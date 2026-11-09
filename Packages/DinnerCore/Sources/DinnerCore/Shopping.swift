import Foundation

public enum Shopping {
    /// What must be bought: not staples, not what the user said is at home.
    public static func missing(from dish: Dish, onHand: Set<String>, catalogue: Catalogue) -> [DishIngredient] {
        dish.ingredients.filter { catalogue.ingredients[$0.id]?.staple == false && !onHand.contains($0.id) }
    }

    /// The amount of one ingredient for `people`, in the catalogue's unit.
    public static func quantityText(_ item: DishIngredient, people: Int) -> String {
        guard let amount = item.amount else { return "to taste" }
        let scaled = amount * Double(people) / Double(Dish.baseServings)
        if item.unit == "g" || item.unit == "ml" {
            return "\(max(5, Int((scaled / 5).rounded()) * 5)) \(item.unit)"
        }
        // Round up to a quarter so scaling never drops an ingredient to nothing.
        let quarters = max(1, Int((scaled * 4).rounded(.up)))
        let whole = quarters / 4
        let fraction = ["", "¼", "½", "¾"][quarters % 4]
        let number = (whole > 0 ? "\(whole)" : "") + fraction
        guard !item.unit.isEmpty else { return number }
        let plural = quarters > 4 && ["cup", "can", "clove", "slice"].contains(item.unit)
        return "\(number) \(item.unit)\(plural ? "s" : "")"
    }
}
