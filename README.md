# swift-threefry

Use this package when you need random bits that are the same for the same seed on every machine, and that you can ask for in any order: the value for a seed, a stream and an index, with no earlier value computed first. Start from `Threefry.block(key:counter:)`, the pure function, or from `Threefry.Generator`, which reads the same blocks in order and conforms to `Random.Generator` from swift-random and to the standard library's `RandomNumberGenerator`. It is Threefry-2x64-20 of Salmon, Moraes, Dror and Shaw (*Parallel random numbers: as easy as 1, 2, 3*, SC'11). It is not a cryptographic generator: for secrets, use a platform source that conforms to `Random.Generator`.

## Laws

- `Threefry.block(key:counter:)` is Threefry-2x64 with 20 rounds, and reproduces the published known-answer vectors. It uses only 64-bit wrapping addition, rotation and exclusive or, so the result is the same on every platform and word size.
- For a fixed key, `block` is a bijection on counters: two different counters never give the same block.
- A `Threefry.Block` reads as 16 `bytes`: `first` then `second`, each little-endian, whatever the byte order of the machine.
- The byte stream of a `Threefry.Generator` is the blocks at counter `(index, stream)` for `index`, `index + 1`, and so on. It depends only on the key, the stream and the position, so any way of splitting a read into `fill`, `byte()` and `next()` calls yields the same bytes. `next()` is the next eight bytes, little-endian.
- A generator created at `index` equals one that has read `16 * index` bytes from the start. `block(at:)` reads any block without moving the generator.
- `fill` never fails, and an empty buffer leaves the generator unchanged.
- The index wraps: after block `UInt64.max` comes block 0, so a stream repeats after 2^68 bytes.
- Equality and hashing compare key, stream and position. Two equal generators produce the same bytes.
