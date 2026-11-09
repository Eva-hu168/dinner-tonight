import Foundation

public struct RankedDish: Sendable, Hashable, Identifiable {
    public let dish: Dish
    public let score: Double
    public let reason: String
    /// Ids of non-staple ingredients not at home. Empty means no shopping, once a kitchen is known.
    public let missing: [String]

    public var id: String { dish.id }
}

public struct RankingInput: Sendable {
    public var catalogue: Catalogue
    public var request: TonightRequest
    public var history: [MealRecord]
    public var today: Date
    public var calendar: Calendar

    public init(catalogue: Catalogue, request: TonightRequest, history: [MealRecord], today: Date,
                calendar: Calendar = .current) {
        self.catalogue = catalogue
        self.request = request
        self.history = history
        self.today = today
        self.calendar = calendar
    }

    func daysAgo(_ date: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: today)).day ?? 0
    }

    /// Earlier dinners from the past week, leaving out any the user said they did not make.
    /// Today's own pick is left out too, so changing one's mind tonight is not penalised.
    var recentMeals: [(record: MealRecord, dish: Dish, days: Int)] {
        history.compactMap { record in
            let days = daysAgo(record.date)
            guard record.madeIt != false, (1...7).contains(days), let dish = catalogue.dish(id: record.dishID) else { return nil }
            return (record, dish, days)
        }
    }
}

public enum DinnerRanker {
    /// Best first. Scores are deterministic for a given day; the day only reorders near-ties.
    public static func rank(_ dishes: [Dish], input: RankingInput) -> [RankedDish] {
        let recent = input.recentMeals
        let seed = input.calendar.ordinality(of: .day, in: .era, for: input.today) ?? 0
        return dishes
            .map { score($0, input: input, recent: recent, seed: seed) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.dish.id < $1.dish.id }
    }

    /// One random dish, avoiding anything eaten in the past week when another is available.
    public static func surprise<G: RandomNumberGenerator>(from dishes: [Dish], input: RankingInput,
                                                          using generator: inout G) -> Dish? {
        let recentIDs = Set(input.recentMeals.map(\.dish.id))
        let fresh = dishes.filter { !recentIDs.contains($0.id) }
        return (fresh.isEmpty ? dishes : fresh).randomElement(using: &generator)
    }

    private static func score(_ dish: Dish, input: RankingInput,
                              recent: [(record: MealRecord, dish: Dish, days: Int)], seed: Int) -> RankedDish {
        let request = input.request
        var total = 0.0

        if recent.contains(where: { $0.dish.id == dish.id }) { total -= 6 }
        if recent.contains(where: { $0.dish.main == dish.main && $0.days <= 3 }) { total -= 2 }
        if recent.contains(where: { $0.dish.cuisine == dish.cuisine && $0.days <= 2 }) { total -= 0.5 }

        let countable = dish.ingredients.filter { input.catalogue.ingredients[$0.id]?.staple == false }
        let onHandCount = countable.filter { request.onHand.contains($0.id) }.count
        if !countable.isEmpty { total += 3 * Double(onHandCount) / Double(countable.count) }
        let missing = countable.map(\.id).filter { !request.onHand.contains($0) }
        // Heavier than a craving match, so a dinner needing a shop never beats one that doesn't.
        if !request.onHand.isEmpty { total -= 4 * Double(missing.count) }

        let cravingMatch = request.craving.map(dish.cravings.contains) ?? false
        if cravingMatch { total += 3 }

        if let effort = request.maxEffort {
            let excess = dish.effort.rawValue - effort.rawValue
            total += excess > 0 ? -1.5 * Double(excess) : 0.5
        }

        var overTime = false
        if let limit = request.maxMinutes {
            overTime = dish.minutes > limit
            total += overTime ? -Double(dish.minutes - limit) / 5 : 0.5
        }

        // The latest rating is the one that counts: tastes change.
        let rating = input.history.filter { $0.dishID == dish.id && $0.wouldRepeat != nil }
            .max { $0.date < $1.date }?.wouldRepeat
        if rating == true { total += 1.5 }
        if rating == false { total -= 4 }

        total += jitter(seed: seed, id: dish.id)

        let reason = reason(dish: dish, request: request, overTime: overTime, cravingMatch: cravingMatch,
                            onHandCount: onHandCount, rating: rating, recent: recent,
                            missingNames: missing.compactMap { input.catalogue.ingredients[$0]?.name.lowercased() })
        return RankedDish(dish: dish, score: total, reason: reason, missing: missing)
    }

    /// Every branch states something true of this dish tonight; the last one always applies.
    private static func reason(dish: Dish, request: TonightRequest, overTime: Bool, cravingMatch: Bool, onHandCount: Int,
                               rating: Bool?, recent: [(record: MealRecord, dish: Dish, days: Int)],
                               missingNames: [String]) -> String {
        if overTime { return "Takes \(dish.minutes) minutes, longer than you asked, but it's one of the closest fits." }
        if !request.onHand.isEmpty, missingNames.isEmpty || (onHandCount >= 1 && missingNames.count <= 2) {
            let mood = cravingMatch ? request.craving?.label : nil
            if missingNames.isEmpty { return mood.map { "\($0), and you have everything for it." } ?? "You have everything for this." }
            let list = missingNames.joined(separator: " and ")
            return mood.map { "\($0), and you'd only need \(list)." } ?? "You'd only need \(list)."
        }
        // A craving is usually shared by all three cards, so pair it with what sets this dish apart.
        if cravingMatch, let craving = request.craving {
            return onHandCount >= 2
                ? "\(craving.label), and you already have \(onHandCount) of the ingredients."
                : "\(craving.label), and ready in \(dish.minutes) minutes."
        }
        if onHandCount >= 2 { return "You already have \(onHandCount) of the ingredients." }
        if rating == true { return "You said you'd have this again." }
        if !recent.isEmpty, !recent.contains(where: { $0.dish.main == dish.main }) {
            return "You haven't had \(dish.main) this week."
        }
        return "Ready in \(dish.minutes) minutes."
    }

    /// FNV-1a, because `Hasher` is reseeded per process and would make the order unrepeatable.
    private static func jitter(seed: Int, id: String) -> Double {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in Array("\(seed):\(id)".utf8) {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Double(hash % 1000) / 2000
    }
}

/// The three cards on screen and what the user has already been shown.
public struct PickSession: Sendable, Hashable {
    public static let cardCount = 3

    public private(set) var cards: [RankedDish]
    public let timeWasRelaxed: Bool
    public let usedKitchen: Bool
    private let ranked: [RankedDish]
    private var seen: Set<String>

    /// True when a kitchen was given but every dinner on screen still needs something bought.
    public var needsShopping: Bool { usedKitchen && !cards.isEmpty && cards.allSatisfy { !$0.missing.isEmpty } }

    public init(ranked: [RankedDish], timeWasRelaxed: Bool, usedKitchen: Bool = false) {
        self.ranked = ranked
        self.timeWasRelaxed = timeWasRelaxed
        self.usedKitchen = usedKitchen
        cards = []
        seen = []
        for _ in 0..<Self.cardCount {
            guard let next = nextPick(avoiding: Set(cards.map(\.dish.main))) else { break }
            cards.append(next)
            seen.insert(next.id)
        }
    }

    /// Replaces a card with the best unseen dish. Returns false, changing nothing, when none is left.
    @discardableResult
    public mutating func swap(dishID: String) -> Bool {
        guard let index = cards.firstIndex(where: { $0.id == dishID }),
              let next = nextPick(avoiding: Set(cards.map(\.dish.main))) else { return false }
        cards[index] = next
        seen.insert(next.id)
        return true
    }

    /// Prefers a different main food, and falls back to a repeat only rather than show nothing.
    /// Variety never outweighs avoiding a shop: while a dinner can be cooked from the kitchen, only those are offered.
    private func nextPick(avoiding mains: Set<String>) -> RankedDish? {
        let unseen = ranked.filter { !seen.contains($0.id) }
        let cookable = unseen.filter { $0.missing.isEmpty }
        let pool = usedKitchen && !cookable.isEmpty ? cookable : unseen
        return pool.first { !mains.contains($0.dish.main) } ?? pool.first
    }
}
