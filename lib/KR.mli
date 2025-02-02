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

module Meta : sig
  type t = Hack | Off | Misc

  val pp : t Fmt.t
  val compare : t -> t -> int
  val pp_template : username:string -> Format.formatter -> unit -> unit
end

module Work : sig
  module Id : sig
    type t =
      | New_KR
      | No_KR
      | ID of string
          (** The kinds of KR identifiers that are possible, a new KR, a no KR
              and a KR with an concrete identifier. *)

    val equal : t -> t -> bool
    (** [equal a b] compares ids [a] and [b] for equality. Matching identifiers
        is not case sensitive. *)

    val pp : t Fmt.t
  end

  type t = {
    id : Id.t;
    title : string;
    start_quarter : Quarter.t option;
    end_quarter : Quarter.t option;
  }

  val v :
    title:string ->
    id:Id.t ->
    start_quarter:Quarter.t option ->
    end_quarter:Quarter.t option ->
    t

  val pp : t Fmt.t
end

(** For type [t]. *)
module Kind : sig
  type t = Meta of Meta.t | Work of Work.t
end

type t = private {
  kind : Kind.t;
  project : string;
  objective : string;
  time_entries : (string * Time.t) list list;
  time_per_engineer : (string, Time.t) Hashtbl.t;
  work : Item.t list list;
}

(** For [Parser.of_markdown]. *)
module Heading : sig
  type t = Meta of Meta.t | Work of string * Work.Id.t option

  val of_string : ?week:Week.t -> string -> t
  val pp : t Fmt.t
end

(** For [Aggregate.by_kr] and [Report.find]. *)
module Id : sig
  type t = Kind.t

  val pp : t Fmt.t
  val compare : t -> t -> int
end

module Warning : sig
  type t =
    [ `Migration_warning of
      Work.t (* work-item *) * Work.t option (* objective *)
      (** For reports written before June 10, 2024 (week 24). *) ]

  val pp : t Fmt.t
  val pp_short : t Fmt.t
  val greppable : t -> string option
end

module Error : sig
  type t =
    [ `Objective_not_found of Work.t
    | `Migration_error of Work.t (* work-item *) * Work.t option (* objective *)
      (** For reports written from June 10, 2024 (week 24). *) ]

  val pp : t Fmt.t
  val pp_short : t Fmt.t
  val greppable : t -> string option
end

val v :
  kind:Kind.t ->
  project:string ->
  objective:string ->
  time_entries:(string * Time.t) list list ->
  Item.t list list ->
  t

val dump : t Fmt.t
val merge : t -> t -> t
val compare : t -> t -> int

val update_from_master_db :
  ?week:Week.t ->
  ?quarter:Quarter.t ->
  t ->
  Masterdb.t ->
  t * [> Warning.t | Error.t ] option

(** {2 Pretty-print} *)

val items :
  ?show_time:bool ->
  ?show_time_calc:bool ->
  ?show_engineers:bool ->
  t ->
  Item.t list
