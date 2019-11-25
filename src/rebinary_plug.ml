type copy_function =
  bytes * int * int ->
  bytes * int * int ->
    (bytes * int * int) * (bytes * int * int)

(* all copy functions per metric *)
let copy_functions : (string, copy_function) Hashtbl.t = Hashtbl.create 20

let offset = ref Stdint.Uint64.zero
