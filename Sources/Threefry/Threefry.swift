public enum Threefry {}

extension Threefry {

    public static func block(key: Key, counter: Block) -> Block {
        let parity: UInt64 = 0x1BD1_1BDA_A9FC_1A22
        let schedule: InlineArray<3, UInt64> = [key.first, key.second, parity ^ key.first ^ key.second]
        let rotations: InlineArray<8, UInt64> = [16, 42, 12, 31, 16, 32, 24, 21]
        var first = counter.first &+ schedule[0]
        var second = counter.second &+ schedule[1]
        (0..<20).forEach { round in
            first &+= second
            let rotation = rotations[round % 8]
            second = (second << rotation) | (second >> (64 - rotation))
            second ^= first
            if round % 4 == 3 {
                let injection = round / 4 + 1
                first &+= schedule[injection % 3]
                second &+= schedule[(injection + 1) % 3] &+ UInt64(injection)
            }
        }
        return Block(first, second)
    }
}
