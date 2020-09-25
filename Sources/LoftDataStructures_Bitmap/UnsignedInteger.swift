// TODO: These are all reasonable packages on their own. They should be broken
// out.

extension MemoryLayout {
    static var bitSize: Int {
        return Self.size * 8
    }
}

extension UnsignedInteger {
    /// Create an integer from its representation in bits.
    ///
    /// The first element of the array is the most significant bit of the
    /// resulting integer, and the last element is the least significant bit.
    /// The number of elements in `bits` must be the same as the size in bits
    /// of the integer type.
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

    internal var bits: [Bool] {
        var result: [Bool] = []
        result.reserveCapacity(MemoryLayout<Self>.bitSize)
        for i in 0..<MemoryLayout<Self>.bitSize {
            result.append((self >> i) & 1 == 1)
        }
        return result
    }

    /// Creates an integer with the first `offset` bits of `a`, filling the
    /// remaining space with the trailing bits of `b`.
    internal init(splicing a: Self, with b: Self, offset: Int) {
        assert(offset >= 0)
        assert(offset <= MemoryLayout<Self>.bitSize)
        // Zero everything we're not using from a.
        let shiftToClear = MemoryLayout<Self>.bitSize - offset
        let usedBitsFromA = (a >> shiftToClear) << shiftToClear
        // Zero everything we're not using from b
        let usedBitsFromB = (b << offset) >> offset
        self = usedBitsFromA | usedBitsFromB
    }
}