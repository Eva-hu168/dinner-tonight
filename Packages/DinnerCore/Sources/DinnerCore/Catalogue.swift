import Foundation

public enum CatalogueError: Error, Equatable {
    case unknownIngredient(dish: String, ingredient: String)
    case duplicateDish(String)
}

/// The dishes and the one ingredient table their allergens and diet are derived from.
/// INVARIANT: a dish has no allergen field of its own, so listing an ingredient always carries its allergens.
public struct Catalogue: Sendable {
    public let ingredients: [String: Ingredient]
    public let dishes: [Dish]

    /// Throws on an unknown ingredient, because a dish that cannot be checked must not be shown.
    public init(ingredients: [Ingredient], dishes: [Dish]) throws {
        self.ingredients = Dictionary(ingredients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        for dish in dishes {
            guard seen.insert(dish.id).inserted else { throw CatalogueError.duplicateDish(dish.id) }
            for item in dish.ingredients where self.ingredients[item.id] == nil {
                throw CatalogueError.unknownIngredient(dish: dish.id, ingredient: item.id)
            }
        }
        self.dishes = dishes
    }

    public func allergens(of dish: Dish) -> Set<Allergen> {
        dish.ingredients.reduce(into: Set<Allergen>()) { $0.formUnion(ingredients[$1.id]?.allergens ?? []) }
    }

    public func kinds(of dish: Dish) -> Set<FoodKind> {
        Set(dish.ingredients.compactMap { ingredients[$0.id]?.kind })
    }

    /// Ingredients worth tracking in a kitchen, by name.
    public var pickable: [Ingredient] {
        ingredients.values.filter { !$0.staple }.sorted { $0.name < $1.name }
    }

    public func dish(id: String) -> Dish? { dishes.first { $0.id == id } }

    private struct Raw: Decodable {
        struct RawDish: Decodable {
            let id, name, emoji, cuisine, main: String
            let minutes: Int
            let effort: Int
            let cravings: [Craving]
            let ingredients, steps: [String]
        }

        let ingredients: [Ingredient]
        let dishes: [RawDish]
    }

    public static func decode(_ data: Data) throws -> Catalogue {
        let raw = try JSONDecoder().decode(Raw.self, from: data)
        let dishes = raw.dishes.map { dish in
            Dish(id: dish.id, name: dish.name, emoji: dish.emoji, cuisine: dish.cuisine, main: dish.main,
                 minutes: dish.minutes, effort: Effort(rawValue: dish.effort) ?? .involved,
                 cravings: Set(dish.cravings), ingredients: dish.ingredients.map(DishIngredient.init(encoded:)),
                 steps: dish.steps)
        }
        return try Catalogue(ingredients: raw.ingredients, dishes: dishes)
    }

    public static func bundled() throws -> Catalogue {
        guard let url = Bundle.module.url(forResource: "catalogue", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(Data(contentsOf: url))
    }
}
