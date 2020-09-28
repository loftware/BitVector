import XCTest
@testable import LoftDataStructures_Bits

final class BitCollectionTests: XCTestCase {
    static let base: [UInt8] = [0b1100_1001, 0b1111_0000]
    let bc = Bits(wrapping: BitCollectionTests.base)

    func testBitmaskForOffset() {
        XCTAssertEqual(type(of: bc).underlyingBitWidth, 8)
        XCTAssertEqual(bc.nthBitSet(0), 0b1000_0000)
        XCTAssertEqual(bc.nthBitSet(1), 0b0100_0000)
        XCTAssertEqual(bc.nthBitSet(2), 0b0010_0000)
        XCTAssertEqual(bc.nthBitSet(3), 0b0001_0000)
        XCTAssertEqual(bc.nthBitSet(4), 0b0000_1000)
        XCTAssertEqual(bc.nthBitSet(5), 0b0000_0100)
        XCTAssertEqual(bc.nthBitSet(6), 0b0000_0010)
        XCTAssertEqual(bc.nthBitSet(7), 0b0000_0001)
        // try it with other int sizes
        let bc2 = Bits(wrapping: [UInt32]())
        XCTAssertEqual(bc2.nthBitSet(3),
            0b0001_0000_0000_0000_0000_0000_0000_0000)
    }

    func testPackedValueAtOffset() {
        let base: [UInt8] = [0b1100_1001, 0b1111_0000]
        let bc = Bits(wrapping: base)
        XCTAssertTrue(bc[0])
        XCTAssertTrue(bc[1])
        XCTAssertFalse(bc[2])
        XCTAssertFalse(bc[3])
        XCTAssertTrue(bc[4])
        XCTAssertFalse(bc[5])
        XCTAssertFalse(bc[6])
        XCTAssertTrue(bc[7])
        // second element
        XCTAssertTrue(bc[8 + 0])
        XCTAssertTrue(bc[8 + 1])
        XCTAssertTrue(bc[8 + 2])
        XCTAssertTrue(bc[8 + 3])
        XCTAssertFalse(bc[8 + 4])
        XCTAssertFalse(bc[8 + 5])
        XCTAssertFalse(bc[8 + 6])
        XCTAssertFalse(bc[8 + 7])
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
        XCTAssertFalse(mut[3])
        mut[3] = true
        XCTAssertTrue(mut[3])

        XCTAssertEqual(mut[packedInteger: 0], 0b1101_1001)

        XCTAssertTrue(mut[8])
        mut[8] = false
        XCTAssertFalse(mut[8])
        XCTAssertEqual(mut[packedInteger: 1], 0b0111_0000)
    }

    func testInitFromBitArray() {
        let a = UInt8(fromBits: [
            true, false, true, false, true, false, true, false
        ])
        XCTAssertEqual(a, 0b1010_1010)

        let b = UInt8(fromBits: [
            false, false, false, false, false, false, false, true
        ])
        XCTAssertEqual(b, 0b0000_0001)

        let c = UInt8(fromBits: [
            true, true, true, true, true, true, true, true
        ])
        XCTAssertEqual(c, 0b1111_1111)

        let d = UInt8(fromBits: [
            false, false, false, false, false, false, false, false
        ])
        XCTAssertEqual(d, 0b0000_0000)
    }

    func testReplaceSubrangeDeletion() {
        // delete from end
        var mut = bc
        mut.replaceSubrange(10..<16, with: [])
        XCTAssertEqual(Array(mut), [
            true, true, false, false, true, false, false, true,
            true, true
        ])
        XCTAssertEqual(mut.endIndexOffset, 2)

        // delete from start
        mut = bc
        mut.replaceSubrange(0..<4, with: [])
        XCTAssertEqual(Array(mut), [
            true, false, false, true,
            true, true, true, true, false, false, false, false
        ])
        XCTAssertEqual(mut.endIndexOffset, 4)
        // delete from center
        mut = bc
        mut.replaceSubrange(6..<10, with: [])
        XCTAssertEqual(Array(mut), [
            true, true, false, false, true, false,
            true, true, false, false, false, false
        ])
        XCTAssertEqual(mut.endIndexOffset, 4)

        // delete everything
        mut = bc
        mut.replaceSubrange(0..<bc.endIndex, with: [])
        XCTAssertEqual(Array(mut), [])
        XCTAssertEqual(mut.endIndexOffset, 0)
    }

    func testReplaceSubrangeAddition() {
        // insert at the start
        var mut = bc
        mut.replaceSubrange(0..<0, with: [false, false, true, true])
        XCTAssertEqual(Array(mut), [
            false, false, true, true,
            true, true, false, false, true, false, false, true,
            true, true, true, true, false, false, false, false
        ])
        XCTAssertEqual(mut.endIndexOffset, 4)

        mut = bc
        mut.replaceSubrange(0..<0,
            with: [false, false, true, true, true, true, true, true])
        XCTAssertEqual(Array(mut), [
            false, false, true, true, true, true, true, true,
            true, true, false, false, true, false, false, true,
            true, true, true, true, false, false, false, false
        ])
        XCTAssertEqual(mut.endIndexOffset, 8)

        // insert at the end
        mut = bc
        mut.replaceSubrange(16..<16, with: [true, true, true, true])
        XCTAssertEqual(Array(mut), [
            true, true, false, false, true, false, false, true,
            true, true, true, true, false, false, false, false,
            true, true, true, true,
        ])
        XCTAssertEqual(mut.endIndexOffset, 4)

        // insert in the middle
        mut = bc
        mut.replaceSubrange(6..<6, with: [true, true, true, true])
        XCTAssertEqual(Array(mut), [
            true, true, false, false, true, false,
            true, true, true, true,
            false, true, true, true, true, true, false, false, false, false,
        ])
        XCTAssertEqual(mut.endIndexOffset, 4)
    }


    func testSubrangeReplacement() {
        // static let base: [UInt8] = [0b1100_1001, 0b1111_0000]
        // replace the same amount of elements as removed
        var mut = bc
        mut.replaceSubrange(6..<10,
            with: [true, false, false, false])
        XCTAssertEqual(Array(mut), [
            true, true, false, false, true, false, true, false,
            false, false, true, true, false, false, false, false
        ])
        XCTAssertEqual(mut.endIndexOffset, 8)

        // replace more elements than removed
        mut = bc
        mut.replaceSubrange(6..<10,
            with: [true, false, false, false, true, false, true, false])
        XCTAssertEqual(Array(mut), [
            true, true, false, false, true, false, true, false,
            false, false, true, false, true, false,
            true, true, false, false, false, false
        ])

        // replace less elements than removed
        mut = bc
        mut.replaceSubrange(6..<10, with: [true])
        XCTAssertEqual(Array(mut), [
            true, true, false, false, true, false, true,
            true, true, false, false, false, false
        ])
    }

    func testArrayLiteralInit() {
        let bits: Bits<[UInt]> = [true, true, false, false]
        XCTAssertEqual(Array(bits), [true, true, false, false])
    }

    static var allTests = [
        ("testBitmaskForOffset", testBitmaskForOffset),
        ("testPackedValueAtOffset", testPackedValueAtOffset),
        ("testIntIndexing", testIntIndexing),
        ("testPackedIntegerAccess", testPackedIntegerAccess),
        ("testMutationStandardIndexing", testMutationStandardIndexing),
        ("testInitFromBitArray", testInitFromBitArray),
        ("testReplaceSubrangeDeletion", testReplaceSubrangeDeletion),
        ("testReplaceSubrangeAddition", testReplaceSubrangeAddition),
        ("testSubrangeReplacement", testSubrangeReplacement),
        ("testArrayLiteralInit", testArrayLiteralInit)
    ]
}