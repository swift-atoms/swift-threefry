extension Threefry {

    public struct Generator: Hashable, Sendable {
        public let key: Key
        public let stream: UInt64
        public private(set) var index: UInt64
        public private(set) var offset: UInt8

        public init(key: Key, stream: UInt64 = 0, index: UInt64 = 0) {
            self.key = key
            self.stream = stream
            self.index = index
            self.offset = 0
        }
    }
}

extension Threefry.Generator {

    public func block(at index: UInt64) -> Threefry.Block {
        Threefry.block(key: key, counter: Threefry.Block(index, stream))
    }

    public mutating func byte() -> UInt8 {
        var bytes = block(at: index).bytes
        return take(from: &bytes)
    }

    /// The byte at the current position of `bytes`, the current block's bytes; moves on,
    /// and replaces `bytes` with the next block's when it crosses into it.
    private mutating func take(from bytes: inout InlineArray<16, UInt8>) -> UInt8 {
        let value = bytes[Int(offset)]
        offset += 1
        if offset == 16 {
            offset = 0
            index &+= 1
            bytes = block(at: index).bytes
        }
        return value
    }
}

extension Threefry.Generator: Random.Generator {

    public mutating func fill(_ buffer: UnsafeMutableRawBufferPointer) {
        var bytes = block(at: index).bytes
        buffer.indices.forEach { position in
            unsafe buffer[position] = take(from: &bytes)
        }
    }
}

extension Threefry.Generator: Swift::RandomNumberGenerator {

    public mutating func next() -> UInt64 {
        var bytes = block(at: index).bytes
        var result: UInt64 = 0
        (0..<8 as Range<UInt64>).forEach { position in
            result |= UInt64(take(from: &bytes)) << (position * 8)
        }
        return result
    }
}
