(* Simple program to insert alerts in a SQLite DB *)

open Batteries
open RamenLog
open RamenHelpers
open SqliteHelpers

let do_insert_alert debug name firing time title text =
  logger := make_logger debug ;
  (* As calls to this program are hardcoded in ramen program code, it is
   * better to take some configuration parameters from the environment,
   * such as DB_FILE (the sqlite file to be used to write the alerts),
   * DB_CREATE (how to create the DB schema if that file is missing),
   * and DB_INSERT (how to insert into that schema). *)
  let file = getenv ~def:"/tmp/ramen/alerts.db" "DB_FILE"
  and create_q =
    getenv ~def:{|CREATE TABLE "alerts" (
                    "insert_time" INTEGER NOT NULL,
                    "id" TEXT NOT NULL,
                    "name" TEXT NOT NULL,
                    "started" INTEGER,
                    "stopped" INTEGER,
                    "title" TEXT NOT NULL,
                    "text" TEXT NOT NULL);|} "DB_CREATE"
  and insert_q =
    getenv ~def:{|INSERT INTO "alerts" (
                    "insert_time", "id", "name", "started", "stopped",
                    "title", "text"
                  ) VALUES (
                    datetime("now"),
                    $ID$,
                    $NAME$,
                    $STARTED$,
                    $STOPPED$,
                    $TITLE$,
                    $TEXT$);|} "DB_INSERT"
  in
  let open Sqlite3 in
  let handle = db_open file in
  let started_firing, stopped_firing =
    if firing then string_of_float time, "NULL"
    else "NULL", string_of_float time in
  let max_rand = 1073741823 in
  let id =
    Printf.sprintf "%d-%d"
      (int_of_float (Unix.time ())) (Random.int max_rand) in
  let replacements =
    [ "$ID$", sql_quote id ;
      "$NAME$", sql_quote name ;
      "$STARTED$", started_firing ;
      "$STOPPED$", stopped_firing ;
      "$TEXT$", sql_quote text ;
      "$TITLE$", sql_quote title ] in
  let q = List.fold_left (fun str (sub, by) ->
    String.nreplace ~str ~sub ~by) insert_q replacements in
  let db_fail err q =
    !logger.error "Cannot %S into sqlite DB %S: %s"
      q file (Rc.to_string err) ;
    exit 1 in
  let exec_or_fail q =
    match exec handle q with
    | Rc.OK -> ()
    | err -> db_fail err q in
  (match exec handle q with
  | Rc.OK -> ()
  | Rc.ERROR when create_q <> "" ->
    !logger.info "Creating table in sqlite DB %S" file ;
    exec_or_fail create_q ;
    exec_or_fail q
  | err ->
    db_fail err q) ;
  close ~max_tries:30 handle

(* Args *)

open Cmdliner

let debug =
  Arg.(value (flag (info ~doc:"increase verbosity" ["d"; "debug"])))

let xname =
  let i = Arg.info ~doc:"Alert's name" [ "name" ] in
  Arg.(required (opt (some string) None i))

let boolish =
  let parse s =
    match String.lowercase_ascii s with
    | "true" | "1" | "yes" -> Pervasives.Ok true
    | "false" | "0" | "no" -> Pervasives.Ok false
    | f -> Pervasives.Error (`Msg ("Invalid boolean: "^ f))
  and print fmt b =
    Format.fprintf fmt "%b" b
  in
  Arg.conv ~docv:"BOOLEAN" (parse, print)

let firing =
  let i = Arg.info ~doc:"Is the alert firing" [ "firing" ] in
  Arg.(value (opt boolish true i))

let time =
  let i = Arg.info ~doc:"Alert's starting time" [ "time" ] in
  Arg.(value (opt float (Unix.time ()) i))

let title =
  let i = Arg.info ~doc:"Alert's title" [ "title" ] in
  Arg.(required (opt (some string) None i))

let text =
  let i = Arg.info ~doc:"Is the alert firing" [ "text" ] in
  Arg.(value (opt string "" i))

let cmd =
  Term.(
    (const do_insert_alert
      $ debug
      $ xname
      $ firing
      $ time
      $ title
      $ text),
    info "insert_alert")

let () =
  Random.self_init () ;
  Term.eval cmd |> Term.exit
