private typealias Word = UInt

/// Returns the offset at which the `i`th bit can be found in an array of
/// `Word`s.
private func wordOffset(ofBit i: Int) -> Int {
  precondition(i >= 0)
  return i / Word.bitWidth
}

/// Returns a mask that isolates the `i`th bit within its `Word` in an array of
/// `Word`s.
private func wordMask(ofBit i: Int) -> Word {
  precondition(i >= 0)
  return (1 as Word) << (i % Word.bitWidth)
}

/// An adapter that presents a base instance of `S` as a sequence of bits packed
/// into `Word`, where `true` and `false` in the base are represented as `1` and
/// `0` bits in an element of `self`, respectively.
private struct PackedIntoWords<S: Sequence>: Sequence where S.Element == Bool {
  /// The iteration state of a traversal of a `PackedIntoWords`.
  struct Iterator: IteratorProtocol {
    var base: S.Iterator

    mutating func next() -> Word? {
      guard let b = base.next() else { return nil }
      var r: Word = b ? 1 : 0
      for i in 1..<Word.bitWidth {
        guard let b = base.next() else { return r }
        if b { r |= wordMask(ofBit: i) }
      }
      return r
    }
  }
  /// Returns a new iterator over `self`.
  func makeIterator() -> Iterator { Iterator(base: base.makeIterator()) }

  /// Returns a number no greater than the number of elements in `self`.
  var underestimatedCount: Int {
    (base.underestimatedCount + Word.bitWidth - 1) / Word.bitWidth
  }

  /// The underlying sequence of `Bool`.
  let base: S

  init(_ base: S) { self.base = base }
}

/// A collection of `Bool` stored efficiently as bits.
public struct BitVector: RandomAccessCollection, MutableCollection {
  /// A position in `self`.
  public typealias Index = Int

  /// Storage for words containing the underlying bits.
  private var storage: [Word]

  /// The number of elements in `self`.
  public private(set) var count: Int

  /// Accesses the `i`th element.
  public subscript(i: Index) -> Bool {
    /// Accessor for simply reading an element
    get {
      precondition(i < count)
      return storage[wordOffset(ofBit: i)] & wordMask(ofBit: i) != 0
    }

    /// Accessor for simply setting an element
    set {
      precondition(i < count)
      storage.withUnsafeMutableBufferPointer { b in
        let j = wordOffset(ofBit: i)
        let m = wordMask(ofBit: i)
        if newValue { b[j] |= m } else { b[j] &= ~m }
      }
    }

    /// Accessor for (potentially) updating an element.
    @inline(__always)
    _modify {
      precondition(i < count)
      let j = wordOffset(ofBit: i)
      let m = wordMask(ofBit: i)
      // Extract a pointer to the right word.  Ensures buffer uniqueness.
      let p = storage.withUnsafeMutableBufferPointer { b in
        b.baseAddress.unsafelyUnwrapped + j
      }

      // Construct the projected value.
      var projectedValue = p.pointee & m != 0

      // Present it for mutation
      yield &projectedValue

      // Put it back
      if projectedValue { p.pointee |= m } else { p.pointee &= ~m }

      // ensure storage isn't released before we write into it.
      withExtendedLifetime(storage) {}
    }
  }

  /// The position of the first element in `self`, or `endIndex` if there is no
  /// such element.
  public var startIndex: Int { 0 }

  /// The position one past the last element in `self`.
  public var endIndex: Int { count }

  /// Creates an empty instance
  public init() {
    storage = []
    count = 0
  }

  /// Ensures that there is storage for at least `n` elements.
  public mutating func reserveCapacity(_ n: Int) {
    storage.reserveCapacity(wordOffset(ofBit: n))
  }

  /// The number of elements that `self` can store without incurring allocation.
  public var capacity: Int {
    return storage.capacity * Word.bitWidth
  }

  /// Creates a logical copy of `content`.
  public init<Content: Collection>(_ content: Content)
    where Content.Element == Bool
  {
    storage = .init(PackedIntoWords(content))
    count = content.count
  }

  /// Appends `newElement` to `self`.
  public mutating func append(_ newElement: Bool) {
    let b = wordOffset(ofBit: count)
    if b < storage.count {
      count += 1
      self[count - 1] = newElement
      return
    }
    storage.append(newElement ? 1 : 0)
    count += 1
  }
}

extension BitVector: Equatable {
  /// Returns `true` iff `l` contains the same elements as `r`.
  public static func == (l: Self, r: Self) -> Bool {
    if l.count != r.count { return false }
    let extraBits = l.count % Word.bitWidth
    if extraBits != 0 {
      if !l.storage.dropLast().elementsEqual(r.storage.dropLast()) {
        return false
      }
      let l1 = l.storage.last.unsafelyUnwrapped
      let r1 = r.storage.last.unsafelyUnwrapped
      let differingBits = l1 ^ r1
      let mask = ((1 as Word) << extraBits) &- 1
      return (differingBits & mask) == 0
    }
    return l.storage.elementsEqual(r.storage)
  }
}
