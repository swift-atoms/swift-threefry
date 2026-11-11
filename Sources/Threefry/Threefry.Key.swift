extension Threefry {

    public struct Key: Hashable, Sendable {
        public let first: UInt64
        public let second: UInt64

        public init(_ first: UInt64, _ second: UInt64) {
            self.first = first
            self.second = second
        }
    }
}
