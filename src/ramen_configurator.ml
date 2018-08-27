open Batteries
open RamenLog
open RamenHelpers

let dry_run = ref false

let run_cmd cmd =
  !logger.debug "Running: %s" cmd ;
  let cmd' = cmd ^" 2>&1" in
  let status, output = Unix.run_and_read cmd' in
  if status <> Unix.WEXITED 0 then (
    Printf.printf "%s" output ;
    Printf.sprintf "Bad exit code from %S: %s"
      cmd (string_of_process_status status) |>
    failwith
  ) else output

let run_program ramen_cmd root_dir persist_dir ?as_ fname params =
  !logger.info "Running program %s%s"
    fname (Option.map_default (fun as_ -> " (as: "^ as_ ^")") "" as_) ;
  if !dry_run then !logger.info "nope" else
    Printf.sprintf2 "%s run --replace --persist-dir %s%s %a %s"
      (shell_quote ramen_cmd)
      (shell_quote persist_dir)
      (Option.map_default (fun as_ -> " -o "^ shell_quote as_) "" as_)
      (List.print ~first:"" ~last:"" ~sep:" " (fun oc (n, v) ->
        Printf.fprintf oc "-p %s" (shell_quote (n ^"="^ v)))) params
      (shell_quote fname) |>
    run_cmd |> ignore

let chop_placeholder s =
  let dirname, placeholder = String.rsplit ~by:"/" s in
  if placeholder <> "_" && placeholder <> "_/" then
    Printf.sprintf "Chopped path %S has no placeholder" s |>
    failwith ;
  dirname

(* Run that file and return the names it's running under: *)
let run_file ramen_cmd root_dir persist_dir no_ext params =
  let fname = root_dir ^"/"^ no_ext ^".x" in
  let as_ = no_ext in
  if Hashtbl.is_empty params then (
    !logger.debug "Running program %s as %s"
      fname as_ ;
    run_program ramen_cmd root_dir persist_dir ~as_ fname [] ;
    Set.String.singleton as_
  ) else (
    Hashtbl.fold (fun uniq_name params rs ->
      let as_ =
        if uniq_name = "" then as_ else
          chop_placeholder as_ ^"/"^ uniq_name in
      !logger.debug "Running program %s as %s with parameters %a"
        fname as_
        (List.print (Tuple2.print String.print String.print)) params ;
      run_program ramen_cmd root_dir persist_dir ~as_ fname params ;
      Set.String.add as_ rs
    ) params Set.String.empty)

let get_config_from_db db =
  Conf_of_sqlite.get_config db

(* Return the list of everything under junkie/.
 * TODO: configurator should have its own namespace ("configurator/"?) that's
 * non editable (by convention) to the user (or API), so that we can freely
 * kill programs in there. *)
let get_running ramen_cmd persist_dir path =
  Printf.sprintf2 "%s ps -p --persist-dir %s %s"
    (shell_quote ramen_cmd)
    (shell_quote persist_dir)
    (shell_quote path) |>
  run_cmd |>
  String.nsplit ~by:"\n" |>
  List.filter_map (fun l ->
    if l = "" then None else
    match String.split ~by:"\t" l with
    | exception _ ->
        !logger.error "Cannot find tab in %S" l ;
        None
    | x, _ -> Some x) |>
  Set.String.of_list

let kill ramen_cmd persist_dir prog =
  !logger.info "Killing program %s" prog ;
  if !dry_run then !logger.info "nope" else
    Printf.sprintf "%s kill --persist-dir %s %s"
      (shell_quote ramen_cmd)
      (shell_quote persist_dir)
      (shell_quote prog) |>
    run_cmd |> ignore

let start debug monitor ramen_cmd root_dir persist_dir db_name
          uncompress csv_prefix
          with_bcns with_bcas dry_run_ =
  logger := make_logger debug ;
  dry_run := dry_run_ ;
  let open Conf_of_sqlite in
  let db = get_db db_name in
  let no_params = Hashtbl.create 0 in
  let update () =
    let old_running = get_running ramen_cmd persist_dir "junkie/*" in
    let new_running = ref Set.String.empty in
    let comp n p =
      let rs = run_file ramen_cmd root_dir persist_dir n p in
      new_running := Set.String.union rs !new_running in
    comp "internal/monitoring/meta" no_params ;
    let params =
      let h = Hashtbl.create 2 in
      Hashtbl.add h ""
        [ "csv_prefix", dquote csv_prefix ;
          "csv_compressed", string_of_bool uncompress ] ;
      h in
    comp "junkie/csv" params ;
    let aggr_times =
      Hashtbl.of_list [ "1min",  [ "obs_window", "60" ] ;
                        "10min", [ "obs_window", "600" ] ;
                        "1hour", [ "obs_window", "3600" ] ] in
    comp "junkie/links/top_zones/_" aggr_times ;
    comp "junkie/apps/top_servers/_" aggr_times ;
    comp "junkie/apps/transactions/_" aggr_times ;
    let bcns, bcas = get_config_from_db db in
    let bcns = List.take with_bcns bcns
    and bcas = List.take with_bcas bcas in
    if bcns <> [] then (
      let or_null f = function
        | None -> "NULL"
        | Some v -> f v in
      let params = Hashtbl.create 5 in
      List.iter (fun bcn ->
        let uniq_name = bcn.BCN.source_name ^" → "^ bcn.dest_name in
        (* Empty vectors are prohibited for now, so just remove them
         * and let the code deal with the default value (which is non
         * empty but unused in that actual case) *)
        List.filter ((<>) "[]" % snd) BCN.[
          "id", string_of_int bcn.id ;
          "min_bps", or_null string_of_int bcn.min_bps ;
          "max_bps", or_null string_of_int bcn.max_bps ;
          "max_rtt", or_null string_of_float bcn.max_rtt ;
          "max_rr", or_null string_of_float bcn.max_rr ;
          "avg_window", string_of_float bcn.avg_window ;
          "obs_window", string_of_float bcn.obs_window ;
          "perc", string_of_float bcn.percentile ;
          "min_for_relevance", string_of_int bcn.min_for_relevance ;
          "source", IO.to_string (vector_print Int.print) bcn.source ;
          "source_name", dquote bcn.source_name ;
          "dest", IO.to_string (vector_print Int.print) bcn.dest ;
          "dest_name", dquote bcn.dest_name
        ] |>
        Hashtbl.add params uniq_name
      ) bcns ;
      comp "junkie/links/BCN/_" params
    ) ;
    if bcas <> [] then (
      let params = Hashtbl.create 5 in
      List.iter (fun bca ->
        let uniq_name = bca.BCA.name in
        BCA.[
          "id", string_of_int bca.id ;
          "service_id", string_of_int bca.service_id ;
          "name", dquote bca.name ;
          "max_eurt", string_of_float bca.max_eurt ;
          "avg_window", string_of_float bca.avg_window ;
          "obs_window", string_of_float bca.obs_window ;
          "perc", string_of_float bca.percentile ;
          "min_handshake_count", string_of_int bca.min_srt_count
        ] |>
        Hashtbl.add params uniq_name
      ) bcas ;
      comp "junkie/apps/BCA/_" params
    ) ;
    (* Several bad behavior detectors, regrouped in a "Security" namespace:
     *)
    comp "junkie/security/DDoS" no_params ;
    comp "junkie/security/scans" no_params ;
    !logger.debug "Old: %a" (Set.String.print String.print) old_running ;
    !logger.debug "New: %a" (Set.String.print String.print) !new_running ;
    let to_kill = Set.String.diff old_running !new_running in
    !logger.info "To Kill: %a" (Set.String.print String.print) to_kill ;
    Set.String.iter (kill ramen_cmd persist_dir) to_kill
  in
  update () ;
  if monitor then
    while true do
      check_config_changed db ;
      if must_reload db then (
        !logger.info "Must reload configuration" ;
        update ()
      ) else (
        Unix.sleep 1
      )
    done

(* Args *)

open Cmdliner

let debug =
  Arg.(value (flag (info ~doc:"increase verbosity" ["d"; "debug"])))

let monitor =
  Arg.(value (flag (info ~doc:"keep running and update conf when DB changes"
                           ["m"; "monitor"])))

let ramen_cmd =
  let i = Arg.info ~doc:"Command line to run ramen"
                   [ "ramen" ] in
  Arg.(value (opt string "ramen" i))

let db_name =
  let i = Arg.info ~doc:"Path of the SQLite file"
                   [ "db" ] in
  Arg.(required (opt (some string) None i))

let root_dir =
  let env = Term.env_info "RAMEN_ROOT" in
  let i = Arg.info ~doc:"Path of root of ramen configuration tree"
                   ~env [ "root" ] in
  Arg.(value (opt string "." i))

let persist_dir =
  let env = Term.env_info "RAMEN_PERSIST_DIR" in
  let i = Arg.info ~doc:"Path where ramen stores its state"
                   ~env [ "persist-dir" ] in
  Arg.(value (opt string "/tmp/ramen" i))

let uncompress_opt =
  let i = Arg.info ~doc:"CSV are compressed with lz4"
                   [ "uncompress" ; "uncompress-csv" ] in
  Arg.(value (flag i))

let csv_prefix =
  let i = Arg.info ~doc:"File glob for the CSV files that comes right \
                         before the metric name"
                   [ "csv" ] in
  Arg.(required (opt (some string) None i))

let with_bcns =
  let i = Arg.info ~doc:"Also output the program with BCN configuration"
                   [ "with-bcns" ; "with-bcn" ; "bcns" ; "bcn" ] in
  Arg.(value (opt ~vopt:10 int 0 i))

let with_bcas =
  let i = Arg.info ~doc:"Also output the program with BCA configuration"
                   [ "with-bcas" ; "with-bca" ; "bcas" ; "bca" ] in
  Arg.(value (opt ~vopt:10 int 0 i))

let dry_run =
  let i = Arg.info ~doc:"Just display what would be killed/run"
                   [ "dry-run" ] in
  Arg.(value (flag i))

let start_cmd =
  let doc = "Configurator for Ramen in PV"
  and version = "1.4.0" in
  Term.(
    (const start
      $ debug
      $ monitor
      $ ramen_cmd
      $ root_dir
      $ persist_dir
      $ db_name
      $ uncompress_opt
      $ csv_prefix
      $ with_bcns
      $ with_bcas
      $ dry_run),
    info "ramen_configurator" ~version ~doc)

let () =
  Term.eval start_cmd |> Term.exit
