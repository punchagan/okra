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

module Objective : sig
  type status_t = Todo | In_progress | Paused | Complete | Closed

  type elt_t = private {
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

  val string_of_status : status_t -> string
  val load_csv : ?separator:char -> string -> (t, [ `Msg of string ]) result
  val find_kr_opt : t -> string -> elt_t option
  val find_title_opt : t -> string -> elt_t option
  val find_krs_for_teams : t -> string list -> elt_t list
end

module Work_item : sig
  type elt_t = private {
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

  val load_csv : ?separator:char -> string -> (t, [ `Msg of string ]) result
  val find_title_opt : t -> string -> elt_t option
end

type t = { objective_db : Objective.t; work_item_db : Work_item.t option }
