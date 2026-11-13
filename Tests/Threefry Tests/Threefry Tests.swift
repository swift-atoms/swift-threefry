import Testing
import Threefry

enum `Threefry Tests` {}

extension `Threefry Tests` {
    @Suite
    struct `Threefry block contracts` {
        @Test
        func `The published known-answer vectors hold`() {
            #expect(
                Threefry.block(key: .init(0, 0), counter: .init(0, 0))
                    == .init(0xc2b6_e3a8_c2c6_9865, 0x6f81_ed42_f350_084d)
            )
            let ones = UInt64.max
            #expect(
                Threefry.block(key: .init(ones, ones), counter: .init(ones, ones))
                    == .init(0xe02c_b7c4_d95d_277a, 0xd066_33d0_893b_8b68)
            )
            #expect(
                Threefry.block(
                    key: .init(0xa409_3822_299f_31d0, 0x082e_fa98_ec4e_6c89),
                    counter: .init(0x243f_6a88_85a3_08d3, 0x1319_8a2e_0370_7344)
                ) == .init(0x263c_7d30_bb0f_0af1, 0x56be_8361_d331_1526)
            )
        }
    }
}

extension `Threefry Tests`.`Threefry block contracts` {
    @Test
    func `Distinct counters under one key give distinct blocks`() {
        let key = Threefry.Key(0x0123_4567_89ab_cdef, 0xfedc_ba98_7654_3210)
        var seen = Set<Threefry.Block>()
        (0..<64 as Range<UInt64>).forEach { first in
            (0..<64 as Range<UInt64>).forEach { second in
                seen.insert(Threefry.block(key: key, counter: .init(first, second)))
            }
        }
        #expect(seen.count == 4096)
    }

    @Test
    func `Every key word and counter word changes the block`() {
        let base = Threefry.block(key: .init(1, 2), counter: .init(3, 4))
        #expect(Threefry.block(key: .init(0, 2), counter: .init(3, 4)) != base)
        #expect(Threefry.block(key: .init(1, 0), counter: .init(3, 4)) != base)
        #expect(Threefry.block(key: .init(1, 2), counter: .init(0, 4)) != base)
        #expect(Threefry.block(key: .init(1, 2), counter: .init(3, 0)) != base)
        #expect(Threefry.block(key: .init(1, 2), counter: .init(3, 4)) == base)
    }

    @Test
    func `A block reads as sixteen bytes with each word little-endian`() {
        let block = Threefry.Block(0x0807_0605_0403_0201, 0x100f_0e0d_0c0b_0a09)
        #expect(block.bytes.count == 16)
        block.bytes.indices.forEach { offset in
            #expect(block.bytes[offset] == UInt8(offset + 1))
        }
    }
}

extension `Threefry Tests` {
    @Suite
    struct `Threefry generator contracts` {
        private let key = Threefry.Key(0x243f_6a88_85a3_08d3, 0x1319_8a2e_0370_7344)

        private func bytes(_ count: Int, from generator: inout Threefry.Generator) -> [UInt8] {
            var result = [UInt8](repeating: 0, count: count)
            result.withUnsafeMutableBytes { buffer in unsafe generator.fill(buffer) }
            return result
        }

        @Test
        func `The byte stream is the blocks at successive indices of the stream`() {
            var generator = Threefry.Generator(key: key, stream: 7)
            let stream = bytes(48, from: &generator)
            (0..<3).forEach { index in
                let block = Threefry.block(key: key, counter: .init(UInt64(index), 7))
                (0..<16).forEach { offset in
                    #expect(stream[index * 16 + offset] == block.bytes[offset])
                }
            }
            #expect(generator.index == 3)
            #expect(generator.offset == 0)
        }

        @Test
        func `Splitting a fill into pieces gives the same bytes`() {
            var whole = Threefry.Generator(key: key)
            let expected = bytes(100, from: &whole)
            for pieces in [[100], [1, 99], [15, 1, 16, 17, 51], [0, 33, 0, 67], [16, 16, 16, 16, 16, 20]] {
                var generator = Threefry.Generator(key: key)
                var collected: [UInt8] = []
                for piece in pieces { collected += bytes(piece, from: &generator) }
                #expect(collected == expected)
                #expect(generator == whole)
            }
        }

        @Test
        func `Single bytes and 64-bit values read the same stream`() {
            var reference = Threefry.Generator(key: key)
            let expected = bytes(40, from: &reference)

            var single = Threefry.Generator(key: key)
            #expect((0..<40).map { _ in single.byte() } == expected)

            var words = Threefry.Generator(key: key)
            _ = words.byte()
            (0..<4).forEach { word in
                var value: UInt64 = 0
                (0..<8).forEach { position in
                    value |= UInt64(expected[1 + word * 8 + position]) << UInt64(position * 8)
                }
                #expect(words.next() == value)
            }
            #expect(words.index == 2)
            #expect(words.offset == 1)
        }

        @Test
        func `Starting at an index equals skipping to it`() {
            var skipped = Threefry.Generator(key: key, stream: 3)
            _ = bytes(16 * 5, from: &skipped)
            var direct = Threefry.Generator(key: key, stream: 3, index: 5)
            #expect(direct == skipped)
            #expect(bytes(32, from: &direct) == bytes(32, from: &skipped))
            #expect(direct.block(at: 9) == Threefry.block(key: key, counter: .init(9, 3)))
        }

        @Test
        func `Streams and keys are independent of each other`() {
            var first = Threefry.Generator(key: key, stream: 0)
            var second = Threefry.Generator(key: key, stream: 1)
            var other = Threefry.Generator(key: .init(key.first, key.second ^ 1), stream: 0)
            let a = bytes(32, from: &first)
            #expect(a != bytes(32, from: &second))
            #expect(a != bytes(32, from: &other))
        }

        @Test
        func `An empty fill changes nothing and the index wraps after its last block`() {
            var generator = Threefry.Generator(key: key, index: .max)
            let before = generator
            #expect(bytes(0, from: &generator).isEmpty)
            #expect(generator == before)
            let last = bytes(16, from: &generator)
            #expect(generator.index == 0)
            var start = Threefry.Generator(key: key)
            #expect(bytes(16, from: &generator) == bytes(16, from: &start))
            #expect(last != bytes(16, from: &start))
        }

        @Test
        func `The generator serves as a random source and as a standard generator`() throws {
            var source: any Random.Generator = Threefry.Generator(key: key)
            var buffer = [UInt8](repeating: 0, count: 8)
            try buffer.withUnsafeMutableBytes { bytes in unsafe try source.fill(bytes) }
            var reference = Threefry.Generator(key: key)
            #expect(buffer == bytes(8, from: &reference))

            var first = Threefry.Generator(key: key)
            var second = Threefry.Generator(key: key)
            let draws = (0..<32).map { _ in Int.random(in: 0..<1000, using: &first) }
            #expect(draws == (0..<32).map { _ in Int.random(in: 0..<1000, using: &second) })
            #expect(Set(draws).count > 16)
        }
    }
}

extension `Threefry Tests`.`Threefry generator contracts` {
    @Test
    func `The generator reproduces the values recorded before buffering`() {
        var generator = Threefry.Generator(key: key, stream: 5)
        var values = (0..<6).map { _ in generator.next() }
        _ = generator.byte()
        values += (0..<5).map { _ in generator.next() }
        let filled = bytes(13, from: &generator)
        values += (0..<3).map { _ in generator.next() }
        #expect(
            values == [
                0xf5ec_2fa1_912a_744c, 0xc6ec_9a3e_3ccb_836b, 0xd39e_5724_e8be_0c58,
                0x03e0_0fe2_cce4_f4a2, 0xa780_f788_f483_2815, 0x2356_b8dd_befc_ef55,
                0x2cf5_4dfc_7370_3e13, 0x41c9_2b4c_70e8_3a5a, 0x7a60_e586_cba4_a416,
                0x8245_04c6_2fff_c422, 0xc826_3ee3_d938_986b, 0x04fd_ab11_5721_c541,
                0x19c8_108c_4ff0_b788, 0xb89a_9e88_9566_9020,
            ]
        )
        #expect(filled == [234, 244, 145, 222, 190, 201, 116, 195, 135, 110, 46, 108, 143])
        #expect(generator.index == 7)
        #expect(generator.offset == 14)
    }
}

extension `Threefry Tests`.`Threefry generator contracts` {
    @Test
    func `A 64-bit value from any offset is the next eight bytes`() {
        var reference = Threefry.Generator(key: key, stream: 2)
        let expected = bytes(64, from: &reference)
        (0..<16).forEach { start in
            var generator = Threefry.Generator(key: key, stream: 2)
            _ = bytes(start, from: &generator)
            (0..<4).forEach { word in
                var value: UInt64 = 0
                (0..<8).forEach { position in
                    value |= UInt64(expected[start + word * 8 + position]) << UInt64(position * 8)
                }
                #expect(generator.next() == value)
            }
        }
    }

    @Test
    func `A keyed draw is the generator for its triple without stepping`() {
        var stepped = Threefry.Generator(key: key, stream: 11)
        _ = (0..<6).map { _ in stepped.next() }
        var keyed = Threefry.Generator(key: key, stream: 11, index: 3)
        #expect(keyed == stepped)
        #expect((0..<9).map { _ in keyed.next() } == (0..<9).map { _ in stepped.next() })
        let block = Threefry.block(key: key, counter: .init(3, 11))
        var fresh = Threefry.Generator(key: key, stream: 11, index: 3)
        #expect(fresh.next() == block.first)
        #expect(fresh.next() == block.second)
    }
}
