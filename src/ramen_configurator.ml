open Batteries
open RamenLog
open RamenHelpers

let compile_program ramen_cmd root_dir bundle_dir ?as_ fname =
  let cmd =
    Printf.sprintf2 "%s compile --root=%S --bundle-dir=%S%s %s"
      ramen_cmd root_dir bundle_dir
      (Option.map_default (fun as_ -> " -o "^ shell_quote as_) "" as_)
      (shell_quote fname)
  in
  if 0 = Sys.command cmd then (
    !logger.debug "Compiled %s" fname ;
    (* Now Ramen with autoreload should pick it up *)
    true
  ) else (
    !logger.error "Failed to compile program %s with %S" fname cmd ;
    false
  )

let run_program ramen_cmd root_dir persist_dir ?as_ fname params =
  let cmd =
    Printf.sprintf2 "%s run --replace --persist-dir %s%s %a %s"
      ramen_cmd
      (shell_quote persist_dir)
      (Option.map_default (fun as_ -> " -o "^ shell_quote as_) "" as_)
      (List.print ~first:"" ~last:"" ~sep:" " (fun oc (n, v) ->
        Printf.fprintf oc "-p %s" (shell_quote (n ^"="^ v)))) params
      (shell_quote fname) in
  !logger.info "Running: %s" cmd ;
  if 0 = Sys.command cmd then
    !logger.debug "Run %s" fname
  else
    !logger.error "Failed to run program %s with %S" fname cmd

let chop_placeholder s =
  let dirname, placeholder = String.rsplit ~by:"/" s in
  if placeholder <> "_" && placeholder <> "_/" then
    Printf.sprintf "Chopped path %S has no placeholder" s |>
    failwith ;
  dirname

let compile_file ramen_cmd root_dir bundle_dir persist_dir no_ext params =
  let fname = root_dir ^"/"^ no_ext ^".ramen" in
  if compile_program ramen_cmd root_dir bundle_dir fname then (
    let bin_name = root_dir ^"/"^ no_ext ^".x" in
    let as_ = no_ext in
    if Hashtbl.is_empty params then (
      !logger.debug "Running program %s as %s"
        bin_name as_ ;
      run_program ramen_cmd root_dir persist_dir ~as_ bin_name []
    ) else (
      Hashtbl.iter (fun uniq_name params ->
        let as_ =
          if uniq_name = "" then as_ else
            chop_placeholder as_ ^"/"^ uniq_name in
        !logger.debug "Running program %s as %s with parameters %a"
          bin_name as_
          (List.print (Tuple2.print String.print String.print)) params ;
        run_program ramen_cmd root_dir persist_dir ~as_ bin_name params
      ) params))

let get_config_from_db db =
  Conf_of_sqlite.get_config db

let start debug monitor ramen_cmd root_dir bundle_dir persist_dir db_name
          uncompress csv_prefix
          with_bcns with_bcas =
  logger := make_logger debug ;
  let open Conf_of_sqlite in
  let db = get_db db_name in
  let no_params = Hashtbl.create 0 in
  let comp = compile_file ramen_cmd root_dir bundle_dir persist_dir in
  let update () =
    comp "internal/monitoring/meta" no_params ;
    let params =
      let h = Hashtbl.create 2 in
      Hashtbl.add h ""
        [ "csv_prefix", dquote csv_prefix ;
          "csv_compressed", string_of_bool uncompress ] ;
      h in
    comp "junkie/base" params ;
    let aggr_times =
      Hashtbl.of_list [ "1min",  [ "aggr_duration", "60" ] ;
                        "10min", [ "aggr_duration", "600" ] ;
                        "1hour", [ "aggr_duration", "3600" ] ] in
    comp "junkie/links/top_zones/_" aggr_times ;
    comp "junkie/apps/top_servers/_" aggr_times ;
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
    comp "junkie/security/scans" no_params
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

let bundle_dir =
  let env = Term.env_info "RAMEN_BUNDLE_DIR" in
  let i = Arg.info ~doc:"Path of ramen runtime libraries"
                   ~env [ "bundle-dir" ] in
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

let start_cmd =
  Term.(
    (const start
      $ debug
      $ monitor
      $ ramen_cmd
      $ root_dir
      $ bundle_dir
      $ persist_dir
      $ db_name
      $ uncompress_opt
      $ csv_prefix
      $ with_bcns
      $ with_bcas),
    info "ramen_configurator")

let () =
  Term.eval start_cmd |> Term.exit
