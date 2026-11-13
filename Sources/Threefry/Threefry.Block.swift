extension Threefry {

    /// 128 bits as two 64-bit words: a counter going in, or the random bits coming out.
    public struct Block: Hashable, Sendable {
        /// The first word: the index, in a counter.
        public let first: UInt64

        /// The second word: the stream, in a counter.
        public let second: UInt64

        /// The block of the two words.
        public init(_ first: UInt64, _ second: UInt64) {
            self.first = first
            self.second = second
        }
    }
}

extension Threefry.Block {

    /// The sixteen bytes: `first` then `second`, each little-endian on every machine.
    public var bytes: InlineArray<16, UInt8> {
        InlineArray { offset in
            let word = offset < 8 ? first : second
            return UInt8(truncatingIfNeeded: word >> (UInt64(offset % 8) * 8))
        }
    }
}
