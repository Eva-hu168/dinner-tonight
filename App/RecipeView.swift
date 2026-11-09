import DinnerCore
import SwiftUI

struct RecipeView: View {
    @Environment(AppModel.self) private var model
    let dish: Dish
    let reason: String?
    @Binding var path: [Route]
    @State private var people: Int?
    @State private var bought: Set<String> = []

    private var servings: Int { people ?? model.profile.people }
    private var toBuy: [DishIngredient] { Shopping.missing(from: dish, onHand: model.kitchen, catalogue: model.catalogue) }
    private var kitchenKnown: Bool { !model.kitchen.isEmpty }
    private var alreadyHave: [DishIngredient] {
        let buying = Set(toBuy.map(\.id))
        return dish.ingredients.filter { !buying.contains($0.id) }
    }
    private var isChosen: Bool { model.tonight?.id == dish.id }

    private var containsText: String? {
        let found = Allergen.allCases.filter(model.catalogue.allergens(of: dish).contains)
        return found.isEmpty ? nil : "Contains: " + found.map(\.label).joined(separator: ", ")
    }

    private func name(_ item: DishIngredient) -> String { model.catalogue.ingredients[item.id]?.name ?? item.id }

    private func line(_ item: DishIngredient) -> String { "\(Shopping.quantityText(item, people: servings)) \(name(item))" }

    private var shoppingText: String {
        (["\(dish.name): shopping list"] + toBuy.map { "• \(line($0))" }).joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                Stepper("Serves \(servings)", value: Binding(get: { servings }, set: { people = $0 }), in: 1...8)
                    .padding()
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
                if toBuy.isEmpty && kitchenKnown {
                    Label("You have everything for this. No shopping needed.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brand)
                }
                if !toBuy.isEmpty { shoppingSection }
                if !alreadyHave.isEmpty { haveSection }
                stepsSection
                allergenNote
            }
            .padding()
        }
        .background(Color.page)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !toBuy.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink("Share shopping list", item: shoppingText)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if isChosen {
                    Button("Done") { path = [] }
                } else {
                    Button("Make this tonight") { model.choose(dish); path = [] }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            .background(.bar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Emoji(dish.emoji, size: 60)
            Text(dish.name).font(.title.bold())
            Text(dish.summary).foregroundStyle(.secondary)
            if let reason { Text(reason).foregroundStyle(Color.brand) }
        }
    }

    private var shoppingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: kitchenKnown ? "You'd still need" : "To buy").padding(.bottom, 6)
            ForEach(toBuy) { item in
                Button {
                    if bought.remove(item.id) == nil { bought.insert(item.id) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: bought.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(bought.contains(item.id) ? Color.brand : Color.secondary)
                        Text(line(item))
                            .strikethrough(bought.contains(item.id))
                            .foregroundStyle(bought.contains(item.id) ? .secondary : .primary)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(bought.contains(item.id) ? .isSelected : [])
            }
        }
    }

    private var haveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "From your kitchen")
            ForEach(alreadyHave) { item in
                Text(line(item)).foregroundStyle(.secondary)
            }
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Steps")
            ForEach(Array(dish.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + 1)").font(.headline).foregroundStyle(Color.brand)
                    Text(step).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var allergenNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let containsText { Text(containsText).font(.footnote.weight(.semibold)) }
            Text("Based on typical versions of these ingredients. Products vary, so always check the labels of what you use.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
