import Foundation

public enum Allergen: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case milk, egg, fish, shellfish, treeNuts, peanuts, wheat, gluten, soy, sesame

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .milk: "Milk"
        case .egg: "Eggs"
        case .fish: "Fish"
        case .shellfish: "Shellfish"
        case .treeNuts: "Tree nuts"
        case .peanuts: "Peanuts"
        case .wheat: "Wheat"
        case .gluten: "Gluten"
        case .soy: "Soy"
        case .sesame: "Sesame"
        }
    }
}

public enum FoodKind: String, Codable, Sendable, Hashable {
    case plant, dairy, egg, honey, fish, shellfish, poultry, meat
}

public enum Diet: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case none, pescatarian, vegetarian, vegan

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none: "I eat everything"
        case .pescatarian: "Pescatarian"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        }
    }

    public func allows(_ kind: FoodKind) -> Bool {
        switch self {
        case .none: true
        case .pescatarian: kind != .meat && kind != .poultry
        case .vegetarian: [.plant, .dairy, .egg, .honey].contains(kind)
        case .vegan: kind == .plant
        }
    }
}

public enum Effort: Int, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case easy = 1, medium, involved

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Some effort"
        case .involved: "Project"
        }
    }

    /// How the Tonight screen asks for it.
    public var askLabel: String {
        switch self {
        case .easy: "Barely any"
        case .medium: "A little"
        case .involved: "Happy to cook"
        }
    }
}

public enum Craving: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case comfort, light, spicy, fresh, hearty

    public var id: String { rawValue }

    public var label: String { rawValue.capitalized }
}

public struct Ingredient: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let kind: FoodKind
    public let allergens: Set<Allergen>
    public let group: String
    /// Assumed to be in every kitchen: never on a shopping list and never counted as missing.
    public let staple: Bool
}

public struct DishIngredient: Sendable, Hashable, Identifiable {
    public let id: String
    /// Nil means "to taste".
    public let amount: Double?
    public let unit: String

    /// Reads the catalogue's `id:amount:unit` form; amount and unit are optional.
    init(encoded: String) {
        let parts = encoded.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        id = parts[0]
        amount = parts.count > 1 ? Double(parts[1]) : nil
        unit = parts.count > 2 ? parts[2] : ""
    }
}

public struct Dish: Sendable, Hashable, Identifiable {
    /// Every catalogue amount is written for this many people.
    public static let baseServings = 2

    public let id: String
    public let name: String
    public let emoji: String
    public let cuisine: String
    /// The food that defines the dish ("chicken", "beans"); variety and swaps compare it.
    public let main: String
    public let minutes: Int
    public let effort: Effort
    public let cravings: Set<Craving>
    public let ingredients: [DishIngredient]
    public let steps: [String]
}

public struct Profile: Codable, Sendable, Hashable {
    public var people: Int
    public var allergens: Set<Allergen>
    public var diet: Diet
    /// Ingredient ids this household will not eat; filtered as strictly as an allergen.
    public var avoided: Set<String>
    /// Default for tonight's time limit; nil means no limit.
    public var usualMinutes: Int?

    public init(people: Int = 2, allergens: Set<Allergen> = [], diet: Diet = .none,
                avoided: Set<String> = [], usualMinutes: Int? = 30) {
        self.people = people
        self.allergens = allergens
        self.diet = diet
        self.avoided = avoided
        self.usualMinutes = usualMinutes
    }
}

public struct TonightRequest: Sendable, Hashable {
    public var maxMinutes: Int?
    public var maxEffort: Effort?
    public var craving: Craving?
    public var onHand: Set<String>

    public init(maxMinutes: Int? = nil, maxEffort: Effort? = nil, craving: Craving? = nil, onHand: Set<String> = []) {
        self.maxMinutes = maxMinutes
        self.maxEffort = maxEffort
        self.craving = craving
        self.onHand = onHand
    }
}

public struct MealRecord: Codable, Sendable, Hashable {
    public var dishID: String
    public var date: Date
    /// Nil until the next-day question is answered.
    public var madeIt: Bool?
    public var wouldRepeat: Bool?

    public init(dishID: String, date: Date, madeIt: Bool? = nil, wouldRepeat: Bool? = nil) {
        self.dishID = dishID
        self.date = date
        self.madeIt = madeIt
        self.wouldRepeat = wouldRepeat
    }
}
