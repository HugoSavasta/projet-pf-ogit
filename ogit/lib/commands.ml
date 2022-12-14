(** fichier commands.ml **)
(** fonctions représentant les commandes ogit **)

(*voir comment compiler pour utiliser les modules*)

let ogit_init () = 
  begin
  if Sys.file_exists ".ogit" then 
    raise (Failure "ogit: already an ogit repository")
  else
    let err = Sys.command ("mkdir .ogit && mkdir .ogit/logs && mkdir .ogit/objects && touch .ogit/HEAD") in 
    if err <> 0 then raise (Failure "ogit: error while creating the repository");
  let _ = Logs.store_commit(Logs.init_commit () ) in ()
  end

let ogit_commit _msg = 
  (*ogit commit “<description>” : parcourt récursivement l’arbre de travail et
    ajoute tous les nouveaux états rencontrés, puis ajoute le commit correspondant 
    avec pour parent le commit HEAD. Les fichiers dont le nom commence 
    par un point (e.g. “.mvn”) sont ignorés*)
  let tmp = Logs.make_commit _msg (Digest.to_hex(Objects.store_work_directory ())) in
  let head = Logs.store_commit tmp in
  Logs.set_head [head]
  
let better_hash _hash =
  let len = String.length _hash in
  if len < 4 then failwith "Hash must be > 4 characters"
  else
    let hashlist = Sys.readdir ".ogit/logs" in
    let rec aux i res=
      if i = Array.length hashlist then match (List.length res) with
        | 0 -> failwith "No match found"
        | 1 -> List.hd res
        | _ -> failwith "Multiple matches found"
      else
        let hash = hashlist.(i) in
        if String.sub hash 0 len = _hash then aux (i+1) (hash::res)
        else aux (i+1) res
    in aux 0 []
      
let ogit_checkout _hash = 
(*Ouvrir logs du hash, lire le fichier, parcourir tout et remplacer*)
  let hashtemp=better_hash _hash in
  if Sys.file_exists( ".ogit/logs/" ^hashtemp) then
    let actualCommit = Logs.read_commit (Digest.from_hex hashtemp) in
    let _obj = Objects.read_directory_object actualCommit.content in
    let _ = Objects.restore_work_directory _obj
    in Logs.set_head [Digest.from_hex hashtemp]
  else failwith "Hash inconnu"

let ogit_log () = 
  let rec aux hd result = 
    if hd = [] then ()
    else
      try 
        let commit = Logs.read_commit (List.hd hd) in
        aux (commit.parents) (["commit " ^ Digest.to_hex(List.hd hd) ^ " " ^ commit.message]@result)
      with _ ->
        let rec aux2 l2 = match l2 with
          | [] -> ()
          | h::t -> begin Printf.printf "%s\n" h; aux2 t end
        in aux2 (result)
  in aux (Logs.get_head ()) []
  
let ogit_merge _hash = 
    let hashtemp = Digest.from_hex (better_hash _hash) in
    (*List.iter (check_parent hashtemp) (Logs.get_head ());
      Voir comment faire ça / voir son utilité*)
    let actualCommit = Logs.read_commit hashtemp in
        Logs.set_head ((Logs.get_head() ) @ actualCommit.parents);
        if Objects.merge_work_directory_I (Objects.read_directory_object actualCommit.content) then
          ogit_commit ("Merge de " ^ (Digest.to_hex hashtemp)) (*Message du commit = Merge de <son hash>*)
        else failwith "Merge impossible"

let ogit_merge_II _hash = 
  let hashtemp = Digest.from_hex (better_hash _hash) in
  (*List.iter (check_parent hashtemp) (Logs.get_head ());
    Voir comment faire ça / voir son utilité*)
  let actualCommit = Logs.read_commit hashtemp in
      Logs.set_head ((Logs.get_head() ) @ actualCommit.parents);
      if Objects.merge_work_directory_II (Objects.read_directory_object actualCommit.content) then
        ogit_commit ("Merge de " ^ (Digest.to_hex hashtemp)) (*Message du commit = Merge de <son hash>*)
      else failwith "Merge impossible"