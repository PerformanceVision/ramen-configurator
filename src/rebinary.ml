open Batteries
open Stdint
open Dessser
module T = Dessser.Types

let version = "3.3.0"

let debug = ref false

module Args =
struct
  open Cmdliner

  let debug =
    let env = Term.env_info "DEBUG" in
    let i = Arg.info ~doc:"Increase verbosity." ~env [ "d" ; "debug" ] in
    Arg.(value (flag i))

  let schemas_dir =
    let env = Term.env_info "SCHEMAS_DIR" in
    let i = Arg.info ~doc:"Where to find NamesAndTypes files (named: metric_name.txt)."
                     ~env [ "schemas" ] in
    Arg.(value (opt string "ramen_root/sniffer/" i))

  let lib_dir =
    let env = Term.env_info "LIB_DIR" in
    let i = Arg.info ~doc:"Where to find rebinary_plug.cmxa."
                     ~env [ "lib-dir" ] in
    Arg.(value (opt string "src/" i))

  let full_speed =
    let env = Term.env_info "FULL_SPEED" in
    let i = Arg.info ~doc:"Play CHBs at full speed."
                     ~env [ "full-speed" ] in
    Arg.(value (flag i))

  let brokers =
    let env = Term.env_info "KAFKA_BROKERS" in
    let i = Arg.info ~doc:"Initial Kafka brokers."
                     ~env [ "brokers" ] in
    Arg.(value (opt string "localhost:9092" i))

  let timeout =
    let env = Term.env_info "KAFKA_TIMEOUT" in
    let i = Arg.info ~doc:"Timeout when sending a Kafka message."
                     ~env [ "timeout" ] in
    Arg.(value (opt float 10. i))

  let partition =
    let env = Term.env_info "KAFKA_PARTITION" in
    let i = Arg.info ~doc:"Kafka partition where to send messages to."
                     ~env [ "partition" ] in
    Arg.(value (opt int 0 i))

  let max_msg_size =
    let env = Term.env_info "KAFKA_MAX_MSG_SIZE" in
    let i = Arg.info ~doc:"Max message size (must match server and consumer, good luck)"
                     ~env [ "max-msg-size" ] in
    Arg.(value (opt int 400_000 i))

  let max_tuples_per_msg =
    let env = Term.env_info "KAFKA_MAX_TUPLES_PER_MSG" in
    let i = Arg.info ~doc:"Max tuples per Kafka message"
                     ~env [ "max-tuples-per-msg" ] in
    Arg.(value (opt int 100 i))

  let in_files =
    let env = Term.env_info "CHBS_DIR" in
    let i = Arg.info ~doc:"Where are chb files located."
                     ~env ~docv:"FILES" [] in
    Arg.(non_empty (pos_all string [] i))

  let loop =
    let env = Term.env_info "LOOP" in
    let i = Arg.info ~doc:"Loop instead of quitting when done."
                     ~env [ "loop" ] in
    Arg.(value (flag i))
end


module Parser =
struct
  module PConfig = ParsersPositions.LineCol (Parsers.SimpleConfig (Char))
  module P = Parsers.Make (PConfig)
  module ParseUsual = ParsersUsual.Make (P)
  include P
  include ParseUsual

  let blanks =
    repeat_greedy ~min:1 ~sep:none ~what:"whitespaces"
      (blank ||| newline) >>: ignore

  let opt_blanks =
    optional_greedy ~def:() blanks

  let allow_surrounding_blanks ppp =
    opt_blanks -+ ppp +- opt_blanks +- eof

  let string_parser ?what ~print p =
    let what =
      match what with None -> [] | Some w -> [w] in
    let p = allow_surrounding_blanks p in
    fun s ->
      let stream = stream_of_string s in
      let parse_with_err_budget e =
        let c = ParsersBoundedSet.make e in
        p what None c stream |> to_result in
      let err_out e =
        Printf.sprintf2 "Parse error: %a"
          (print_bad_result print) e |>
        failwith
      in
      match parse_with_err_budget 0 with
      | Bad e -> err_out e
      | Ok (res, _) -> res

  (* strinG will match the given string regardless of the case and
   * regardless of the surrounding (ie even if followed by other letters). *)
  let strinG = ParseUsual.string ~case_sensitive:false

  let p m =
    let m = "NamesAndTypes" :: m in
    let backquoted_string_with_sql_style m =
      let m = "Backquoted field name" :: m in
      (
        char '`' -+
        repeat_greedy ~sep:none (
          cond "field name" ((<>) '`') 'x') +-
        char '`' >>: String.of_list
      ) m in
    let rec ptype m =
      let with_param np ap =
        np -- opt_blanks -- char '(' -+ ap +- char ')' in
      let with_2_params np p1 p2 =
        let ap = p1 -+ opt_blanks +- char ',' +- opt_blanks ++ p2 in
        with_param np ap in
      let unsigned =
        integer >>: fun n ->
          let i = Num.to_int n in
          if i < 0 then raise (Reject "Type parameter must be >0") ;
          i in
      let with_num_param s =
        with_param (strinG s) unsigned in
      let with_2_num_params s =
        with_2_params (strinG s) number number in
      let with_typ_param s =
        with_param (strinG s) ptype in
      let m = "Type name" :: m in
      (
        let notnull = T.(make ~nullable:false) in
        (* Look only for simple types, starting with numerics: *)
        (strinG "UInt8" >>: fun () -> notnull T.TU8) |||
        (strinG "UInt16" >>: fun () -> notnull T.TU16) |||
        (strinG "UInt32" >>: fun () -> notnull T.TU32) |||
        (strinG "UInt64" >>: fun () -> notnull T.TU64) |||
        ((strinG "Int8" ||| strinG "TINYINT") >>:
          fun () -> notnull T.TI8) |||
        ((strinG "Int16" ||| strinG "SMALLINT") >>:
          fun () -> notnull T.TI16) |||
        ((strinG "Int32" ||| strinG "INT" ||| strinG "INTEGER") >>:
          fun () -> notnull T.TI32) |||
        ((strinG "Int64" ||| strinG "BIGINT") >>:
          fun () -> notnull T.TI64) |||
        ((strinG "Float32" ||| strinG "Float64" |||
          strinG "FLOAT" ||| strinG "DOUBLE") >>:
          fun () -> notnull T.TFloat) |||
        (* Assuming UUIDs are just plain U128 with funny-printing: *)
        (strinG "UUID" >>: fun () -> notnull T.TU128) |||
        (* Decimals: for now forget about the size of the decimal part,
         * just map into corresponding int type*)
        (with_num_param "Decimal32" >>: fun _p -> notnull T.TI32) |||
        (with_num_param "Decimal64" >>: fun _p -> notnull T.TI64) |||
        (with_num_param "Decimal128" >>: fun _p -> notnull T.TI128) |||
        (* TODO: actually do something with the size: *)
        ((with_2_num_params "Decimal" ||| with_2_num_params "DEC") >>:
          fun (_n, _m)  -> notnull T.TI128) |||
        ((strinG "DateTime" ||| strinG "TIMESTAMP") >>:
          fun () -> notnull T.TU32) |||
        (strinG "Date" >>: fun () -> notnull T.TU16) |||
        ((strinG "String" ||| strinG "CHAR" ||| strinG "VARCHAR" |||
          strinG "TEXT" ||| strinG "TINYTEXT" ||| strinG "MEDIUMTEXT" |||
          strinG "LONGTEXT" ||| strinG "BLOB" ||| strinG "TINYBLOB" |||
          strinG "MEDIUMBLOB" ||| strinG "LONGBLOB") >>:
          fun () -> notnull T.TString) |||
        ((with_num_param "FixedString" ||| with_num_param "BINARY") >>:
          fun d -> T.(notnull T.(TVec (d, notnull TChar)))) |||
        (with_typ_param "Nullable" >>:
          fun t -> T.{ t with nullable = true }) |||
        (* Just ignore those ones (for now): *)
        (with_typ_param "LowCardinality")
        (* Etc... *)
      ) m
    in
    (
      optional ~def:() (
        string "columns format version: " -- number -- blanks) --
      optional ~def:() (
        number -- blanks -- string "columns:" -- blanks) -+
      several ~sep:blanks (
        backquoted_string_with_sql_style +- blanks ++ ptype
      ) >>:
        fun lst -> T.make (TRec (Array.of_list lst))
    ) m
end

(* Now that we have a NamesAndTypes parser, read a schema on stdin and parse it: *)

let read_whole_file fname =
  File.with_file_in fname IO.read_all

let namesAndTypes schema_file =
  let str = read_whole_file schema_file in
  let print = T.print in
  let t = Parser.(string_parser ~what:"NamesAndTypes" ~print p) str in
  if !debug then
    Printf.printf "Will generate rowbinary for type: %a\n%!"
      T.print t ;
  t

let run_cmd cmd =
  if !debug then
    Printf.eprintf "Running command: %s\n%!" cmd ;
  match Unix.system cmd with
  | Unix.WEXITED 0 -> ()
  | Unix.WEXITED code ->
      Printf.sprintf "%s failed with code %d\n" cmd code |>
      failwith
  | Unix.WSIGNALED s ->
      Printf.sprintf "%s killed with signal %d" cmd s |>
      failwith
  | Unix.WSTOPPED s ->
      Printf.sprintf "%s stopped by signal %d" cmd s |>
      failwith

module HexDump =
struct
  let hex_of =
    let zero = Char.code '0'
    and ten = Char.code 'a' - 10 in
    fun n ->
      if n < 10 then Char.chr (zero + n)
      else Char.chr (ten + n)

  (* Returns the int (0..255) into a 2 char hex representation: *)
  let hex_byte_of i =
    assert (i >= 0 && i <= 255) ;
    String.init 2 (function
      | 0 -> i lsr 4 |> hex_of
      | _ -> i land 15 |> hex_of)

  (* TODO: add those to BatChar.is_symbol? *)
  let is_missing_symbol = function
    | '(' | ')' | '[' | ']' | '{' | '}' | ';'
    | '\'' | '"' | ',' | '.' | '_' | ' ' ->
        true
    | _ ->
        false

  let is_printable c =
    let open Char in
    is_letter c || is_digit c || is_symbol c || is_missing_symbol c

  let print ?(num_cols=16) bytes oc =
    let disp_char_of c =
      if is_printable c then c else '.'
    in
    (* [b0] was the offset at the beginning of the line while [b] is the
     * current offset.
     * [c] is the current column. *)
    let rec aux b0 c b =
      (* Sep from column c-1: *)
      let sep c =
        if c >= num_cols then ""
        else if c = 0 then "    "
        else if c land 7 = 0 then " - "
        else " " in
      (* Display the ascii section + new line: *)
      let eol () =
        if c > 0 then (
          (* Fill up to ascii section: *)
          for i = c to num_cols do
            Printf.fprintf oc "%s  " (sep i)
          done ;
          (* Ascii section: *)
          Printf.fprintf oc "  " ;
          for i = 0 to c - 1 do
            Char.print oc
              (disp_char_of (Bytes.get bytes (b0 + i)))
          done ;
          String.print oc "\n"
        )
      in
      (* Actually add an hex byte: *)
      if b >= Bytes.length bytes then (
        eol ()
      ) else (
        if c >= num_cols then (
          eol () ;
          aux b 0 b
        ) else (
          let str = hex_byte_of (Char.code (Bytes.get bytes b)) in
          Printf.fprintf oc "%s%s" (sep c) str ;
          aux b0 (c + 1) (b + 1)))
    in
    Printf.fprintf oc "\n" ;
    aux 0 0 0
end

type fname =
  { name : string ;
    poller : string ;
    time : float ;
    metric : string }

let parse_chb_fname name =
  let error msg =
    Printf.eprintf "%s\n%!" msg ;
    None in
  match String.split_on_char '.' name with
  | [ poller ; timestamp ; metric_version ; ext ] ->
      if ext <> "chb" then error ("Wrong ext: "^ ext) else
      let metric, version = String.rsplit ~by:"_" metric_version in
      if version <> "v30" then error ("Wrong version: "^ version) else
      let metric =
        match String.index metric '+' with
        | exception Not_found -> metric
        | i ->
            assert (i > 0) ;
            String.left metric (i - 1) in
      Some { name ; poller ; time = float_of_string timestamp ; metric }
  | _ ->
      error ("Cannot make sense of filename "^ name)

let producers = Hashtbl.create 10

let kafka_err_string =
	let open Kafka in
	function
  | BAD_MSG -> "BAD_MSG"
  | BAD_COMPRESSION -> "BAD_COMPRESSION"
  | DESTROY -> "DESTROY"
  | FAIL -> "FAIL"
  | TRANSPORT -> "TRANSPORT"
  | CRIT_SYS_RESOURCE -> "CRIT_SYS_RESOURCE"
  | RESOLVE -> "RESOLVE"
  | MSG_TIMED_OUT -> "MSG_TIMED_OUT"
  | UNKNOWN_PARTITION -> "UNKNOWN_PARTITION"
  | FS -> "FS"
  | UNKNOWN_TOPIC -> "UNKNOWN_TOPIC"
  | ALL_BROKERS_DOWN -> "ALL_BROKERS_DOWN"
  | INVALID_ARG -> "INVALID_ARG"
  | TIMED_OUT -> "TIMED_OUT"
  | QUEUE_FULL -> "QUEUE_FULL"
  | ISR_INSUFF -> "ISR_INSUFF"
  | UNKNOWN -> "UNKNOWN"
  | OFFSET_OUT_OF_RANGE -> "OFFSET_OUT_OF_RANGE"
  | INVALID_MSG -> "INVALID_MSG"
  | UNKNOWN_TOPIC_OR_PART -> "UNKNOWN_TOPIC_OR_PART"
  | INVALID_MSG_SIZE -> "INVALID_MSG_SIZE"
  | LEADER_NOT_AVAILABLE -> "LEADER_NOT_AVAILABLE"
  | NOT_LEADER_FOR_PARTITION -> "NOT_LEADER_FOR_PARTITION"
  | REQUEST_TIMED_OUT -> "REQUEST_TIMED_OUT"
  | BROKER_NOT_AVAILABLE -> "BROKER_NOT_AVAILABLE"
  | REPLICA_NOT_AVAILABLE -> "REPLICA_NOT_AVAILABLE"
  | MSG_SIZE_TOO_LARGE -> "MSG_SIZE_TOO_LARGE"
  | STALE_CTRL_EPOCH -> "STALE_CTRL_EPOCH"
  | OFFSET_METADATA_TOO_LARGE -> "OFFSET_METADATA_TOO_LARGE"
  | CONF_UNKNOWN -> "CONF_UNKNOWN"
  | CONF_INVALID -> "CONF_INVALID"

let delivery_callback msg_id err =
  match err with
  | None ->
      if !debug then
        Printf.eprintf "delivery_callback: msg_id=%d, Success\n%!"
          msg_id
  | Some err_code ->
      Printf.eprintf "delivery_callback: msg_id=%d, Error: %s\n%!"
        msg_id (kafka_err_string err_code)

let producer_of_topic kafka_handler timeout topic =
  try Hashtbl.find producers topic
  with Not_found ->
    let prod_topic =
      Kafka.new_topic kafka_handler topic [
        "message.timeout.ms",
          string_of_int (int_of_float (timeout *. 1000.)) ;
      ] in
    Hashtbl.add producers topic prod_topic ;
    prod_topic

let release_all_producers kafka_handler =
  Hashtbl.iter (fun _ producer_topic ->
    Kafka.destroy_topic producer_topic
  ) producers ;
  Kafka.destroy_handler kafka_handler

let msg_id = ref 0
let send_to_topic kafka_handler timeout partition topic bytes len tups =
  if len > 0 then (
    assert (tups > 0) ;
    let open Kafka in
    let prod_topic = producer_of_topic kafka_handler timeout topic in
    if !debug then
      Printf.eprintf "Sending %d tuples in %d bytes to topic %S\n%!"
        tups len topic ;
    let str = Bytes.sub_string bytes 0 len in
    Kafka.produce prod_topic ~msg_id:!msg_id partition str ;
    incr msg_id ;
    Kafka.wait_delivery kafka_handler (* Should be done once per set or even only once at the end *)
  )

module BE = BackEndOCaml
module RB2RB = DesSer (RowBinary.Des (BE)) (RowBinary.Ser (BE))

(* We actually append all functions in a single file and compile and load it
 * only once as a work around for dynlink bug. *)
let create_plugin_for_metric schemas_dir output metric_name =
  let schema_file = schemas_dir ^"/"^ metric_name ^".txt" in
  let typ = namesAndTypes schema_file in
  (* Transform the first field if it's a string: *)
  let transform oc frames v =
    match frames with
    | { typ = Types.{ structure = TU64 ; _ } ;
        name = ("capture_begin" | "capture_end") ; _ } :: _ ->
        BE.comment oc "Add some offset to the time stamps" ;
        let offset = Identifier.u64 () in
        (* For now, just output the code to access the global reference
         * directly. Later, have a way to set/get globals. *)
        Printf.fprintf oc.code
          "%slet %a = !Rebinary_plug.offset in" oc.indent
          Identifier.print offset ;
        let s = BE.U64.add oc (Identifier.u64_of_any v) offset in
        Identifier.to_any s
    | _ -> v in
  let tptr = Types.(make TPointer) in
  BE.print_function2 output tptr tptr t_pair_ptrs (fun oc src dst ->
    BE.comment oc "Copy the RowBinary from src to dst" ;
    let src, dst = RB2RB.desser typ ~transform oc src dst in
    BE.make_pair oc t_pair_ptrs src dst)

let replay schemas_dir lib_dir max_msg_size max_tuples_per_msg brokers
           timeout partition full_speed in_files loop =
  (* Prepare the list of files: *)
  let all_files =
    List.filter_map parse_chb_fname in_files |>
    Array.of_list in
  if Array.length all_files <= 0 then (
    Printf.eprintf "Nothing to do!?\n%!" ;
    exit 1) ;
  Printf.printf "%d files to send.\n%!" (Array.length all_files) ;
  let cmp f1 f2 = Float.compare f1.time f2.time in
  Array.fast_sort cmp all_files ;
  (* Create all required plugins *)
  let mode = [ `create ; `text ; `trunc ] in
  let fname =
    Printf.sprintf "/tmp/rebinary_plugins.%s"
      BE.preferred_file_extension in
  let output = BE.make_output () in
  let gen_funcs =
    Array.fold_left (fun gens file ->
      if not (Map.String.mem file.metric gens) then (
        if !debug then
          Printf.printf "Creating plugin for metric %S...\n%!" file.metric ;
        let copy_record =
          create_plugin_for_metric schemas_dir output file.metric in
        Map.String.add file.metric copy_record gens
      ) else gens
    ) Map.String.empty all_files in
  File.with_file_out ~mode fname (fun plugin_oc ->
    BE.print_output plugin_oc output ;
    Map.String.iter (fun metric copy_function ->
      Printf.fprintf plugin_oc
        "let () =\n\
          Printf.printf \"Loaded generated RowBinary (des)ser for %s\\n%!\" ;\n\
          Hashtbl.add Rebinary_plug.copy_functions %S %a\n"
        metric metric
        Identifier.print copy_function
    ) gen_funcs) ;
  let cmxs = Dynlink.adapt_filename fname in
  Printf.printf "Compiling %s...\n%!" cmxs ;
  let cmd =
    Printf.sprintf
      "ocamlfind ocamlopt -g -annot -O3 -I %S \
        -package stdint,batteries,dessser %s -shared -linkall -o %s"
      lib_dir fname cmxs in
  run_cmd cmd ;
  (try Dynlink.loadfile cmxs
  with (Dynlink.Error e) as exn ->
    Printf.eprintf "%s\n%!" (Dynlink.error_message e) ;
    raise exn) ;
  (* Prepare to send Kafka messages: *)
  Printf.printf "Connecting to Kafka\n%!" ;
  let kafka_handler =
    Kafka.new_producer ~delivery_callback [
      "metadata.broker.list", brokers ;
      "message.max.bytes", string_of_int max_msg_size ] in
  let kafka_buffer = Bytes.create max_msg_size in
  let replay_file file =
    if !debug then
      Printf.printf "Replaying file %S...\n%!" file.name ;
    let topic = "pvx.chb."^ file.metric in
    let copy_function = Hashtbl.find Rebinary_plug.copy_functions file.metric in
    let kafka_buffer_bytes = ref 0 in
    let kafka_buffer_tups = ref 0 in
    let append_tuple tup tup_len =
      if !kafka_buffer_bytes + tup_len > max_msg_size ||
         !kafka_buffer_tups >= max_tuples_per_msg then (
        send_to_topic kafka_handler timeout partition topic kafka_buffer !kafka_buffer_bytes !kafka_buffer_tups ;
        Bytes.blit kafka_buffer 0 tup 0 tup_len ;
        kafka_buffer_bytes := tup_len ;
        kafka_buffer_tups := 1
      ) else (
        Bytes.blit kafka_buffer !kafka_buffer_bytes tup 0 tup_len ;
        kafka_buffer_bytes := !kafka_buffer_bytes + tup_len ;
        incr kafka_buffer_tups
      ) ;
    in
    let open DessserOCamlBackendHelpers in
    let input = read_whole_file file.name in
    let src = Pointer.of_string input in
    let rec loop_tuples src =
      if Pointer.remSize src > 0 then
        let sz = 8000 in
        let dst = Pointer.make sz in
        let src, dst = copy_function src dst in
        let b, o, l = dst in
        assert (o < l) ;
        (* Append that tuple into the current message: *)
        append_tuple b o ;
        loop_tuples src in
    loop_tuples src ;
    send_to_topic kafka_handler timeout partition topic kafka_buffer !kafka_buffer_bytes !kafka_buffer_tups ;
    kafka_buffer_bytes := 0 ;
    kafka_buffer_tups := 0
  in
  let start_time = all_files.(0).time in
  let rec replay_all_files () =
    let time_to_now = Unix.time () -. start_time in
    Printf.printf "Will offset all times by %f seconds.\n%!" time_to_now ;
    Rebinary_plug.offset := Uint64.of_float (time_to_now *. 1_000_000.) ;
    let num_files = Array.length all_files in
    let rec loop_files i =
      if i < num_files then (
        replay_file all_files.(i) ;
        if i < num_files - 1 then
          let next_time = all_files.(i + 1).time +. time_to_now in
          let wait_time = next_time -. Unix.time () in
          if wait_time > 0. && not full_speed then (
            if !debug then
              Printf.eprintf "Sleeping for %fs\n%!" wait_time ;
            Unix.sleepf wait_time) ;
          loop_files (i + 1)
      ) in
    loop_files 0 ;
    if loop then replay_all_files () in
  replay_all_files () ;
  release_all_producers kafka_handler

let init debug_arg schemas_dir lib_dir full_speed brokers timeout
         partition max_msg_size max_tuples_per_msg in_files_arg loop =
  debug := debug_arg ;
  let in_files = ref [] in
  let rec add_files fname =
    if Sys.is_directory fname then (
      Printf.printf "Adding all files in %s\n%!" fname ;
      Sys.files_of fname |>
      Enum.iter (fun fname' -> add_files (fname ^"/"^ fname'))
    ) else
      in_files := fname :: !in_files
  in
  List.iter add_files in_files_arg ;
  replay schemas_dir lib_dir max_msg_size max_tuples_per_msg brokers
         timeout partition full_speed !in_files loop

let main =
  let open Cmdliner in
  let start_cmd =
    Printf.printf "Rebinary v%s\n%!" version ;
    let doc = "RowBinary files replayer via Kafka" in
    Term.(
      (const init
        $ Args.debug
        $ Args.schemas_dir
        $ Args.lib_dir
        $ Args.full_speed
        $ Args.brokers
        $ Args.timeout
        $ Args.partition
        $ Args.max_msg_size
        $ Args.max_tuples_per_msg
        $ Args.in_files
        $ Args.loop),
      info "rebinary" ~version ~doc)
  in
  Term.eval start_cmd |> Term.exit
