open Batteries
open RamenLog
open RamenHelpers

let dry_run = ref false
let identity_file = ref ""

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

let compile_program debug ramen_cmd confserver_url fname src_path =
  !logger.info "(Pre-)Compiling program %s as %s"
    fname src_path ;
  if !dry_run then !logger.info "nope" else
    Printf.sprintf
      "%s compile%s%s --confserver %s --replace %s --as %s"
      (shell_quote ramen_cmd)
      (if debug then " --debug" else "")
      (if !identity_file <> "" then " -i "^ !identity_file else "")
      (shell_quote confserver_url)
      (shell_quote fname)
      (shell_quote src_path) |>
    run_cmd |> ignore

let run_program debug ramen_cmd confserver_url as_ params =
  !logger.info "Running program %s with parameters %a"
    as_
    (List.print (Tuple2.print String.print String.print)) params ;
  if !dry_run then !logger.info "nope" else
    Printf.sprintf2
      "%s run%s%s --replace --confserver %s %a %s"
      (shell_quote ramen_cmd)
      (if debug then " --debug" else "")
      (if !identity_file <> "" then " -i "^ !identity_file else "")
      (shell_quote confserver_url)
      (List.print ~first:"" ~last:"" ~sep:" " (fun oc (n, v) ->
        Printf.fprintf oc "-p %s" (shell_quote (n ^"="^ v)))) params
      (shell_quote as_) |>
    run_cmd |> ignore

(* Run that file and return the names it's running under: *)
let run_file debug ramen_cmd root_dir confserver_url no_ext
             ?fname ?src_path params =
  let fname = root_dir ^"/"^ (fname |? (no_ext ^".ramen")) in
  let src_path = src_path |? no_ext in
  let as_ = no_ext in
  if Hashtbl.is_empty params then (
    compile_program debug ramen_cmd confserver_url fname src_path ;
    run_program debug ramen_cmd confserver_url as_ [] ;
    Set.String.singleton as_
  ) else (
    compile_program debug ramen_cmd confserver_url fname src_path ;
    Hashtbl.fold (fun uniq_name params rs ->
      let as_ =
        if uniq_name = "" then as_
                          else as_ ^"#"^ uniq_name in
      run_program debug ramen_cmd confserver_url as_ params ;
      Set.String.add as_ rs
    ) params Set.String.empty)

(* Return the list of everything under sniffer/.
 * TODO: configurator should have its own namespace ("configurator/"?) that's
 * non editable (by convention) to the user (or API), so that we can freely
 * kill programs in there. *)
let get_running ramen_cmd confserver_url path =
  Printf.sprintf2 "%s ps%s --confserver %s %s"
    (shell_quote ramen_cmd)
    (if !identity_file <> "" then " -i "^ !identity_file else "")
    (shell_quote confserver_url)
    (shell_quote path) |>
  run_cmd |>
  String.nsplit ~by:"\n" |>
  List.filter_map (fun l ->
    if l = "" then None else
    match String.nsplit ~by:"\t" l with
    | exception _ ->
        !logger.error "Cannot find tab in %S" l ;
        None
    | _site :: fq :: _ ->
        (try
          let pname, _fname = String.rsplit ~by:"/" fq in
          Some pname
        with Not_found ->
          None)
    | _ ->
        !logger.error "Invalid output for `ramen ps`: %S" l ;
        None) |>
  Set.String.of_list

let kill ramen_cmd confserver_url prog =
  !logger.info "Killing program %s" prog ;
  if !dry_run then !logger.info "nope" else
    Printf.sprintf "%s kill%s --confserver %s %s"
      (shell_quote ramen_cmd)
      (if !identity_file <> "" then " -i "^ !identity_file else "")
      (shell_quote confserver_url)
      (shell_quote prog) |>
    run_cmd |> ignore

let sync_programs debug ramen_cmd root_dir confserver_url uncompress
                  kafka_brokers csv_prefix csv_delete security_whitelist =
  let no_params = Hashtbl.create 0 in
  let old_running = get_running ramen_cmd confserver_url "sniffer/*" in
  let new_running = ref Set.String.empty in
  let comp no_ext ?fname ?src_path p =
    let rs = run_file debug ramen_cmd root_dir confserver_url no_ext
                      ?fname ?src_path p in
    new_running := Set.String.union rs !new_running in
  comp "internal/monitoring/meta" no_params ;
  let params =
    Hashtbl.of_list
      [ "",
          if kafka_brokers <> "" then
            [ "kafka_broker_list", dquote kafka_brokers ]
          else
            [ "csv_prefix", dquote csv_prefix ;
              "csv_delete", string_of_bool csv_delete ;
              "csv_compressed", string_of_bool uncompress ] ] in
  let fname = "sniffer/"
              ^ (if kafka_brokers <> "" then "csv_kafka" else "csv_files")
              ^ ".ramen" in
  let no_ext = "sniffer/csv" in
  comp no_ext ~fname ~src_path:no_ext params ;
  comp "sniffer/metrics" no_params ;
  let aggr_times =
    Hashtbl.of_list [ "1min",  [ "time_step", "60" ] ;
                      "10min", [ "time_step", "600" ] ;
                      "1hour", [ "time_step", "3600" ] ] in
  comp "sniffer/top_zones" aggr_times ;
  comp "sniffer/per_zone" aggr_times ;
  comp "sniffer/top_servers" aggr_times ;
  comp "sniffer/per_application" aggr_times ;
  comp "sniffer/transactions" aggr_times ;
  comp "sniffer/top_errors" aggr_times ;
  let open Conf_of_sqlite in
  (* Several bad behavior detectors, regrouped in a "Security" namespace:
   *)
  let params =
    let wl = String.trim security_whitelist in
    (* Work around forbidden empty lists with NULL: *)
    if wl <> "" then
      let wl = "["^ wl ^"]" in
      Hashtbl.of_list
        [ "", [ "whitelist", wl ] ]
    else no_params in
  comp "sniffer/security/DDoS" params ;
  comp "sniffer/security/scans" params ;
  comp "sniffer/autodetect" no_params ;
  !logger.debug "Old: %a" (Set.String.print String.print) old_running ;
  !logger.debug "New: %a" (Set.String.print String.print) !new_running ;
  let to_kill = Set.String.diff old_running !new_running in
  !logger.info "To Kill: %a" (Set.String.print String.print) to_kill ;
  Set.String.iter (kill ramen_cmd confserver_url) to_kill

(* Note: When executing a shell command, all substitutions are shell-quoted
 * and there is no way around it (FIXME: proper templating language that
 * allows to call functions such as shell-quote so that user is in control).
 * So for now we _unquote_ all substitution and rely on shell string
 * concatenation instead. *)
(* Note: Better use the parameter hostname rather than the envvar, as a
 * parameter will be shell-quoted properly. *)
let send_email from rcpts =
  Printf.sprintf
    "/bin/echo -e '\
       Subject: [PVX Alerting] from '${hostname}' / '${name}'\\n\
       From: %s\\n\
       To: %s\\n\
       \\n\
       '${desc}'\\n\
       \\n\
       (certainty: '${certainty_percent}'%%)\\n\
     ' | sendmail -f %s %s"
     from
     rcpts
     (shell_quote from)
     (shell_quote rcpts)

let send_trap sink =
  Printf.sprintf
    "snmptrap -v 2c -m ALL -IR -c public %s '' generic-notify \
       name.0 s ${name} \
       firingStatus.0 i ${firing} \
       certainty.0 u ${certainty_percent} \
       extParameters.0 s ${desc}"
    (shell_quote sink)

let write_notif_conf fname alert_internal cmds =
  !logger.info "Writing notifier configuration in %S" fname ;
  (* We could share the same type for the conf, and then serialize it,
   * but that would force us to package a library from ramen, for the only
   * benefit of this program. Rather, we'd like PPP to offer _modification_
   * of a blob from the command line. Meanwhile, we merely templatize
   * this string: *)
  File.with_file_out ~mode:[`create;`text;`trunc] fname (fun oc ->
    Printf.fprintf oc {|
{
  teams = [
    %s{
      name = "" ;
      contacts =
        [
          ViaSqlite {
            file = "/srv/ramen/alerts.db" ;
            create = "create table \"alerts\" (
                \"id\" integer primary key autoincrement,
                \"start\" integer not null,
                \"stop\" integer null,
                \"name\" text not null,
                \"firing\" integer null,
                \"desc\" text null,
                \"bcn\" integer null,
                \"bca\" integer null,
                \"service_id\" integer null,
                \"ips\" text null,
                \"thresholds\" text null,
                \"values\" text null
              );" ;
            insert = "insert into \"alerts\" (
                \"name\", \"desc\", \"firing\",
                \"start\", \"stop\",
                \"bcn\", \"bca\", \"service_id\",
                \"ips\", \"thresholds\", \"values\"
              ) values (
                ${name}, ${desc}, ${firing},
                ${start}, ${stop},
                ${bcn}, ${bca}, ${service_id},
                ${ips}, ${thresholds}, ${values}
              );"
          }%s
          %a
        ]
    }
  ];
  default_init_schedule_delay = 30;
}
|}
    (if alert_internal then "" else "{ name = \"Internal\" ; contacts = [] }; ")
    (if cmds <> [] then " ;" else "")
    (List.print ~first:"" ~sep:" ;\n" ~last:"\n" (fun oc cmd ->
      Printf.fprintf oc "ViaExec %S" cmd)) cmds)

let sync_notif_conf =
  let prev_cmds = ref None in
  fun db notif_conf_file alert_internal ->
    let from, rcpts, snmpsink = Conf_of_sqlite.get_alerts_sink db in
    let cmds = [] in
    let cmds =
      if rcpts = "" || from = "" then cmds
      else send_email from rcpts :: cmds in
    let cmds =
      if snmpsink = "" then cmds
      else send_trap snmpsink :: cmds in
    if !prev_cmds <> Some cmds then (
      write_notif_conf notif_conf_file alert_internal cmds ;
      prev_cmds := Some cmds)

let start debug monitor ramen_cmd root_dir confserver_url db_name
          uncompress kafka_brokers csv_prefix csv_delete alert_internal
          notif_conf_file identity_file_ dry_run_ =
  logger := make_logger debug ;
  identity_file := identity_file_ ;
  dry_run := dry_run_ ;
  if kafka_brokers <> "" &&
     (csv_prefix <> "" || csv_delete || uncompress)
  then
    failwith "CSV options are not compatible with Kafka" ;
  let db = Conf_of_sqlite.get_db db_name in
  let update_programs () =
    let security_whitelist = Conf_of_sqlite.get_source_params db in
    sync_programs debug ramen_cmd root_dir confserver_url uncompress
                  kafka_brokers csv_prefix csv_delete security_whitelist
  and update_notif_conf () =
    if notif_conf_file <> "" then
      sync_notif_conf db notif_conf_file alert_internal
  in
  update_notif_conf () ;
  update_programs () ;
  if monitor then
    while true do
      update_notif_conf () ;
      Unix.sleep 5
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

let confserver_url =
  let env = Term.env_info "RAMEN_CONFSERVER" in
  let i = Arg.info ~doc:"Configure remote confserver"
                   ~env [ "confserver" ] in
  Arg.(value (opt ~vopt:"localhost" string "" i))

let uncompress_opt =
  let i = Arg.info ~doc:"CSV are compressed with lz4"
                   [ "uncompress" ; "uncompress-csv" ] in
  Arg.(value (flag i))

let kafka_brokers =
  let i = Arg.info ~doc:"Read CSV data from Kafka instead of files."
            [ "kafka-broers" ] in
  Arg.(value (opt string "" i))

let csv_prefix =
  let i = Arg.info ~doc:"File glob for the CSV files that comes right \
                         before the metric name"
                   [ "csv" ] in
  Arg.(value (opt string "" i))

let csv_delete =
  let i = Arg.info ~doc:"Delete CSV files once injected"
                   [ "delete" ] in
  Arg.(value (flag i))

let notif_conf_file =
  let env = Term.env_info "NOTIFIER_CONFIG" in
  let i = Arg.info ~doc:"Notifier configuration file to write"
                   ~env ["notifier-config"; "notif-config"] in
  Arg.(value (opt string "" i))

let alert_internal =
  let i = Arg.info ~doc:"Also send \"Internal\" notifications."
                   [ "alert-internal" ] in
  Arg.(value (flag i))

let identity_file =
  let env = Term.env_info "RAMEN_CLIENT_IDENTITY" in
  let i = Arg.info ~doc:"User identity file."
                   ~docv:"FILE" ~env [ "i" ; "identity" ] in
  Arg.(value (opt string "" i))

let dry_run =
  let i = Arg.info ~doc:"Just display what would be killed/run"
                   [ "dry-run" ] in
  Arg.(value (flag i))

let start_cmd =
  let doc = "Configurator for Ramen in PV"
  and version = "3.1.0" in
  Term.(
    (const start
      $ debug
      $ monitor
      $ ramen_cmd
      $ root_dir
      $ confserver_url
      $ db_name
      $ uncompress_opt
      $ kafka_brokers
      $ csv_prefix
      $ csv_delete
      $ alert_internal
      $ notif_conf_file
      $ identity_file
      $ dry_run),
    info "ramen_configurator" ~version ~doc)

let () =
  Term.eval start_cmd |> Term.exit
