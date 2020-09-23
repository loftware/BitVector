import XCTest
@testable import BitMap

final class BitCollectionTests: XCTestCase {
    static let base: [UInt8] = [0b1100_1001, 0b1111_0000]
    let bc = BitMap(BitCollectionTests.base)

    func testBitmaskForOffset() {
        XCTAssertEqual(type(of: bc).packingStride, 8)
        XCTAssertEqual(bc.bitmaskFor(offset: 0), 0b1000_0000)
        XCTAssertEqual(bc.bitmaskFor(offset: 1), 0b0100_0000)
        XCTAssertEqual(bc.bitmaskFor(offset: 2), 0b0010_0000)
        XCTAssertEqual(bc.bitmaskFor(offset: 3), 0b0001_0000)
        XCTAssertEqual(bc.bitmaskFor(offset: 4), 0b0000_1000)
        XCTAssertEqual(bc.bitmaskFor(offset: 5), 0b0000_0100)
        XCTAssertEqual(bc.bitmaskFor(offset: 6), 0b0000_0010)
        XCTAssertEqual(bc.bitmaskFor(offset: 7), 0b0000_0001)
        // try it with other int sizes
        let bc2 = BitMap([UInt32]())
        XCTAssertEqual(bc2.bitmaskFor(offset:3),
            0b0001_0000_0000_0000_0000_0000_0000_0000)
    }

    func testPackedValueAtOffset() {
        let base: [UInt8] = [0b1100_1001, 0b1111_0000]
        let bc = BitMap(base)
        XCTAssertTrue(bc[BitMap.Index(0, offset: 0)])
        XCTAssertTrue(bc[BitMap.Index(0, offset: 1)])
        XCTAssertFalse(bc[BitMap.Index(0, offset: 2)])
        XCTAssertFalse(bc[BitMap.Index(0, offset: 3)])
        XCTAssertTrue(bc[BitMap.Index(0, offset: 4)])
        XCTAssertFalse(bc[BitMap.Index(0, offset: 5)])
        XCTAssertFalse(bc[BitMap.Index(0, offset: 6)])
        XCTAssertTrue(bc[BitMap.Index(0, offset: 7)])
        // second element
        XCTAssertTrue(bc[BitMap.Index(1, offset: 0)])
        XCTAssertTrue(bc[BitMap.Index(1, offset: 1)])
        XCTAssertTrue(bc[BitMap.Index(1, offset: 2)])
        XCTAssertTrue(bc[BitMap.Index(1, offset: 3)])
        XCTAssertFalse(bc[BitMap.Index(1, offset: 4)])
        XCTAssertFalse(bc[BitMap.Index(1, offset: 5)])
        XCTAssertFalse(bc[BitMap.Index(1, offset: 6)])
        XCTAssertFalse(bc[BitMap.Index(1, offset: 7)])
    }

    func testIntIndexing() {
        // check all the ones are true
        XCTAssertTrue(bc[0])
        XCTAssertTrue(bc[1])
        XCTAssertTrue(bc[4])
        XCTAssertTrue(bc[7])
        XCTAssertTrue(bc[8])
        XCTAssertTrue(bc[9])
        XCTAssertTrue(bc[10])
        XCTAssertTrue(bc[11])

        // check all the zeroes are false
        XCTAssertFalse(bc[2])
        XCTAssertFalse(bc[3])
        XCTAssertFalse(bc[5])
        XCTAssertFalse(bc[6])
        XCTAssertFalse(bc[12])
        XCTAssertFalse(bc[13])
        XCTAssertFalse(bc[14])
        XCTAssertFalse(bc[15])
    }

    func testPackedIntegerAccess() {
        XCTAssertEqual(bc[packedInteger: 0], 0b1100_1001)
        XCTAssertEqual(bc[packedInteger: 1], 0b1111_0000)
    }

    func testMutationStandardIndexing() {
        var mut = bc
        XCTAssertFalse(mut[BitMap.Index(0, offset: 3)])
        mut[BitMap.Index(0, offset: 3)] = true
        XCTAssertTrue(mut[BitMap.Index(0, offset: 3)])

        XCTAssertEqual(mut[packedInteger: 0], 0b1101_1001)

        XCTAssertTrue(mut[BitMap.Index(1, offset: 0)])
        mut[BitMap.Index(1, offset: 0)] = false
        XCTAssertFalse(mut[BitMap.Index(1, offset: 0)])
        XCTAssertEqual(mut[packedInteger: 1], 0b0111_0000)
    }

    func testNewOffsetsFor() {
        var (a, b): (Int, Int)
        (a, b) = type(of: bc).newOffsetsFor(growth: 0, oldOffset: 4)
        XCTAssertEqual(a, 0)
        XCTAssertEqual(b, 0)
        (a, b) = type(of: bc).newOffsetsFor(growth: 4, oldOffset: 4)
        XCTAssertEqual(a, 0)
        XCTAssertEqual(b, -4)
        (a, b) = type(of: bc).newOffsetsFor(growth: 5, oldOffset: 4)
        XCTAssertEqual(a, 1)
        XCTAssertEqual(b, -3)
        (a, b) = type(of: bc).newOffsetsFor(growth: 6, oldOffset: 4)
        XCTAssertEqual(a, 1)
        XCTAssertEqual(b, -2)
        (a, b) = type(of: bc).newOffsetsFor(growth: 12, oldOffset: 4)
        XCTAssertEqual(a, 1)
        XCTAssertEqual(b, -4)
        (a, b) = type(of: bc).newOffsetsFor(growth: 13, oldOffset: 4)
        XCTAssertEqual(a, 2)
        XCTAssertEqual(b, -3)
        (a, b) = type(of: bc).newOffsetsFor(growth: -5, oldOffset: 4)
        XCTAssertEqual(a, -1)
        XCTAssertEqual(b, 3)
    }

    static var allTests = [
        ("testBitmaskForOffset", testBitmaskForOffset),
        ("testPackedValueAtOffset", testPackedValueAtOffset),
        ("testIntIndexing", testIntIndexing),
        ("testPackedIntegerAccess", testPackedIntegerAccess),
        ("testMutationStandardIndexing", testMutationStandardIndexing),
        ("testNewOffsetsFor", testNewOffsetsFor),
    ]
}