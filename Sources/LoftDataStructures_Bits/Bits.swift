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
    Base: BidirectionalCollection
> where Base.Element: UnsignedInteger {
    public typealias SubSequence = Slice<Self>

    /// One more than the offset into the last `Element` of the last bit in the
    /// `Bits`.
    internal var endIndexOffset: Int // @testable
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

    /// The number with only the bit at `offset` set.
    internal func twoToThe(_ n: Int) -> Base.Element {
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

extension Bits: BidirectionalCollection {
    /// A position in a `Bits`.
    public struct Index: Comparable {
        public let elementIndex: Base.Index
        public let offsetIntoElement: Int

        init (_ index: Base.Index, offset: Int) {
            assert(offset >= 0)
            self.elementIndex = index
            self.offsetIntoElement = offset % Bits<Base>.underlyingBitWidth
        }

        public static func < (lhs: Index, rhs: Index) -> Bool {
            return lhs.elementIndex < rhs.elementIndex ||
                (lhs.elementIndex == rhs.elementIndex &&
                    lhs.offsetIntoElement < rhs.offsetIntoElement)
        }
    }

    // @testable
    static internal func newOffsetsFor(
        growth: Int,
        oldOffset offset: Int
    ) -> (packedIntChange: Int, offsetChange: Int) {
        let packedChange = (offset + growth - 1).flooringDiv(
            Self.underlyingBitWidth)
        let offsetChange = (offset + growth).modulo(
            Self.underlyingBitWidth) - offset
        return (packedChange, offsetChange)
    }

    public var startIndex: Index {
        return Index(base.startIndex, offset: 0)
    }

    public var endIndex: Index {
        if endIndexOffset == Self.underlyingBitWidth || endIndexOffset == 0 {
            return Index(base.endIndex, offset: 0)
        }
        return Index(base.index(before: base.endIndex), offset: endIndexOffset)
    }

    public func index(after i: Index) -> Index {
        if i.offsetIntoElement == Self.underlyingBitWidth - 1 {
            return Index(base.index(after: i.elementIndex), offset: 0)
        }
        return Index(i.elementIndex, offset: i.offsetIntoElement + 1)
    }

    public func index(before i: Index) -> Index {
        if i.offsetIntoElement == 0 {
            return Index(base.index(before: i.elementIndex),
                offset: Self.underlyingBitWidth - 1)
        }
        return Index(i.elementIndex, offset: i.offsetIntoElement - 1)
    }

    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        let (indexChange, offsetChange) = Self.newOffsetsFor(
            growth: distance, oldOffset: i.offsetIntoElement)
        return Index(base.index(i.elementIndex, offsetBy: indexChange),
            offset: i.offsetIntoElement + offsetChange)
    }

    /// The index for the value `depth` bits away from the value at
    /// `startIndex`.
    public func indexFor(depth: Int) -> Index {
        let distanceToIndex = depth / Self.underlyingBitWidth
        let index = base.index(base.startIndex, offsetBy: distanceToIndex)
        return Index(index, offset: depth % Self.underlyingBitWidth)
    }

    /// The number of bits away the value at `index` is from the value at
    /// `startIndex`.
    public func depthFor(index: Index) -> Int {
        return base.distance(from: base.startIndex, to: index.elementIndex) *
            Self.underlyingBitWidth + index.offsetIntoElement
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
        return valuePacked(in: base[index.elementIndex],
            offset: index.offsetIntoElement)
    }

    /// The value `depth` bits away from the value at `startIndex`.
    private func valueAt(depth: Int) -> Bool {
        return valueAt(index: indexFor(depth: depth))
    }

    /// The raw integer value in the `base` collection at `Base.Index`.
    public subscript(packedInteger i: Base.Index) -> Base.Element {
        return base[i]
    }

    public subscript(position: Bits.Index) -> Bool {
        valueAt(index: position)
    }
}

// Mark: Int indexed versions of `Collection` apis.
extension Bits {
    /// The value `depth` bits away from the value at `startIndex`.
    public subscript(position: Int) -> Bool {
        valueAt(depth: position)
    }

    /// Returns a subsequence from the start of the collection through the
    /// specified position.
    public func prefix(through position: Int) -> Self.SubSequence {
        return prefix(through: indexFor(depth: position))
    }

    /// Returns a subsequence from the start of the collection up to, but not
    /// including, the specified position.
    public func prefix(upTo end: Int) -> Self.SubSequence {
        return prefix(upTo: indexFor(depth: end))
    }

    /// Returns a subsequence from the specified position to the end of the
    /// collection.
    public func suffix(from start: Int) -> Self.SubSequence {
        return suffix(from: indexFor(depth: start))
    }

    /// Accesses a contiguous subrange of the collection’s elements.
    public subscript(bounds: Range<Int>) -> Self.SubSequence {
        return self[
            indexFor(depth: bounds.lowerBound) ..<
            indexFor(depth: bounds.upperBound)]
    }
}

extension Bits: RandomAccessCollection where Base: RandomAccessCollection {}

extension Bits: MutableCollection where Base: MutableCollection {
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
            let oldPackedValues = self[packedInteger: position.elementIndex]
            if newValue {
                self[packedInteger: position.elementIndex] =
                    twoToThe(position.offsetIntoElement) | oldPackedValues
            } else {
                self[packedInteger: position.elementIndex] =
                    ~twoToThe(position.offsetIntoElement) & oldPackedValues
            }
        }
    }
}

// Mark: Int indexed versions of `MutableCollection` apis.
extension Bits where Base: MutableCollection {
    /// The value `depth` bits away from the value at `startIndex`.
    public subscript(position: Int) -> Bool {
        get { valueAt(depth: position) }
        set(newValue) { self[checkedIndexFor(depth: position)] = newValue }
    }

    /// Exchanges the values at the specified positions in the collection.
    public mutating func swapAt(_ i: Int, _ j: Int) {
        swapAt(indexFor(depth: i), indexFor(depth: j))
    }

    /// Accesses a contiguous subrange of the collection’s elements.
    public subscript(position: Range<Int>) -> Self.SubSequence {
        get {
            self[indexFor(depth: position.lowerBound) ..<
                indexFor(depth: position.upperBound)]
        }
        set(newValue) {
            self[indexFor(depth: position.lowerBound) ..<
                indexFor(depth: position.upperBound)] = newValue
        }
    }
}

extension Bits: RangeReplaceableCollection
where Base: RangeReplaceableCollection {
    public init() {
        self = .init(.init(), endIndexOffset: 0)
    }

   // TODO: Provide an in place implementation of this when we have
   // MutableCollection conformance.
   public mutating func replaceSubrange<C>(
        _ subrange: Range<Index>,
        with newElements: C
    ) where C : Collection, C.Element == Bool {
        var leadingBits = self[
            Index(subrange.lowerBound.elementIndex, offset: 0) ..<
                subrange.lowerBound]
            .makeIterator()
        var replacementBits = newElements.makeIterator()
        var trailingBits = self[subrange.upperBound...].makeIterator()

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
                // TODO: Check if this is still O(n) when keepingCaparity is
                // true.
                buffer.removeAll(keepingCapacity: true)
            }
        }
        endIndexOffset = Self.underlyingBitWidth
        // fill empty space at the end of the replacement with zeroes
        if !buffer.isEmpty {
            // If the buffer is partially filled, the new endIndexOffset should
            // be moved to however filled it is
            endIndexOffset = buffer.count
            while buffer.count < Self.underlyingBitWidth {
                buffer.append(false)
            }
            replacement.append(Base.Element(fromBits: buffer))
        }

        base.replaceSubrange(subrange.lowerBound.elementIndex...,
            with: replacement)

        if base.isEmpty {
            endIndexOffset = 0
        }
    }
}

 // Mark: Int indexed versions of stdlib `RangeReplaceableCollection` apis.
extension Bits where Base: RangeReplaceableCollection {
    /// Replaces the specified subrange of elements with the given collection.
    public mutating func replaceSubrange<C>(
        _ subrange: Range<Int>,
        with newElements: C
    ) where C : Collection, C.Element == Bool {
        replaceSubrange(indexFor(depth: subrange.lowerBound) ..<
            indexFor(depth: subrange.upperBound), with: newElements)
    }

    /// Inserts a new element into the collection at the specified position.
    public mutating func insert(_ newElement: Self.Element, at i: Int) {
        insert(newElement, at: indexFor(depth: i))
    }

    /// Removes and returns the element at the specified position.
    @discardableResult
    public mutating func remove(at i: Int) -> Self.Element {
        remove(at: indexFor(depth: i))
    }

    /// Removes the specified subrange of elements from the collection.
    public mutating func removeSubrange(_ bounds: Range<Int>) {
        removeSubrange(indexFor(depth: bounds.lowerBound) ..<
            indexFor(depth: bounds.upperBound))
    }
}