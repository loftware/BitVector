/// A `Collection` of `Bool` that packs its values into `UnsignedInteger`s to
/// minimize storage overhead.
///
/// `BitMap` acomplishes this by wrapping a `base` `Collection` of some unsigned
/// integer type and allowing access to the underlying bits given an index
/// into `base`, and a bit offset into the value. Values are packed from most to
/// least significant bit in the integer.
///
/// In addition to this indexing scheme, you can also retreive values with just
/// an `Int` index. This gets you the value `n` bits away from the bit at
/// `startIndex`. You can also access the values in the underlying integer
/// collection using the `[packedInteger:]` subscript.
public struct BitMap<
    Base: BidirectionalCollection
> where Base.Element: UnsignedInteger {
    private var endIndexOffset: Int
    private var base: Base

    /// The amount of bits that can be packed into the underlying integer type.
    static internal var packingStride: Int {
        MemoryLayout<Base.Element>.size * 8
    }

    /// Creates a `BitMap` wrapping the given `base` `Collection`.
    ///
    /// All bits in the underlying values of `base` are considered valid
    /// entries in the `BitMap`.
    public init(_ base: Base) {
        self.base = base
        self.endIndexOffset = Self.packingStride
    }

    /// Creates a `BitMap` wrapping the given `base` `Collection` with the last
    /// valid bit at offset `lastIndexOffset` into the last element of `base`.
    public init(_ base: Base, lastIndexOffset: Int) {
        self.base = base
        self.endIndexOffset = lastIndexOffset + 1
    }

    /// The number with only the bit at `offset` set.
    internal func bitmaskFor(offset: Int) -> Base.Element {
        assert(offset >= 0 && offset < Self.packingStride)
        return Base.Element.init(1) << ((Self.packingStride - 1) - offset)
    }

    /// The value packed into a `Base.Element` at the given bit offset.
    private func valuePacked(
        in packed: Base.Element,
        offset: Int
    ) -> Bool {
        return ((packed >> ((Self.packingStride - 1) - offset)) & 1) == 1
    }
}

extension BitMap: BidirectionalCollection {
    /// A position in a `BitMap`.
    public struct Index: Comparable {
        public let index: Base.Index
        public let offset: Int

        init (_ index: Base.Index, offset: Int) {
            self.index = index
            self.offset = offset
        }

        public static func < (lhs: Index, rhs: Index) -> Bool {
            return lhs.index < rhs.index ||
                (lhs.index == rhs.index && lhs.offset < rhs.offset)
        }
    }

    public var startIndex: Index {
        return Index(base.startIndex, offset: 0)
    }

    public var endIndex: Index {
        return Index(
            base.index(before: base.endIndex),
            offset: self.endIndexOffset
        )
    }

    public func index(after i: Index) -> Index {
        if i.offset == Self.packingStride - 1 {
            return Index(base.index(after: i.index), offset: 0)
        }
        return Index(i.index, offset: i.offset + 1)
    }

    public func index(before i: Index) -> Index {
        if i.offset == 0 {
            return Index(base.index(before: i.index),
                offset: Self.packingStride - 1)
        }
        return Index(i.index, offset: i.offset - 1)
    }

    /// The index for the value `depth` bits away from the value at
    /// `startIndex`.
    public func indexFor(depth: Int) -> Index {
        let distanceToIndex = depth / Self.packingStride
        let index = base.index(base.startIndex, offsetBy: distanceToIndex)
        return Index(index, offset: depth % Self.packingStride)
    }

    /// indexFor(depth:) with added bounds checking for setters
    private func checkedIndexFor(depth: Int) -> Index {
        let index = indexFor(depth: depth)
        assert(index < endIndex)
        return index
    }

    // valueAt(index:) and valueAt(depth:) are provided instead of just the
    // subscripts that use it to avoid re-implementing this logic in getters for
    // both the get only and the get + set implementation found in
    // `MutableCollection` conformance.

    private func valueAt(index: Index) -> Bool {
        assert(index < endIndex)
        return valuePacked(in: base[index.index], offset: index.offset)
    }

    /// The value `depth` bits away from the value at `startIndex`.
    private func valueAt(depth: Int) -> Bool {
        return valueAt(index: indexFor(depth: depth))
    }

    /// The raw integer value in the `base` collection at `Base.Index`.
    public subscript(packedInteger i: Base.Index) -> Base.Element {
        return base[i]
    }

    public subscript(position: BitMap.Index) -> Bool {
        valueAt(index: position)
    }

    /// The value `depth` bits away from the value at `startIndex`.
    public subscript(position: Int) -> Bool {
        valueAt(depth: position)
    }
}

extension BitMap: RandomAccessCollection where Base: RandomAccessCollection {}

extension BitMap: MutableCollection where Base: MutableCollection {
    /// The raw integer value in the `base` collection at `Base.Index`.
    public subscript(packedInteger i: Base.Index) -> Base.Element {
        get { base[i] }
        set(newValue) { self.base[i] = newValue }
    }

    public subscript(position: Index) -> Bool {
        get {
            valueAt(index: position)
        }
        set(newValue) {
            assert(position < endIndex)
            let oldPackedValues = self[packedInteger: position.index]
            if newValue {
                self[packedInteger: position.index] =
                    bitmaskFor(offset: position.offset) | oldPackedValues
            } else {
                self[packedInteger: position.index] =
                    ~bitmaskFor(offset: position.offset) & oldPackedValues
            }
        }
    }

    /// The value `depth` bits away from the value at `startIndex`.
    public subscript(position: Int) -> Bool {
        get { valueAt(depth: position) }
        set(newValue) { self[checkedIndexFor(depth: position)] = newValue }
    }
}

// TODO: RangeReplacableCollection conformance