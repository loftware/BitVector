import XCTest
@testable import BitVector

final class BitVectorTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(BitVector().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
