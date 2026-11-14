/// Threefry-2x64-20, the counter-based generator of Salmon, Moraes, Dror and Shaw.
///
/// A counter-based generator is a keyed function from a counter to a block of random bits,
/// so any value of any stream can be computed directly, in any order and on any thread.
public enum Threefry {}

extension Threefry {

    /// The block for `counter` under `key`: Threefry-2x64 with 20 rounds.
    ///
    /// This is the whole generator. It is pure, so the block for a (key, stream, index)
    /// triple is `block(key: key, counter: Block(index, stream))`, computed without stepping.
    public static func block(key: Key, counter: Block) -> Block {
        let third = 0x1BD1_1BDA_A9FC_1A22 ^ key.first ^ key.second
        var first = counter.first &+ key.first
        var second = counter.second &+ key.second
        rounds(&first, &second, 16, 42, 12, 31)
        inject(&first, &second, key.second, third, 1)
        rounds(&first, &second, 16, 32, 24, 21)
        inject(&first, &second, third, key.first, 2)
        rounds(&first, &second, 16, 42, 12, 31)
        inject(&first, &second, key.first, key.second, 3)
        rounds(&first, &second, 16, 32, 24, 21)
        inject(&first, &second, key.second, third, 4)
        rounds(&first, &second, 16, 42, 12, 31)
        inject(&first, &second, third, key.first, 5)
        return Block(first, second)
    }

    /// The draw from [0, 1) for a (key, stream, index) triple, without making a generator first.
    ///
    /// It is the first `unit(as:)` of `Generator(key: key, stream: stream, index: index)`: the top bits
    /// of the first word of `block(key: key, counter: Block(index, stream))`, as many as the type's
    /// significand holds, as a share of one.
    public static func unit<Value: BinaryFloatingPoint>(
        key: Key,
        stream: UInt64 = 0,
        index: UInt64 = 0,
        as _: Value.Type = Value.self
    ) -> Value {
        unit(of: block(key: key, counter: Block(index, stream)).first, as: Value.self)
    }

    /// A 64-bit word as a value in [0, 1): its top bits, as many as the type's significand holds (at most
    /// 64), as a share of one.
    ///
    /// For a type with a significand of p bits, counting the implicit one, it is `word >> (64 − p)` times
    /// 2⁻ᵖ, `Double(word >> 11) * 0x1p-53` for `Double`: exact in the type, so never 1. It is `unit(as:)` of
    /// a generator whose next value is the word.
    @inlinable
    public static func unit<Value: BinaryFloatingPoint>(of word: UInt64, as _: Value.Type = Value.self) -> Value {
        let bits = Swift.min(Value.significandBitCount + 1, UInt64.bitWidth)
        let step = Value(sign: .plus, exponent: Value.Exponent(-bits), significand: 1)
        return Value(word >> UInt64(UInt64.bitWidth - bits)) * step
    }

    /// Four mix rounds with the given rotations.
    @inline(__always)
    private static func rounds(
        _ first: inout UInt64,
        _ second: inout UInt64,
        _ a: UInt64,
        _ b: UInt64,
        _ c: UInt64,
        _ d: UInt64
    ) {
        mix(&first, &second, a)
        mix(&first, &second, b)
        mix(&first, &second, c)
        mix(&first, &second, d)
    }

    /// One mix round: add, rotate the second word left by `rotation`, exclusive or.
    @inline(__always)
    private static func mix(_ first: inout UInt64, _ second: inout UInt64, _ rotation: UInt64) {
        first &+= second
        second = (second &<< rotation | second &>> (64 &- rotation)) ^ first
    }

    /// The key injection after every fourth round.
    @inline(__always)
    private static func inject(
        _ first: inout UInt64,
        _ second: inout UInt64,
        _ low: UInt64,
        _ high: UInt64,
        _ injection: UInt64
    ) {
        first &+= low
        second &+= high &+ injection
    }
}
