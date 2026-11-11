extension Threefry {

    public struct Block: Hashable, Sendable {
        public let first: UInt64
        public let second: UInt64

        public init(_ first: UInt64, _ second: UInt64) {
            self.first = first
            self.second = second
        }
    }
}

extension Threefry.Block {

    public var bytes: InlineArray<16, UInt8> {
        InlineArray { offset in
            let word = offset < 8 ? first : second
            return UInt8(truncatingIfNeeded: word >> (UInt64(offset % 8) * 8))
        }
    }
}
