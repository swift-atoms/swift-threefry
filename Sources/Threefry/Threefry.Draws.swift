extension Threefry {

    /// The unit draws of one item in one stream under a key, read in any order: random access by three
    /// coordinates, two draws to a block.
    ///
    /// Draws `2k` and `2k + 1` are the two words of the block at counter `Block(item, stream << 32 + k)`, the
    /// first word for the even index and the second for the odd one, each as `Threefry.unit(of:)`. So a draw
    /// depends only on the key, the item, the stream and the index, is the same on every platform, and a pair
    /// of neighbouring draws costs one block. Streams below 2³² and indices below 2³³ address distinct
    /// counter words; beyond them the stream and the index share the counter's second word.
    public struct Draws: Hashable, Sendable {
        /// The key.
        public let key: Key

        /// The item the draws belong to: the first word of every counter.
        public let item: UInt64

        /// The stream, so that independent uses of one item draw independent numbers.
        public let stream: UInt64

        /// The draws of an item in a stream under a key.
        public init(key: Key, item: UInt64, stream: UInt64 = 0) {
            self.key = key
            self.item = item
            self.stream = stream
        }
    }
}

extension Threefry.Draws {

    /// The block that holds draws `2 × pair` and `2 × pair + 1`.
    public func block(at pair: UInt64) -> Threefry.Block {
        Threefry.block(key: key, counter: Threefry.Block(item, stream &<< 32 &+ pair))
    }

    /// The draw at an index, in [0, 1): a word of the block at half the index, the first for an even
    /// index and the second for an odd one.
    public func unit<Value: BinaryFloatingPoint>(at index: UInt64, as _: Value.Type = Value.self) -> Value {
        let block = block(at: index &>> 1)
        return Threefry.unit(of: index & 1 == 0 ? block.first : block.second, as: Value.self)
    }

    /// Draws `2 × pair` and `2 × pair + 1` at the cost of one block: `unit(at:)` of both.
    public func pair<Value: BinaryFloatingPoint>(
        at pair: UInt64,
        as _: Value.Type = Value.self
    ) -> (first: Value, second: Value) {
        block(at: pair).units(as: Value.self)
    }
}
