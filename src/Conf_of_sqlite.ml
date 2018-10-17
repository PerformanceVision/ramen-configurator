(* Helper to extract alerting configuration re. network link from a SQLite DB.
 *)
open Batteries
open RamenLog
open SqliteHelpers

type db =
  { db : Sqlite3.db ;
    get_email_rcpts : Sqlite3.stmt ;
    get_snmp_sink : Sqlite3.stmt }

let get_email_rcpts_query =
  "SELECT value FROM setting WHERE key = 'alerts_emails'"

let get_snmp_sink_query =
  "SELECT \
    (SELECT value FROM setting WHERE key = 'alerts_snmp_host') ||':'|| \
    COALESCE((SELECT value FROM setting WHERE key = 'alerts_snmp_port' \
                                          AND length(key) > 0), '162') \
    AS value"

let get_db filename =
  !logger.debug "Opening DB %S" filename ;
  let open Sqlite3 in
  try (
    let db = db_open ~mode:`READONLY filename in
    !logger.debug "got db handler" ;
    !logger.debug "SQL statements have been prepared" ;
    { db ;
      get_email_rcpts = prepare db get_email_rcpts_query ;
      get_snmp_sink = prepare db get_snmp_sink_query }
  ) with exc -> (
    !logger.error "Exception: %s" (Printexc.to_string exc) ;
    exit 1
  )

let get_alerts_sink db =
  !logger.debug "Getting alerts sink from DB..." ;
  let open Sqlite3 in
  let rcpts =
    match step db.get_email_rcpts with
    | Rc.ROW ->
      let rcpts =
        with_field db.get_email_rcpts 0 "value" (default "" % to_string) in
      reset db.get_email_rcpts |> must_be_ok ;
      rcpts
    | Rc.DONE ->
      reset db.get_email_rcpts |> must_be_ok ;
      ""
    | _ ->
      reset db.get_email_rcpts |> ignore ;
      failwith "No idea what to do from this get_email_rcpts result" in
  let snmpsink =
    match step db.get_snmp_sink with
    | Rc.ROW ->
      let rcpts =
        with_field db.get_snmp_sink 0 "value" (default "" % to_string) in
      reset db.get_snmp_sink |> must_be_ok ;
      rcpts
    | Rc.DONE ->
      reset db.get_snmp_sink |> must_be_ok ;
      ""
    | _ ->
      reset db.get_snmp_sink |> ignore ;
      failwith "No idea what to do from this get_snmp_sink result" in
  rcpts, snmpsink

let make filename =
  let db = get_db filename in
  !logger.debug "Building conf from DB %S" filename ;
  (*Alarm.every 1.0 (fun () -> check_config_changed db) ;*)
  db
