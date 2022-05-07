private func bucket(for i: Int) -> Int { i / UInt.bitWidth }
private func mask(for i: Int) -> UInt {
  (1 as UInt) << (i % UInt.bitWidth)
}

private struct PackedIntoUInts<S: Sequence>: Sequence where S.Element == Bool {
  struct Iterator: IteratorProtocol {
    var base: S.Iterator
    mutating func next() -> UInt? {
      guard let b = base.next() else { return nil }
      var r: UInt = b ? 1 : 0
      for i in 1..<UInt.bitWidth {
        guard let b = base.next() else { return r }
        if b { r |= mask(for: i) }
      }
      return r
    }
  }

  var underestimatedCount: Int {
    (base.underestimatedCount + UInt.bitWidth - 1) / UInt.bitWidth
  }

  func makeIterator() -> Iterator { Iterator(base: base.makeIterator()) }
  let base: S

  init(_ base: S) { self.base = base }
}

struct BitVector: RandomAccessCollection, MutableCollection {
  public typealias Index = Int

  private var buckets: [UInt]
  public private(set) var count: Int

  public subscript(i: Index) -> Bool {
    get {
      precondition(i < count)
      return buckets[bucket(for: i)] & mask(for: i) != 0
    }
    set {
      precondition(i < count)
      if self[i] == newValue { return }
      buckets.withUnsafeMutableBufferPointer { b in
        let j = bucket(for: i)
        let m = mask(for: i)
        if newValue { b[j] |= m } else { b[j] &= ~m }
      }
    }
    _modify {
      precondition(i < count)
      let j = bucket(for: i)
      let m = mask(for: i)
      // ensures uniqueness
      let p = buckets.withUnsafeMutableBufferPointer { b in
        b.baseAddress.unsafelyUnwrapped + j
      }
      var value = p.pointee & m != 0
      yield &value
      if value { p.pointee |= m } else { p.pointee &= ~m }
      withExtendedLifetime(self) {}
    }
  }

  public var startIndex: Int { 0 }
  public var endIndex: Int { count }

  public init() {
    buckets = []
    count = 0
  }

  public mutating func reserveCapacity(_ i: Int) {
    buckets.reserveCapacity(bucket(for: i))
  }

  public init<Content: Collection>(_ content: Content)
    where Content.Element == Bool
  {
    buckets = .init(PackedIntoUInts(content))
    count = content.count
  }


  public mutating func append(_ newElement: Bool) {
    let b = bucket(for: count)
    if b < buckets.count {
      count += 1
      self[count - 1] = newElement
      return
    }
    buckets.append(newElement ? 1 : 0)
  }
}
