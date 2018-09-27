(* Tool to find long stretches of worthy CSV files, for tests.  *)
open Batteries
open RamenHelpers

let () =
  let dir = ref "." in
  let metrics = ref "tcp,udp,icmp,other_ip,non_ip,dns,http,citrix,\
                     citrix_chanless,smb,sql,voip" in
  Arg.parse [
    "-dir", Set_string dir, "directory where the files are" ;
    "-metrics", Set_string metrics, "list (coma separated) of metrics to \
                                    consider a set complete" ]
    (fun s -> raise (Arg.Bad ("unknown argument "^ s)))
    "findcsv -dir ... -metrics tcp,udp,..." ;
  let metrics =
    String.nsplit ~by:"," !metrics |>
    List.map String.trim |>
    Set.String.of_list in
  Printf.eprintf "Reading files...%!" ;
  let files = Sys.files_of !dir in
  let num_files = ref 0 ;
  and num_csv = ref 0 in
  let fre = Str.regexp {|^\([a-z_]+\)_v29\.\([0-9]+\)\.csv\.lz4$|} in
  let sets = Hashtbl.create 9999 in
  Enum.iter (fun f ->
    incr num_files ;
    if Str.string_match fre f 0 then (
      incr num_csv ;
      let metric = Str.matched_group 1 f
      and ts = Str.matched_group 2 f |> int_of_string in
      Hashtbl.modify_opt ts (function
        | None -> Some (Set.String.singleton metric)
        | Some s -> Some (Set.String.add metric s)
      ) sets)
  ) files ;
  Printf.eprintf "done %d csv over %d files!\n%!" !num_csv !num_files ;
  Printf.eprintf "Removing incomplete sets...%!" ;
  let ts_set =
    Hashtbl.fold (fun ts s ts_set ->
      if Set.String.subset metrics s then
        Set.Int.add ts ts_set else ts_set
    ) sets Set.Int.empty in
  Printf.eprintf "Removed %d sets out of %d\n%!"
    (Hashtbl.length sets - Set.Int.cardinal ts_set)
    (Hashtbl.length sets) ;
  let packs = Hashtbl.create 9999 in
  let rec compact ts_set =
    if not (Set.Int.is_empty ts_set) then (
      let min_ts, ts_set = Set.Int.pop_min ts_set in
      let rec absorb count ts ts_set =
        if Set.Int.mem ts ts_set then
          absorb (count + 1) (ts + 60) (Set.Int.remove ts ts_set)
        else count, ts_set in
      let count, ts_set = absorb 1 (min_ts + 60) ts_set in
      Hashtbl.add packs min_ts count ;
      compact ts_set) in
  compact ts_set ;
  let tss = Hashtbl.keys packs |> Array.of_enum in
  Array.fast_sort Int.compare tss ;
  let ctime i = ctime (float_of_int i) in
  let max_ts, max_count =
    Array.fold_left (fun (_max_ts, max_count as prev) ts ->
      let count = Hashtbl.find packs ts in
      (*let date = ctime ts in
      Printf.printf "%s %d %d\n" date ts count;*)
      if count > max_count then ts, count else prev
    ) (0, 0) tss in
  Printf.eprintf "Max %d consecutive sets (%f hours) at %s (%d)\n"
    max_count (float_of_int max_count /. 60.) (ctime max_ts) max_ts ;
  let rec files lst n ts =
    if n >= max_count then lst else (
      let lst =
        Set.String.fold (fun metric lst ->
          (metric ^"_v29."^ string_of_int ts ^".csv.lz4") :: lst
        ) metrics lst in
      files lst (n + 1) (ts + 60)
    ) in
  let files = files [] 0 max_ts in
  List.print ~first:"" ~last:"" ~sep:"\n" String.print stdout files

