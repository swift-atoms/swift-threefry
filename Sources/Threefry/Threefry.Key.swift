extension Threefry {

    /// The 128-bit key: the seed.
    public struct Key: Hashable, Sendable {
        /// The first key word.
        public let first: UInt64

        /// The second key word.
        public let second: UInt64

        /// The key of the two words.
        public init(_ first: UInt64, _ second: UInt64) {
            self.first = first
            self.second = second
        }
    }
}
