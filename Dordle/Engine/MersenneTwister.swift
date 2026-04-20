import Foundation

/// Mersenne Twister (MT19937) RNG — 32-bit output.
///
/// Port of Makoto Matsumoto & Takuji Nishimura's reference implementation, by
/// way of Sean McCullough's JavaScript port that ships with the original
/// Dordle (zaratustra.itch.io/dordle). Intentionally bit-identical to that
/// JS version so the same seed produces the same output across both.
struct MersenneTwister {
    private static let n = 624
    private static let m = 397
    private static let matrixA: UInt32 = 0x9908b0df
    private static let upperMask: UInt32 = 0x80000000
    private static let lowerMask: UInt32 = 0x7fffffff

    private var mt = [UInt32](repeating: 0, count: n)
    private var mti: Int = n + 1

    init(seed: UInt32) {
        initGenrand(seed)
    }

    private mutating func initGenrand(_ s: UInt32) {
        mt[0] = s
        for i in 1..<Self.n {
            let prev = mt[i - 1] ^ (mt[i - 1] >> 30)
            // ((prev_hi16 * 1812433253) << 16) + (prev_lo16 * 1812433253) + i
            // — faithful reproduction of the JS bit-math.
            let hi = (prev & 0xffff0000) >> 16
            let lo = prev & 0x0000ffff
            let result = ((hi &* 1812433253) << 16) &+ (lo &* 1812433253) &+ UInt32(i)
            mt[i] = result
        }
        mti = Self.n
    }

    /// Equivalent to `genrand_int32()` — full 32-bit output.
    mutating func genrandInt32() -> UInt32 {
        let mag01: [UInt32] = [0, Self.matrixA]
        var y: UInt32

        if mti >= Self.n {
            for kk in 0..<(Self.n - Self.m) {
                y = (mt[kk] & Self.upperMask) | (mt[kk + 1] & Self.lowerMask)
                mt[kk] = mt[kk + Self.m] ^ (y >> 1) ^ mag01[Int(y & 0x1)]
            }
            for kk in (Self.n - Self.m)..<(Self.n - 1) {
                y = (mt[kk] & Self.upperMask) | (mt[kk + 1] & Self.lowerMask)
                mt[kk] = mt[kk + (Self.m - Self.n)] ^ (y >> 1) ^ mag01[Int(y & 0x1)]
            }
            y = (mt[Self.n - 1] & Self.upperMask) | (mt[0] & Self.lowerMask)
            mt[Self.n - 1] = mt[Self.m - 1] ^ (y >> 1) ^ mag01[Int(y & 0x1)]
            mti = 0
        }

        y = mt[mti]
        mti += 1

        // Tempering
        y ^= (y >> 11)
        y ^= (y << 7) & 0x9d2c5680
        y ^= (y << 15) & 0xefc60000
        y ^= (y >> 18)
        return y
    }

    /// Equivalent to `genrand_int31()` — 31-bit output (top bit cleared).
    mutating func genrandInt31() -> UInt32 {
        return genrandInt32() >> 1
    }
}
