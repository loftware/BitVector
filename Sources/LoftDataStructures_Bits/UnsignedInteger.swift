// TODO: These are all reasonable packages on their own. They should be broken
// out.

extension MemoryLayout {
    static var bitSize: Int {
        return Self.size * 8
    }
}

extension BinaryInteger {
    /// Create an integer from its representation in bits.
    ///
    /// The first element of the array is the most significant bit of the
    /// resulting integer, and the last element is the least significant bit.
    /// The number of elements in `bits` must be the same as the size in bits
    /// of the integer type.
    // TODO: Get rid of this, we shouldn't actually need it. Just used for the
    // current reference implementation of replaceSubrange.
    internal init(fromBits bits: [Bool]) {
        assert(bits.count == MemoryLayout<Self>.bitSize)
        var result = 0 as Self
        for bit in bits.dropLast() {
            if bit {
                result += 1
            }
            result <<= 1
        }
        if bits.last! {
            result += 1
        }
        self = result
    }
}