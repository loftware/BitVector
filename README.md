# LoftDataStructures_Bits

`Bits` projects any underlying collection of unsigned integers as a collection
of `Bool`, with each element with each element of the `Bits` being true iff a corresponding bit in one of the underlying collection's elements is set.

`Bits` is indexed by the `Bits.Index` type, which consists of an index into the
wrapped collection, and a bit offset into the element at that position where the bit at offset 0 in an integer is the most significant bit. It also
provides api surface for manipulating the `Bits` as if it was indexed by `Int`s
where the index is the distance of the requested bit from the start of the
collection.