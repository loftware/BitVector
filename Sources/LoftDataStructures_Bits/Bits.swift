import LoftNumerics_Modulo
import LoftNumerics_IntegerDivision

/// A `Collection` of `Bool` that packs its values into `UnsignedInteger`s to
/// minimize storage overhead.
///
/// `Bits` acomplishes this by wrapping a `base` `Collection` of some unsigned
/// integer type and allowing access to the underlying bits given an index
/// into `base`, and a bit offset. The most significant bit of the
///
/// In addition to this indexing scheme, you can also retrieve values with just
/// an `Int` index. This gets you the value `n` bits away from the bit at
/// `startIndex`. You can also access the values in the underlying integer
/// collection using the `[packedInteger:]` subscript.
public struct Bits<
    Base: RandomAccessCollection
> where Base.Element: BinaryInteger {
    public typealias SubSequence = Slice<Self>
    /// One more than the offset into the last `Element` of the last bit in the
    /// `Bits`.
    internal var endIndexOffset: Int // @testable
    /// The `BidirectionalCollection` containing the `BinaryIntegers` which this
    /// this `Bits` projects the bits of.
    private var base: Base

    /// The number of bits in the underlying integer type.
    static internal var underlyingBitWidth: Int {
        MemoryLayout<Base.Element>.bitSize
    }

    /// Creates an instance whose elements are `true` iff the coresponding bit
    /// in an element of `base` is set.
    ///
    /// Each bit in an element of `base` is represented in the new instance.
    public init(wrapping base: Base) {
        self.base = base
        self.endIndexOffset = Self.underlyingBitWidth
    }

    /// Creates an instance whose elements are `true` iff the coresponding bit
    /// in an element of `base` is set.
    ///
    /// Each bit in an element of `base` is represented in the new instance
    /// except for those `endIndexOffset` or greater bits into the last element
    /// of `base`
    public init(_ base: Base, endIndexOffset: Int) {
        self.base = base
        self.endIndexOffset = endIndexOffset
    }

    /// The integer with only the bit at `n` set.
    internal func nthBitSet(_ n: Int) -> Base.Element {
        assert(n >= 0 && n < Self.underlyingBitWidth)
        return Base.Element.init(1) << ((Self.underlyingBitWidth - 1) - n)
    }

    /// If the bit `offset` bits into a `Base.Element` is set.
    ///
    /// The bit at an `offset` of zero is the most significant bit.
    private func valuePacked(
        in packed: Base.Element,
        offset: Int
    ) -> Bool {
        return ((packed >> ((Self.underlyingBitWidth - 1) - offset)) & 1) == 1
    }
}

extension Bits where Base: RangeReplaceableCollection {
    /// Creates an instance with the given elements.
    public init<S: Sequence>(_ bits: S) where S.Element == Bool {
        self = .init(.init(), endIndexOffset: 0)
        self.append(contentsOf: bits)
    }
}

extension Bits: ExpressibleByArrayLiteral
where Base: RangeReplaceableCollection {
    public init(arrayLiteral: Bool...) {
        self = .init(arrayLiteral)
    }
}

extension Bits: RandomAccessCollection {
    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        if endIndexOffset == Self.underlyingBitWidth || endIndexOffset == 0 {
            return base.distance(from: base.startIndex, to: base.endIndex)
                * Self.underlyingBitWidth
        }
        return base.distance(from: base.startIndex,
            to: base.index(before: base.endIndex)) * Self.underlyingBitWidth
                + endIndexOffset
    }

    public func index(after i: Int) -> Int {
        return i + 1
    }

    public func index(before i: Int) -> Int {
        return i - 1
    }

    public func index(_ i: Int, offsetBy distance: Int) -> Int {
        return i + distance
    }

    /// The index into the base collection, and offset into the word at that
    /// index for the value `position` bits into the `Bits`.
    public func wordIndexAndOffset(
        for position: Int
    ) -> (wordIndex: Base.Index, offsetIntoWord: Int) {
        let distanceToIndex = position / Self.underlyingBitWidth
        let wordIndex = base.index(base.startIndex, offsetBy: distanceToIndex)
        return (wordIndex, position % Self.underlyingBitWidth)
    }

    /*
    /// The number of bits away the value at `index` is from the value at
    /// `startIndex`.
    public func depthFor(index: Index) -> Int {
        return base.distance(from: base.startIndex, to: index.wordIndex) *
            Self.underlyingBitWidth + index.offsetIntoWord
    }
    */

    /// index(atOffset:) with added bounds checking for setters
    private func assertInBounds(_ index: Int) -> Int {
        assert(index < endIndex)
        return index
    }

    // valueAt(index:) and valueAt(depth:) are provided instead of just the
    // subscripts that use it to avoid re-implementing this logic in getters for
    // both the get only and the get + set implementation found in
    // `MutableCollection` conformance.

    private func valueAt(index: Int) -> Bool {
        let (wordIndex, offsetIntoWord) = wordIndexAndOffset(for: index)
        return valuePacked(in: base[wordIndex], offset: offsetIntoWord)
    }

    /// The raw integer value in the `base` collection at `Base.Index`.
    public subscript(packedInteger i: Base.Index) -> Base.Element {
        return base[i]
    }

    /// The value `depth` bits away from the value at `startIndex`.
    public subscript(position: Int) -> Bool {
        get { valueAt(index: position) }
    }
}

extension Bits: MutableCollection where Base: MutableCollection {
    /// The raw integer value in the `base` collection at `Base.Index`.
    public subscript(packedInteger i: Base.Index) -> Base.Element {
        get { return base[i] }
        set(newValue) { base[i] = newValue }
    }

    public subscript(position: Int) -> Bool {
        get {
            valueAt(index: position)
        }
        set(newValue) {
            assert(position < endIndex)
            let (wordIndex, offsetIntoWord) = wordIndexAndOffset(for: position)
            let oldPackedValues = self[packedInteger: wordIndex]
            if newValue {
                self[packedInteger: wordIndex] =
                    nthBitSet(offsetIntoWord) | oldPackedValues
            } else {
                self[packedInteger: wordIndex] =
                    ~nthBitSet(offsetIntoWord) & oldPackedValues
            }
        }
    }
}

extension Bits: RangeReplaceableCollection
where Base: RangeReplaceableCollection {
    public init() {
        self = .init(.init(), endIndexOffset: 0)
    }

    // TODO: This implementation of replace subrange allocates more storage
    // than necessary, is lacking a fast path for a variety of cases and
    // is inefficient due to references held in the created iterators.
    // It is intended to be a reference implementation which passes all the
    // provided tests. A better implementation should replace it and the tests
    // given can help refine that improved implementation.
    public mutating func replaceSubrange<C>(
        _ target: Range<Int>,
        with newElements: C
    ) where C : Collection, C.Element == Bool {
        let lowerBound = wordIndexAndOffset(for: target.lowerBound)
        var leadingBits = self[target.lowerBound - lowerBound.offsetIntoWord ..<
            target.lowerBound]
            .makeIterator()
        var replacementBits = newElements.makeIterator()
        var trailingBits = self[target.upperBound...].makeIterator()

        func nextBit() -> Bool? {
            leadingBits.next() ??
                (replacementBits.next() ?? trailingBits.next())
        }
        // Naive implementation: replace everything from the start of the
        // integer backing the start position through to the end of the end
        // of the range.
        var replacement = [Base.Element]()
        var buffer = [Bool]()
        buffer.reserveCapacity(Self.underlyingBitWidth)
        while let bit = nextBit() {
            buffer.append(bit)
            if buffer.count == Self.underlyingBitWidth {
                replacement.append(Base.Element(fromBits: buffer))
                buffer.removeAll(keepingCapacity: true)
            }
        }
        endIndexOffset = Self.underlyingBitWidth
        // fill empty space at the end of the buffer with zeroes
        if !buffer.isEmpty {
            // If the buffer is partially filled, the new endIndexOffset should
            // be moved to however filled it is
            endIndexOffset = buffer.count
            while buffer.count < Self.underlyingBitWidth {
                buffer.append(false)
            }
            replacement.append(Base.Element(fromBits: buffer))
        }

        base.replaceSubrange(lowerBound.wordIndex...,
            with: replacement)

        if base.isEmpty {
            endIndexOffset = 0
        }
    }
}