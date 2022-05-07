import XCTest
import LoftDataStructures_BitVector
import LoftTest_StandardLibraryProtocolChecks
import Foundation

extension Equatable {
  public func checkNotEqual(_ b: Self) {
    XCTAssertNotEqual(self, b)
    XCTAssertNotEqual(b, self)
  }
}

final class BitVectorTests: XCTestCase {
  func testEmpty() {
    var x = BitVector()
    x.checkBidirectionalCollectionLaws(expecting: EmptyCollection())
    x.checkMutableCollectionLaws(expecting: EmptyCollection(), writing: EmptyCollection())
    x.append(false)
    XCTAssertEqual(x.count, 1)
    XCTAssertEqual(x[0], false)
    x = BitVector()
    x.append(true)
    XCTAssertEqual(x.count, 1)
    XCTAssertEqual(x[0], true)
    x.checkEquatableLaws()
  }

  func test1() {
    var x = BitVector(CollectionOfOne(false))
    x.checkBidirectionalCollectionLaws(expecting: CollectionOfOne(false))
    x.checkMutableCollectionLaws(expecting: CollectionOfOne(false), writing: CollectionOfOne(true))
    x.append(false)
    XCTAssertEqual(x.count, 2)
    XCTAssertEqual(x[0], false)
    x.checkEquatableLaws()
    x.checkNotEqual(BitVector())
    x.checkNotEqual(BitVector(CollectionOfOne(true)))

    x = BitVector()
    x.append(true)
    x.checkEquatableLaws()
    XCTAssertEqual(x.count, 1)
    XCTAssertEqual(x[0], true)
    x.checkNotEqual(BitVector(CollectionOfOne(false)))
  }

  func test2() {
    var x = BitVector([false, false])
    x.checkBidirectionalCollectionLaws(expecting: [false, false])
    x.checkMutableCollectionLaws(expecting: [false, false], writing: [true, true])
    x.checkEquatableLaws()
    x.checkNotEqual(BitVector())

    x = BitVector([false, true])
    x.checkBidirectionalCollectionLaws(expecting: [false, true])
    x.checkMutableCollectionLaws(expecting: [false, true], writing: [true, false])

    x = BitVector([true, false])
    x.checkBidirectionalCollectionLaws(expecting: [true, false])
    x.checkMutableCollectionLaws(expecting: [true, false], writing: [false, true])

    x = BitVector([true, true])
    x.checkBidirectionalCollectionLaws(expecting: [true, true])
    x.checkMutableCollectionLaws(expecting: [true, true], writing: [false, false])
  }

  func test2Word() {
    let source = (0 ..< 3 * UInt.bitWidth / 2).lazy.map { $0 % 3 != 0 }
    var x = BitVector(source)
    x.checkBidirectionalCollectionLaws(expecting: source)
    x.checkMutableCollectionLaws(expecting: source, writing: source.lazy.map { !$0 })
    x.checkEquatableLaws()
    var y = x
    y.append(true)
    x.checkNotEqual(y)
    x.append(false)
    x.checkNotEqual(y)
  }

  static let testMax = Int(3 * sqrt(Double(UInt.bitWidth)))
  static let nonRepeating = (0..<testMax)
    .flatMap { n in ((0..<(n+1)).lazy.map { $0 == 0 }) }

  func testMany() {
    assert(Self.nonRepeating.count > UInt.bitWidth)

    var x = BitVector(Self.nonRepeating)
    x.checkBidirectionalCollectionLaws(expecting: Self.nonRepeating)
    x.checkMutableCollectionLaws(
      expecting: Self.nonRepeating, writing: Self.nonRepeating.lazy.map { !$0 })
  }

  func testAppend() {
    var x = BitVector()
    x.append(false)
    XCTAssertEqual(x.count, 1)
    XCTAssertEqual(x[0], false)

    x.append(true)
    XCTAssertEqual(x.count, 2)
    XCTAssertEqual(x[0], false)
    XCTAssertEqual(x[1], true)

    x = BitVector()
    for i in Self.nonRepeating.indices {
      x.append(Self.nonRepeating[i])
      XCTAssert(x.elementsEqual(Self.nonRepeating[...i]))
    }
  }

  func testEquatable() {
    var x = BitVector(Self.nonRepeating)
    x.checkEquatableLaws()
    var y = x

    y.append(true)
    x.checkNotEqual(y)

    x.append(false)
    x.checkNotEqual(y)
  }
}

// Local Variables:
// fill-column: 100
// End:
