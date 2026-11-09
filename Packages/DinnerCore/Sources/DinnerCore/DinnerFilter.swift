import Foundation

public struct FilterResult: Sendable, Hashable {
    public let dishes: [Dish]
    /// True when no safe dish fit the time limit, so slower safe dishes are offered instead.
    public let timeWasRelaxed: Bool
}

public enum DinnerFilter {
    /// INVARIANT: allergens, diet and avoided foods are never relaxed, whatever the request.
    public static func safeDishes(in catalogue: Catalogue, for profile: Profile) -> [Dish] {
        catalogue.dishes.filter { dish in
            catalogue.allergens(of: dish).isDisjoint(with: profile.allergens)
                && catalogue.kinds(of: dish).allSatisfy(profile.diet.allows)
                && dish.ingredients.allSatisfy { !profile.avoided.contains($0.id) }
        }
    }

    public static func apply(catalogue: Catalogue, profile: Profile, request: TonightRequest) -> FilterResult {
        let safe = safeDishes(in: catalogue, for: profile)
        guard let limit = request.maxMinutes else { return FilterResult(dishes: safe, timeWasRelaxed: false) }
        let inTime = safe.filter { $0.minutes <= limit }
        return inTime.isEmpty && !safe.isEmpty
            ? FilterResult(dishes: safe, timeWasRelaxed: true)
            : FilterResult(dishes: inTime, timeWasRelaxed: false)
    }
}
