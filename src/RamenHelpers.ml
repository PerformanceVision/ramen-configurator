open Batteries
open RamenLog

let round_to_int f =
  int_of_float (Float.round f)

let print_exception ?(what="Exception") e =
  !logger.error "%s: %s\n%s"
    what
    (Printexc.to_string e)
    (Printexc.get_backtrace ())

let log_exceptions f x =
  try f x
  with e -> print_exception e

let is_directory f =
  try Sys.is_directory f with _ -> false

let mkdir_all ?(is_file=false) dir =
  let dir = if is_file then Filename.dirname dir else dir in
  let rec ensure_exist d =
    if String.length d > 0 && not (is_directory d) then (
      ensure_exist (Filename.dirname d) ;
      !logger.debug "mkdir %S" d ;
      try Unix.mkdir d 0o755
      with Unix.Unix_error (Unix.EEXIST, "mkdir", _) ->
        (* Happens when we have "somepath//someother" (dirname should handle this IMHO) *)
        ()
    ) in
  ensure_exist dir

let file_exists ?(maybe_empty=true) ?(has_perms=0) fname =
  let open Unix in
  match stat fname with
  | exception _ -> false
  | s ->
    (maybe_empty || s.st_size > 0) &&
    s.st_perm land has_perms = has_perms

let mtime_of_file fname =
  let open Unix in
  let s = stat fname in
  s.st_mtime

(* Trick from LWT: how to exit without executing the at_exit hooks: *)
external sys_exit : int -> 'a = "caml_sys_exit"

let do_daemonize () =
  let open Unix in
  if fork () > 0 then sys_exit 0 ;
  setsid () |> ignore ;
  (* Close all fds, ignoring errors in case they have been closed already: *)
  let null = openfile "/dev/null" [O_RDONLY] 0 in
  dup2 null stdin ;
  close null ;
  let null = openfile "/dev/null" [O_WRONLY; O_APPEND] 0 in
  dup2 null stdout ;
  dup2 null stderr ;
  close null

let shell_quote s =
  "'"^ String.nreplace s "'" "'\\''" ^"'"

let sql_quote s =
  "'"^ String.nreplace s "'" "''" ^"'"

let getenv ?def n =
  try Sys.getenv n
  with Not_found ->
    match def with
    | Some d -> d
    | None ->
      Printf.sprintf "Cannot find envvar %s" n |>
      failwith

let dquote s = Printf.sprintf "%S" s

let vector_print p oc v =
  List.print ~first:"[" ~last:"]" ~sep:";" p oc v

let name_of_signal s =
  let open Sys in
  if s = sigabrt then "ABORT"
  else if s = sigalrm then "ALRM"
  else if s = sigfpe then "FPE"
  else if s = sighup then "HUP"
  else if s = sigill then "ILL"
  else if s = sigint then "INT"
  else if s = sigkill then "KILL"
  else if s = sigpipe then "PIPE"
  else if s = sigquit then "QUIT"
  else if s = sigsegv then "SEGV"
  else if s = sigterm then "TERM"
  else if s = sigusr1 then "USR1"
  else if s = sigusr2 then "USR2"
  else if s = sigchld then "CHLD"
  else if s = sigcont then "CONT"
  else if s = sigstop then "STOP"
  else if s = sigtstp then "TSTP"
  else if s = sigttin then "TTIN"
  else if s = sigttou then "TTOU"
  else if s = sigvtalrm then "VTALRM"
  else if s = sigprof then "PROF"
  else if s = sigbus then "BUS"
  else if s = sigpoll then "POLL"
  else if s = sigsys then "SYS"
  else if s = sigtrap then "TRAP"
  else if s = sigurg then "URG"
  else if s = sigxcpu then "XCPU"
  else if s = sigxfsz then "XFSZ"
  else "Unknown OCaml signal number "^ string_of_int s

let string_of_process_status = function
  | Unix.WEXITED 127 -> "shell couldn't be executed"
  | Unix.WEXITED code -> Printf.sprintf "terminated with code %d" code
  | Unix.WSIGNALED sign -> Printf.sprintf "killed by signal %s" (name_of_signal sign)
  | Unix.WSTOPPED sign -> Printf.sprintf "stopped by signal %s" (name_of_signal sign)
