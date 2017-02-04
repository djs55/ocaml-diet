(*
 * Copyright (C) 2016 David Scott <dave@recoil.org>
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
 *
 *)

type t
(** A cluster map which describes cluster usage in the file. The cluster map
    tracks which clusters are free, and which are used, and where the references
    are. *)

type cluster = int64

type reference = cluster * int (* cluster * index within cluster *)

module ClusterBitmap = Qcow_bitmap
module ClusterSet = Qcow_clusterset
module ClusterMap: Map.S with type key = cluster

val zero: t
(** A cluster map for a zero-length disk *)

val make: free:ClusterBitmap.t -> refs:reference ClusterMap.t -> first_movable_cluster:cluster -> t
(** Given a set of free clusters, and the first cluster which can be moved
    (i.e. that isn't fixed header), construct an empty cluster map. *)

val total_used: t -> int64
(** Return the number of tracked used clusters *)

val total_free: t -> int64
(** Return the number of tracked free clusters *)

val add: t -> reference -> cluster -> unit
(** [add t ref cluster] marks [cluster] as in-use and notes the reference from
    [reference]. *)

val remove: t -> cluster -> unit
(** [remove t cluster] marks [cluster] as free and invalidates any reference
    to it (e.g. in response to a discard) *)

val find: t -> cluster -> reference
(** [find t cluster] returns the reference to [cluster], or raises [Not_found] *)

val with_roots: t -> ClusterSet.t -> (unit -> 'a Lwt.t) -> 'a Lwt.t
(** [with_roots t clusters f] calls [f ()} with [clusters] registered as in-use. *)

module Move: sig
  type t = { src: cluster; dst: cluster }
  (** An instruction to move the contents from cluster [src] to cluster [dst] *)
end

val compact_s: (Move.t -> 'a -> ((bool * 'a), 'b) result Lwt.t ) -> t -> 'a
  -> ('a, 'b) result Lwt.t
(** [compact_s f t acc] accumulates the result of [f move] where [move] is
    the next cluster move needed to perform a compaction of [t].. *)

val get_last_block: t -> int64
(** [get_last_block t] is the last allocated block in [t]. Note if there are no
    data blocks this will point to the last header block even though it is
    immovable. *)
