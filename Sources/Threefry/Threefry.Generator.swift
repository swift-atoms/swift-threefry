extension Threefry {

    /// The byte stream of one stream under one key, read in order from a position.
    ///
    /// The stream is the blocks at counter `(index, stream)` for `index`, `index + 1`, and so on,
    /// each read as its sixteen little-endian bytes. A generator holds the block it is reading,
    /// so a block is computed once for every sixteen bytes however they are read.
    ///
    /// The generator is also the keyed draw: `Generator(key: key, stream: stream, index: index)`
    /// is the generator for that triple, computed directly, never by stepping from the start.
    public struct Generator: Sendable {
        /// The key.
        public let key: Key

        /// The stream: the second word of every counter this generator reads.
        public let stream: UInt64

        /// The block being read: the first word of its counter.
        public private(set) var index: UInt64

        /// The byte of the block being read, from 0 to 15.
        public private(set) var offset: UInt8

        /// The block at `index`, kept so that it is computed once.
        private var current: Block

        /// The generator for `key` and `stream`, at the start of block `index`.
        ///
        /// It equals a generator at index 0 that has read `16 * index` bytes, and costs one block.
        public init(key: Key, stream: UInt64 = 0, index: UInt64 = 0) {
            self.key = key
            self.stream = stream
            self.index = index
            self.offset = 0
            self.current = Threefry.block(key: key, counter: Block(index, stream))
        }
    }
}

extension Threefry.Generator {

    /// The block at `index` of this generator's stream, without moving the generator.
    public func block(at index: UInt64) -> Threefry.Block {
        Threefry.block(key: key, counter: Threefry.Block(index, stream))
    }

    /// The next byte.
    public mutating func byte() -> UInt8 {
        let word = offset < 8 ? current.first : current.second
        let value = UInt8(truncatingIfNeeded: word &>> (UInt64(offset % 8) &* 8))
        offset += 1
        if offset == 16 { advance() }
        return value
    }

    /// Moves to the start of the next block.
    private mutating func advance() {
        index &+= 1
        offset = 0
        current = block(at: index)
    }
}

extension Threefry.Generator: Hashable {

    /// Generators are equal when key, stream and position are; the held block follows from them.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key && lhs.stream == rhs.stream && lhs.index == rhs.index && lhs.offset == rhs.offset
    }

    /// Hashes key, stream and position.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(stream)
        hasher.combine(index)
        hasher.combine(offset)
    }
}

extension Threefry.Generator: Random.Generator {

    /// Fills `buffer` with the next bytes, whole words at a time where the position allows.
    public mutating func fill(_ buffer: UnsafeMutableRawBufferPointer) {
        var position = 0
        while position < buffer.count {
            if offset % 8 == 0 && buffer.count - position >= 8 {
                unsafe buffer.storeBytes(of: next().littleEndian, toByteOffset: position, as: UInt64.self)
                position += 8
            } else {
                unsafe buffer[position] = byte()
                position += 1
            }
        }
    }
}

extension Threefry.Generator: Swift::RandomNumberGenerator {

    /// The next eight bytes, little-endian.
    public mutating func next() -> UInt64 {
        switch offset {
        case 0:
            offset = 8
            return current.first

        case 8:
            let value = current.second
            advance()
            return value

        case 1..<8:
            let shift = UInt64(offset) &* 8
            offset += 8
            return current.first &>> shift | current.second &<< (64 &- shift)

        default:
            let shift = UInt64(offset - 8) &* 8
            let low = current.second &>> shift
            let resume = offset - 8
            advance()
            offset = resume
            return low | current.first &<< (64 &- shift)
        }
    }
}
