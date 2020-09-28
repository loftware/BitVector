/// A `Collection` of `Bool` that packs its values into `BinaryInteger`s to
/// minimize storage overhead.
///
/// `Bits` acomplishes this by wrapping a `base` `Collection` of some
/// integer type and allowing access to the underlying bits given a offset in
/// bits into the collection.
public struct Bits<
    Base: RandomAccessCollection
> where Base.Element: BinaryInteger {
    /// One more than the offset into the last `Element` of the last bit in the
    /// `Bits`.
    internal var endIndexOffset: Int // @testable
    /// The `BidirectionalCollection` containing the `BinaryIntegers` which this
    /// this `Bits` projects the bits of.
    private var base: Base

    /// The number of bits in the underlying integer type.
    static internal var wordSize: Int {
        MemoryLayout<Base.Element>.bitSize
    }

    /// Creates an instance whose elements are `true` iff the coresponding bit
    /// in an element of `base` is set.
    ///
    /// Each bit in an element of `base` is represented in the new instance.
    public init(wrapping base: Base) {
        self.base = base
        self.endIndexOffset = Self.wordSize
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
        assert(n >= 0 && n < Self.wordSize)
        return Base.Element.init(1) << ((Self.wordSize - 1) - n)
    }

    /// If the bit `offset` bits into a `Base.Element` is set.
    ///
    /// The bit at an `offset` of zero is the most significant bit.
    private func valuePacked(
        in packed: Base.Element,
        offset: Int
    ) -> Bool {
        return ((packed >> ((Self.wordSize - 1) - offset)) & 1) == 1
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
        if endIndexOffset == Self.wordSize || endIndexOffset == 0 {
            return base.distance(from: base.startIndex, to: base.endIndex)
                * Self.wordSize
        }
        return base.distance(from: base.startIndex,
            to: base.index(before: base.endIndex)) * Self.wordSize
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
        let distanceToIndex = position / Self.wordSize
        let wordIndex = base.index(base.startIndex, offsetBy: distanceToIndex)
        return (wordIndex, position % Self.wordSize)
    }

    // valueAt(index:) is provided instead of just the subscripts that use it to
    // avoid re-implementing this logic in getters for both the get only and the
    // get + set implementation found in `MutableCollection` conformance.
    /// If the bit at the given index into the `Bits` is set.
    private func valueAt(index: Int) -> Bool {
        let (wordIndex, offsetIntoWord) = wordIndexAndOffset(for: index)
        return valuePacked(in: base[wordIndex], offset: offsetIntoWord)
    }

    /// The raw integer value in the `base` collection at `Base.Index`.
    public subscript(packedInteger i: Base.Index) -> Base.Element {
        return base[i]
    }

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
        buffer.reserveCapacity(Self.wordSize)
        while let bit = nextBit() {
            buffer.append(bit)
            if buffer.count == Self.wordSize {
                replacement.append(Base.Element(fromBits: buffer))
                buffer.removeAll(keepingCapacity: true)
            }
        }
        endIndexOffset = Self.wordSize
        // fill empty space at the end of the buffer with zeroes
        if !buffer.isEmpty {
            // If the buffer is partially filled, the new endIndexOffset should
            // be moved to however filled it is
            endIndexOffset = buffer.count
            while buffer.count < Self.wordSize {
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