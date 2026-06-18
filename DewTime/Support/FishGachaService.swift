import Foundation

/// 餌やり時の魚種ガチャ。プールは現在の水槽 tier で解放済みの種のみ。
enum FishGachaService {
    static func eligibleSpecies(tier: Int) -> [FishSpecies] {
        FishSpecies.allCases.filter { $0.requiredAquariumTier <= tier }
    }

    static func weight(for species: FishSpecies) -> Double {
        1.0 / Double(species.requiredAquariumTier + 1)
    }

    static func rollSpecies(tier: Int, rng: inout some RandomNumberGenerator) -> FishSpecies {
        let pool = eligibleSpecies(tier: tier)
        guard !pool.isEmpty else { return .medaka }

        let weights = pool.map(weight(for:))
        let total = weights.reduce(0, +)
        var roll = Double.random(in: 0..<total, using: &rng)

        for (species, weight) in zip(pool, weights) {
            roll -= weight
            if roll <= 0 { return species }
        }
        return pool.last ?? .medaka
    }

    static func rollSpecies(tier: Int) -> FishSpecies {
        var rng = SystemRandomNumberGenerator()
        return rollSpecies(tier: tier, rng: &rng)
    }
}
