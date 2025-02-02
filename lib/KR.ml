(*
 * Copyright (c) 2021 Magnus Skjegstad <magnus@skjegstad.com>
 * Copyright (c) 2021 Thomas Gazagnaire <thomas@gazagnaire.org>
 * Copyright (c) 2021 Patrick Ferris <pf341@patricoferris.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

let src = Logs.Src.create "okra.KR"

module Log = (val Logs.src_log src : Logs.LOG)

let compare_no_case x y =
  let x = String.uppercase_ascii x in
  let y = String.uppercase_ascii y in
  String.compare x y

module Meta = struct
  type t = Hack | Off | Misc

  let pp ppf = function
    | Hack -> Fmt.pf ppf "Hack"
    | Off -> Fmt.pf ppf "Off"
    | Misc -> Fmt.pf ppf "Misc"

  let of_string ?week s =
    let supported =
      match week with
      | Some file_week ->
          (* June 10 - June 16 *)
          let limit = { Week.year = 2024; week = 24 } in
          Week.compare file_week limit >= 0
      | None -> true
    in
    if supported then
      match String.lowercase_ascii s with
      | "hack" -> Some Hack
      | "off" -> Some Off
      | "misc" -> Some Misc
      | _ -> None
    else None

  let compare x y =
    String.compare (Fmt.to_to_string pp x) (Fmt.to_to_string pp y)

  let pp_template ~username ppf () =
    let pp_user ppf () = User.pp ~with_link:false ppf username in
    Fmt.pf ppf
      {|
- Misc
  - %a (0 days)
  - Any work that does not fall under specific objectives, including meetings, management work, offsite, workshops, training, conferences, tech talks and all hands.

- Hack
  - %a (0 days)
  - Hacking Days.

- Off
  - %a (0 days)
  - Any kind of leaves, holidays, time off from work, including 2-week August company break.
|}
      pp_user () pp_user () pp_user ()
end

module Work = struct
  module Id = struct
    type t = New_KR | No_KR | ID of string

    let pp ppf = function
      | New_KR -> Fmt.pf ppf "New KR"
      | No_KR -> Fmt.pf ppf "No KR"
      | ID s -> Fmt.pf ppf "%s" s

    let equal a b =
      match (a, b) with
      | New_KR, New_KR | No_KR, No_KR -> true
      | ID id1, ID id2 -> compare_no_case id1 id2 = 0
      | _ -> false

    let okr_re = Str.regexp "\\([a-zA-Z#]+[0-9]+\\)"
    (* Legacy KR: (KR12) *)
    (* GitHub WI: (12) *)

    let of_string s =
      match String.lowercase_ascii s with
      | "new kr" | "new okr" | "new wi" -> Some New_KR
      | "no kr" | "no okr" | "no wi" -> Some No_KR
      | _ -> (
          match Str.string_match okr_re s 0 with
          | false -> None
          | true ->
              let id = String.trim (Str.matched_group 1 s) in
              Some (ID id))

    let merge x y =
      match (x, y) with
      | ID x, ID y ->
          assert (compare_no_case x y = 0);
          ID x
      | ID x, _ | _, ID x -> ID x
      | No_KR, No_KR -> No_KR
      | New_KR, New_KR -> New_KR
      | No_KR, New_KR | New_KR, No_KR -> New_KR
  end

  type t = {
    id : Id.t;
    title : string;
    start_quarter : Quarter.t option;
    end_quarter : Quarter.t option;
  }

  let dump =
    let open Fmt.Dump in
    record
      [
        field "title" (fun t -> t.title) string;
        field "id" (fun t -> t.id) Id.pp;
        field "start quarter" (fun t -> t.start_quarter) (Fmt.option Quarter.pp);
        field "end quarter" (fun t -> t.end_quarter) (Fmt.option Quarter.pp);
      ]

  let pp ppf x = Format.fprintf ppf "%s (%a)" x.title Id.pp x.id

  let v ~title ~id ~start_quarter ~end_quarter =
    { title; id; start_quarter; end_quarter }

  let compare a b =
    match (a.id, b.id) with
    | ID a, ID b -> compare_no_case a b
    | _ -> compare_no_case a.title b.title

  let merge x y =
    let title =
      match (x.title, y.title) with
      | "", s | s, "" -> s
      | x, y ->
          if compare_no_case x y <> 0 then
            Log.warn (fun l -> l "Conflicting titles:\n- %S\n- %S" x y);
          x
    in
    let start_quarter =
      match (x.start_quarter, y.start_quarter) with None, q | q, _ -> q
    in
    let end_quarter =
      match (x.end_quarter, y.end_quarter) with None, q | q, _ -> q
    in
    let id = Id.merge x.id y.id in
    { title; id; start_quarter; end_quarter }
end

module Heading = struct
  type t = Meta of Meta.t | Work of string * Work.Id.t option

  let pp ppf = function
    | Meta x -> Fmt.pf ppf "%a" Meta.pp x
    | Work (s, Some id) -> Fmt.pf ppf "%s (%a)" s Work.Id.pp id
    | Work (s, None) -> Fmt.pf ppf "%s" s

  let sub_opt s x y =
    match String.sub s x y with
    | exception Invalid_argument _ -> None
    | r -> Some r

  let of_string ?week s =
    let title, id =
      match String.rindex_opt s '(' with
      | None -> (Some s, None)
      | Some opn_par ->
          let title = String.sub s 0 opn_par in
          let end_index =
            match String.rindex_opt s ')' with
            | None -> String.length s
            | Some cls_par -> cls_par
          in
          let id = sub_opt s (opn_par + 1) (end_index - opn_par - 1) in
          (Some title, id)
    in
    match title with
    | Some title -> (
        let title = String.trim title in
        match Meta.of_string ?week title with
        | Some m -> Meta m
        | None -> (
            match id with
            | Some id -> (
                let id = String.trim id in
                match Work.Id.of_string id with
                | Some id -> Work (title, Some id)
                | None -> Work (title, None))
            | None -> Work (title, None)))
    | None -> Work (s, None)
end

module Kind = struct
  type t = Meta of Meta.t | Work of Work.t

  let pp ppf = function Meta x -> Meta.pp ppf x | Work x -> Work.pp ppf x
  let dump ppf = function Meta x -> Meta.pp ppf x | Work x -> Work.dump ppf x

  let merge x y =
    match (x, y) with
    | Meta x, Meta y ->
        assert (Meta.compare x y = 0);
        Meta x
    | Work x, Work y -> Work (Work.merge x y)
    | Meta _, Work _ -> assert false
    | Work _, Meta _ -> assert false

  let compare a b =
    let meta = Fmt.to_to_string Meta.pp in
    let work = Fmt.to_to_string Work.pp in
    match (a, b) with
    | Meta a, Meta b -> String.compare (meta a) (meta b)
    | Meta a, Work b -> String.compare (meta a) (work b)
    | Work a, Meta b -> String.compare (work a) (meta b)
    | Work a, Work b -> Work.compare a b
end

module Id = struct
  type t = Kind.t

  let pp ppf = function
    | Kind.Meta x -> Meta.pp ppf x
    | Kind.Work x -> Work.pp ppf x

  let compare = Kind.compare
end

type t = {
  kind : Kind.t;
  project : string;
  objective : string;
  time_entries : (string * Time.t) list list;
  time_per_engineer : (string, Time.t) Hashtbl.t;
  work : Item.t list list;
}

let v ~kind ~project ~objective ~time_entries work =
  (* Sum time per engineer *)
  let time_per_engineer =
    let tbl = Hashtbl.create 7 in
    List.iter
      (List.iter (fun (e, d) ->
           let open Time in
           let d =
             match Hashtbl.find_opt tbl e with None -> d | Some x -> x + d
           in
           Hashtbl.replace tbl e d))
      time_entries;
    tbl
  in
  { kind; project; objective; time_entries; time_per_engineer; work }

let dump =
  let open Fmt.Dump in
  record
    [
      field "kind" (fun t -> t.kind) Kind.dump;
      field "project" (fun t -> t.project) string;
      field "objective" (fun t -> t.objective) string;
      field "time_entries"
        (fun t -> t.time_entries)
        (list (list (pair string Time.pp)));
      field "time_per_engineer"
        (fun t -> List.of_seq (Hashtbl.to_seq t.time_per_engineer))
        (list (pair string Time.pp));
      field "work" (fun t -> t.work) (list (list Item.dump));
    ]

let merge x y =
  let kind = Kind.merge x.kind y.kind in
  let project =
    match (x.project, y.project) with
    | "", s | s, "" -> s
    | x, y ->
        if compare_no_case x y <> 0 then
          Log.warn (fun l ->
              l "KR %a appears in two projects:\n- %S\n- %S" Kind.pp kind x y);
        x
  in
  let objective =
    match (x.objective, y.objective) with
    | "", s | s, "" -> s
    | x, y ->
        if compare_no_case x y <> 0 then
          Log.warn (fun l ->
              l "KR %a appears in two objectives:\n- %S\n- %S" Kind.pp kind x y);
        x
  in
  let time_entries = x.time_entries @ y.time_entries in
  let time_per_engineer =
    let t = Hashtbl.create 13 in
    Hashtbl.iter (fun k v -> Hashtbl.add t k v) x.time_per_engineer;
    Hashtbl.iter
      (fun k v ->
        let open Time in
        match Hashtbl.find_opt t k with
        | None -> Hashtbl.replace t k v
        | Some v' -> Hashtbl.replace t k (v + v'))
      y.time_per_engineer;
    t
  in
  let work = x.work @ y.work in
  { kind; project; objective; time_entries; time_per_engineer; work }

let compare a b = Kind.compare a.kind b.kind

let make_engineer ~time (e, d) =
  if time then Fmt.str "%a (%a)" (User.pp ~with_link:false) e Time.pp d
  else Fmt.str "%a" (User.pp ~with_link:true) e

let make_engineers ~time entries =
  let entries = List.of_seq (Hashtbl.to_seq entries) in
  let entries = List.sort (fun (x, _) (y, _) -> String.compare x y) entries in
  let engineers = List.rev_map (make_engineer ~time) entries in
  match engineers with
  | [] -> []
  | e :: es ->
      let lst =
        List.fold_left
          (fun acc engineer ->
            Omd.Text ([], engineer) :: Text ([], ", ") :: acc)
          [ Omd.Text ([], e) ]
          es
      in
      [ Omd.Paragraph ([], Concat ([], lst)) ]

let make_time_entries t =
  let aux (e, d) = Fmt.str "@%s (%a)" e Time.pp d in
  [ Omd.Paragraph ([], Text ([], String.concat ", " (List.map aux t))) ]

module Warning = struct
  type t = [ `Migration_warning of Work.t * Work.t option ]

  let pp ppf = function
    | `Migration_warning (work_item, None) ->
        Fmt.pf ppf
          "Invalid objective:@ \"%a\" is a work-item. You should use an \
           objective instead."
          Work.pp work_item
    | `Migration_warning (work_item, Some obj) ->
        Fmt.pf ppf
          "Invalid objective:@ \"%a\" is a work-item. You should use its \
           parent objective \"%a\" instead."
          Work.pp work_item Work.pp obj

  let pp_short ppf = function
    | `Migration_warning (work_item, None) ->
        Fmt.pf ppf "Invalid objective: \"%a\" (work-item)" Work.pp work_item
    | `Migration_warning (work_item, Some obj) ->
        Fmt.pf ppf "Invalid objective: \"%a\" (work-item), use \"%a\" instead"
          Work.pp work_item Work.pp obj

  let greppable = function
    | `Migration_warning (work_item, _) -> Some work_item.Work.title
end

module Error = struct
  type t =
    [ `Objective_not_found of Work.t
    | `Migration_error of Work.t * Work.t option ]

  let pp ppf = function
    | `Objective_not_found x -> Fmt.pf ppf "Invalid objective:@ %S" x.Work.title
    | `Migration_error x -> Warning.pp ppf (`Migration_warning x)

  let pp_short ppf = function
    | `Objective_not_found x ->
        Fmt.pf ppf "Invalid objective: %S (not found)" x.Work.title
    | `Migration_error x -> Warning.pp_short ppf (`Migration_warning x)

  let greppable = function
    | `Objective_not_found x -> Some x.Work.title
    | `Migration_error x -> Warning.greppable (`Migration_warning x)
end

let update_from_master_db ?week ?quarter orig_kr db =
  let post_week_24 =
    match week with
    | Some file_week ->
        (* June 10 - June 16 *)
        let limit = { Week.year = 2024; week = 24 } in
        Week.compare file_week limit >= 0
    | None -> false
  in
  match orig_kr.kind with
  | Meta _ -> (orig_kr, None)
  | Work orig_work -> (
      let db_kr =
        match orig_work.id with
        | ID id -> Masterdb.Objective.find_kr_opt db.Masterdb.objective_db id
        | _ -> Masterdb.Objective.find_title_opt db.objective_db orig_work.title
      in
      match db_kr with
      | None -> (
          if orig_work.id = New_KR then
            Log.warn (fun l ->
                l "KR ID not found for new KR %S" orig_work.title);
          match db.work_item_db with
          (* Not found in objectives, no WI database *)
          | None -> (orig_kr, Some (`Objective_not_found orig_work))
          | Some work_item_db -> (
              match
                Masterdb.Work_item.find_title_opt work_item_db orig_work.title
              with
              (* Not found in objectives, not found in workitems *)
              | None ->
                  let error =
                    match orig_work.id with
                    | No_KR | New_KR ->
                        if post_week_24 then
                          Some (`Objective_not_found orig_work)
                        else None
                    | ID _ -> Some (`Objective_not_found orig_work)
                  in
                  (orig_kr, error)
              | Some work_item_kr ->
                  let work_item = orig_work in
                  let kr, objective =
                    match
                      Masterdb.Objective.find_title_opt db.objective_db
                        work_item_kr.objective
                    with
                    (* Not found in objectives, found in WI db, no objective *)
                    | None -> (orig_kr, None)
                    (* Not found in objectives, found in WI db, has objective *)
                    | Some
                        {
                          printable_id = id;
                          title;
                          start_quarter;
                          end_quarter;
                          _;
                        } ->
                        if
                          Quarter.check quarter ~starts:start_quarter
                            ~ends:end_quarter
                        then
                          let obj =
                            {
                              Work.id = ID id;
                              title;
                              start_quarter;
                              end_quarter;
                            }
                          in
                          let new_kr = { orig_kr with kind = Work obj } in
                          (new_kr, Some obj)
                        else (orig_kr, None)
                  in
                  let error =
                    if post_week_24 then
                      Some (`Migration_error (work_item, objective))
                    else None
                  in
                  (kr, error)))
      | Some db_kr ->
          if orig_work.id = No_KR then
            Log.warn (fun l ->
                l "KR ID updated from \"No KR\" to %S:\n- %S\n- %S" db_kr.id
                  orig_work.title db_kr.title);
          let work =
            {
              Work.id = ID db_kr.printable_id;
              title = db_kr.title;
              start_quarter = db_kr.start_quarter;
              end_quarter = db_kr.end_quarter;
            }
          in
          let kr = { orig_kr with kind = Work work } in
          (* show the warnings *)
          ignore (merge orig_kr kr);
          (kr, None))

let items ?(show_time = true) ?(show_time_calc = false) ?(show_engineers = true)
    kr =
  let items =
    if not show_engineers then []
    else if show_time then
      if show_time_calc then
        (* show time calc + engineers *)
        [
          Omd.List
            ([], Bullet '+', Tight, List.map make_time_entries kr.time_entries);
          List
            ( [],
              Bullet '=',
              Tight,
              [ make_engineers ~time:true kr.time_per_engineer ] );
        ]
      else make_engineers ~time:true kr.time_per_engineer
    else make_engineers ~time:false kr.time_per_engineer
  in
  [
    Omd.List
      ( [],
        Bullet '-',
        Tight,
        [
          [
            Paragraph ([], Text ([], Fmt.str "%a" Kind.pp kr.kind));
            List ([], Bullet '-', Tight, items :: kr.work);
          ];
        ] );
  ]
