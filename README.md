# LoftDataStructures_Bits

`Bits` is a type which wraps any given collection type of unsigned integers,
and provides an interface to that base collection which allows access to it as
if it were a collection of the bits making up the elements of the underlying
collection. This allows for an extremely compact representation for a collection
of Bools.

`Bits` is indexed by the `Bits.Index` type, which consists of an index into
the wrapped collection, and a bit offset into the element at that position. It
also provides api surface for manipulating the `Bits` as if it was indexed by
`Int`s where the index is the distance of the requested bit from the start of
the collection.