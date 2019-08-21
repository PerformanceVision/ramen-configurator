(* Helper to extract alerting configuration re. network link from a SQLite DB.
 *)
open Batteries
open RamenLog
open SqliteHelpers

type db =
  { db : Sqlite3.db ;
    get_email_rcpts : Sqlite3.stmt ;
    get_email_from : Sqlite3.stmt ;
    get_snmp_sink : Sqlite3.stmt ;
    get_security_whitelist : Sqlite3.stmt }

let get_email_rcpts_query =
  "SELECT value FROM setting \
    WHERE key = 'alerts_email_recipients' AND value <> ''"

let get_email_from =
  "SELECT value FROM setting \
    WHERE key = 'smtp_from' AND value <> ''"

let get_snmp_sink_query =
  "SELECT \
    (SELECT value FROM setting \
       WHERE key = 'alerts_snmp_host' AND value <> '') ||':'|| \
    COALESCE((SELECT value FROM setting \
                WHERE key = 'alerts_snmp_port' AND value <> ''), '162') \
    AS value"

(* Supposed to be a coma separated list of cidr v4 or v6 *)
let get_security_whitelist_query =
  "SELECT value FROM setting \
     WHERE key = 'alerts_security_whitelist' AND value <> ''"

let get_db filename =
  !logger.debug "Opening DB %S" filename ;
  let open Sqlite3 in
  try (
    let db = db_open ~mode:`READONLY filename in
    !logger.debug "got db handler" ;
    !logger.debug "SQL statements have been prepared" ;
    { db ;
      get_email_rcpts = prepare db get_email_rcpts_query ;
      get_email_from = prepare db get_email_from ;
      get_snmp_sink = prepare db get_snmp_sink_query ;
      get_security_whitelist = prepare db get_security_whitelist_query }
  ) with exc -> (
    !logger.error "Exception: %s" (Printexc.to_string exc) ;
    exit 1
  )

let get_str_value what stmt def =
  let open Sqlite3 in
  match step stmt with
  | Rc.ROW ->
    let res =
      with_field stmt 0 "value" (default def % to_string) in
    reset stmt |> must_be_ok ;
    res
  | Rc.DONE ->
    reset stmt |> must_be_ok ;
    def
  | _ ->
    reset stmt |> ignore ;
    Printf.sprintf "No idea what to do from this %s result" what |>
    failwith

let get_alerts_sink db =
  !logger.debug "Getting alerts sink from DB..." ;
  get_str_value "get_email_from" db.get_email_from "no-reply@accedian.com",
  get_str_value "get_email_rcpts" db.get_email_rcpts "",
  get_str_value "get_snmp_sink" db.get_snmp_sink ""

(* For now the only parameter we have is the whitelist for the scan detector: *)
let get_source_params db =
  get_str_value "get_security_whitelist" db.get_security_whitelist ""

let make filename =
  let db = get_db filename in
  !logger.debug "Building conf from DB %S" filename ;
  (*Alarm.every 1.0 (fun () -> check_config_changed db) ;*)
  db
