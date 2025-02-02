(*
 * Copyright (c) 2021 Magnus Skjegstad <magnus@skjegstad.com>
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

let pp_error_kw =
  Fmt.styled `Bold
  @@ Fmt.styled (`Fg `Red)
  @@ fun ppf () -> Fmt.pf ppf "%s" "Error"

let pp_error line_number filename k =
  let pp_loc =
    Fmt.styled `Bold @@ fun ppf (filename, line_number) ->
    Fmt.pf ppf "File %S, line %i" filename line_number
  in
  k (fun ppf ->
      Fmt.pf ppf "@[<hv 0>@{<loc>%a@}:@\n%a: " pp_loc (filename, line_number)
        pp_error_kw ();
      Fmt.kpf (fun ppf -> Fmt.pf ppf "@]@,") ppf)

let msg_to_error line_number filename msg =
  pp_error line_number filename (fun m -> m Format.str_formatter "%s") msg;
  Format.flush_str_formatter ()

module Objective = struct
  type status_t = Todo | In_progress | Paused | Complete | Closed

  type elt_t = {
    id : string;
    printable_id : string;
    title : string;
    project : string;
    team : string;
    status : status_t option;
    start_quarter : Quarter.t option;
    end_quarter : Quarter.t option;
  }

  type t = (string, elt_t) Hashtbl.t

  let status_of_string s =
    match Astring.String.cuts ~sep:" " (String.uppercase_ascii s) with
    | "TODO" :: _ -> Some Todo
    | "IN" :: "PROGRESS" :: _ -> Some In_progress
    | "PAUSED" :: _ -> Some Paused
    | "COMPLETE" :: _ -> Some Complete
    | "CLOSED" :: _ -> Some Closed
    | _ -> None

  let string_of_status s =
    match s with
    | Todo -> "Todo"
    | In_progress -> "In Progress"
    | Paused -> "Paused"
    | Complete -> "Complete"
    | Closed -> "Closed"

  let empty_db = Hashtbl.create 13

  let load_csv ?(separator = ',') f =
    let ( let* ) = Result.bind in
    let res = empty_db in
    let line = ref 1 in
    let ic = open_in f in
    try
      let rows = Csv.of_channel ~separator ~has_header:true ic in
      let* () =
        Csv.Rows.fold_left ~init:(Ok ())
          ~f:(fun acc row ->
            let* () = acc in
            line := !line + 1;
            let find_and_trim col = Csv.Row.find row col |> String.trim in
            let printable_id = find_and_trim "id" in
            let* start_quarter =
              find_and_trim "start on quarter" |> Quarter.of_string
            in
            let* end_quarter =
              find_and_trim "end on quarter" |> Quarter.of_string
            in
            let e =
              {
                id = String.uppercase_ascii printable_id;
                printable_id;
                title = find_and_trim "title";
                project = find_and_trim "project";
                team = find_and_trim "team";
                status = find_and_trim "status" |> status_of_string;
                start_quarter;
                end_quarter;
              }
            in
            let* () =
              Result.map_error (fun (`Msg e) -> `Msg (msg_to_error !line f e))
              @@
              if e.id = "" then
                Fmt.error_msg "A unique KR ID is required per line"
              else if e.id <> "#" && Hashtbl.mem res e.id then
                Fmt.error_msg "KR ID %S is not unique." e.id
              else if e.title = "" then
                Fmt.error_msg "KR ID %S does not have a title" e.id
              else Ok ()
            in
            Hashtbl.add res e.id e;
            Ok ())
          rows
      in
      Ok res
    with e ->
      close_in_noerr ic;
      Error (`Msg (Printexc.to_string e))

  let find_kr_opt t id = Hashtbl.find_opt t (id |> String.uppercase_ascii)

  let find_title_opt t title =
    let title_no_case = title |> String.uppercase_ascii |> String.trim in
    let okrs = Hashtbl.to_seq_values t |> List.of_seq in
    List.find_opt
      (fun kr ->
        kr.title |> String.uppercase_ascii |> String.trim = title_no_case)
      okrs

  let filter_krs t f =
    let v = Hashtbl.to_seq_values t in
    List.of_seq (Seq.filter f v)

  let find_krs_for_teams t teams =
    let teams = List.map String.uppercase_ascii teams in
    let p e =
      List.exists (String.equal (String.uppercase_ascii e.team)) teams
    in
    filter_krs t p
end

module Work_item = struct
  type elt_t = {
    id : string;
    printable_id : string;
    title : string;
    objective : string;
    project : string;
    team : string;
    status : string;
    quarter : Quarter.t option;
  }

  type t = (string, elt_t) Hashtbl.t

  let empty_db = Hashtbl.create 13

  let load_csv ?(separator = ',') f =
    let ( let* ) = Result.bind in
    let res = empty_db in
    let line = ref 1 in
    let ic = open_in f in
    try
      let rows = Csv.of_channel ~separator ~has_header:true ic in
      let* () =
        Csv.Rows.fold_left ~init:(Ok ())
          ~f:(fun acc row ->
            let* () = acc in
            line := !line + 1;
            let find_and_trim col = Csv.Row.find row col |> String.trim in
            let printable_id = find_and_trim "id" in
            let* quarter = find_and_trim "quarter" |> Quarter.of_string in
            let e =
              {
                id = String.uppercase_ascii printable_id;
                printable_id;
                title = find_and_trim "title";
                objective = find_and_trim "objective";
                project = find_and_trim "project";
                team = find_and_trim "team";
                status = find_and_trim "status";
                quarter;
              }
            in
            let* () =
              Result.map_error (fun (`Msg e) -> `Msg (msg_to_error !line f e))
              @@
              if e.id = "" then
                Fmt.error_msg "A unique KR ID is required per line"
              else if e.id <> "#" && Hashtbl.mem res e.id then
                Fmt.error_msg "KR ID %S is not unique." e.id
              else if e.title = "" then
                Fmt.error_msg "KR ID %S does not have a title" e.id
              else Ok ()
            in
            Hashtbl.add res e.id e;
            Ok ())
          rows
      in
      Ok res
    with e ->
      close_in_noerr ic;
      Error (`Msg (Printexc.to_string e))

  let find_title_opt t title =
    let title_no_case = title |> String.uppercase_ascii |> String.trim in
    let okrs = Hashtbl.to_seq_values t |> List.of_seq in
    List.find_opt
      (fun kr ->
        kr.title |> String.uppercase_ascii |> String.trim = title_no_case)
      okrs
end

type t = { objective_db : Objective.t; work_item_db : Work_item.t option }
