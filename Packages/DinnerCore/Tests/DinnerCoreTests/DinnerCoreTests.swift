import Foundation
import Testing
@testable import DinnerCore

private let catalogue = try! Catalogue.bundled()
private let calendar: Calendar = {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(identifier: "UTC")!
    return value
}()
private let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 18))!

private func daysBefore(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: today)! }

private func input(_ request: TonightRequest = TonightRequest(), history: [MealRecord] = []) -> RankingInput {
    RankingInput(catalogue: catalogue, request: request, history: history, today: today, calendar: calendar)
}

private func session(_ profile: Profile, _ request: TonightRequest = TonightRequest(), history: [MealRecord] = []) -> PickSession {
    let filtered = DinnerFilter.apply(catalogue: catalogue, profile: profile, request: request)
    return PickSession(ranked: DinnerRanker.rank(filtered.dishes, input: input(request, history: history)),
                       timeWasRelaxed: filtered.timeWasRelaxed)
}

@Suite struct CatalogueChecks {
    @Test func loadsAndIsLargeEnough() {
        #expect(catalogue.dishes.count >= 40)
    }

    @Test func unknownIngredientIsRejected() throws {
        let dish = Dish(id: "x", name: "X", emoji: "", cuisine: "", main: "", minutes: 1, effort: .easy, cravings: [],
                        ingredients: [DishIngredient(encoded: "mystery")], steps: [])
        #expect(throws: CatalogueError.unknownIngredient(dish: "x", ingredient: "mystery")) {
            try Catalogue(ingredients: [], dishes: [dish])
        }
    }

    @Test(arguments: [
        ("butter", Allergen.milk), ("cheddar", .milk), ("mozzarella", .milk), ("parmesan", .milk), ("feta", .milk),
        ("yogurt", .milk), ("sour_cream", .milk), ("milk", .milk), ("pesto", .milk), ("pesto", .treeNuts),
        ("egg", .egg), ("mayo", .egg), ("ramen", .egg), ("salmon", .fish), ("white_fish", .fish), ("tuna_can", .fish),
        ("fish_sauce", .fish), ("red_curry_paste", .fish), ("red_curry_paste", .shellfish), ("shrimp", .shellfish),
        ("oyster_sauce", .shellfish), ("cashews", .treeNuts), ("peanuts", .peanuts), ("peanut_butter", .peanuts),
        ("pasta", .wheat), ("pasta", .gluten), ("couscous", .gluten), ("flour", .gluten), ("flour_tortilla", .gluten),
        ("bread", .gluten), ("burger_bun", .gluten), ("breadcrumbs", .gluten), ("ramen", .gluten), ("soy_sauce", .gluten),
        ("gochujang", .gluten), ("soy_sauce", .soy), ("tofu", .soy), ("miso", .soy), ("gochujang", .soy),
        ("sesame_oil", .sesame), ("sesame_seeds", .sesame), ("burger_bun", .sesame),
    ])
    func knownIngredientCarriesAllergen(id: String, allergen: Allergen) throws {
        let ingredient = try #require(catalogue.ingredients[id])
        #expect(ingredient.allergens.contains(allergen))
    }

    /// A new ingredient whose name gives away an allergen must be tagged with it.
    @Test func ingredientNamesAgreeWithTags() {
        let rules: [(String, Allergen, Set<String>)] = [
            ("peanut", .peanuts, []), ("sesame", .sesame, []), ("soy", .soy, []), ("shrimp", .shellfish, []),
            ("egg", .egg, ["eggplant"]), ("fish", .fish, []), ("cheese", .milk, []), ("cream", .milk, []),
            ("butter", .milk, ["peanut_butter"]), ("yogurt", .milk, []), ("milk", .milk, ["coconut_milk"]),
            ("flour", .gluten, []), ("bread", .gluten, []), ("pasta", .gluten, []),
        ]
        for ingredient in catalogue.ingredients.values {
            for (word, allergen, exceptions) in rules
            where ingredient.id.contains(word) && !exceptions.contains(ingredient.id) {
                #expect(ingredient.allergens.contains(allergen), "\(ingredient.id) should carry \(allergen)")
            }
        }
    }

    @Test func animalIngredientsAreNotPlant() {
        for id in ["chicken_broth", "fish_sauce", "oyster_sauce", "honey", "mayo", "pesto", "red_curry_paste"] {
            #expect(catalogue.ingredients[id]?.kind != .plant, "\(id)")
        }
    }

    @Test func everyDishHasStepsAndValidAmounts() {
        for dish in catalogue.dishes {
            #expect(!dish.steps.isEmpty, "\(dish.id)")
            #expect(!dish.cravings.isEmpty, "\(dish.id)")
            for item in dish.ingredients where catalogue.ingredients[item.id]?.staple == false {
                #expect((item.amount ?? 0) > 0, "\(dish.id) \(item.id)")
            }
        }
    }
}

@Suite struct FilterChecks {
    @Test(arguments: Allergen.allCases)
    func allergenNeverSurvivesAndChoiceRemains(allergen: Allergen) {
        let safe = DinnerFilter.safeDishes(in: catalogue, for: Profile(allergens: [allergen]))
        #expect(safe.count >= 3)
        for dish in safe {
            #expect(!catalogue.allergens(of: dish).contains(allergen), "\(dish.id)")
        }
    }

    @Test(arguments: [Diet.pescatarian, .vegetarian, .vegan])
    func dietIsRespected(diet: Diet) {
        let safe = DinnerFilter.safeDishes(in: catalogue, for: Profile(diet: diet))
        #expect(safe.count >= 3)
        for dish in safe { #expect(catalogue.kinds(of: dish).allSatisfy(diet.allows), "\(dish.id)") }
    }

    @Test func veganExcludesHiddenAnimalFoods() {
        let ids = Set(DinnerFilter.safeDishes(in: catalogue, for: Profile(diet: .vegan)).map(\.id))
        #expect(!ids.contains("turkey_lettuce_wraps"))
        #expect(!ids.contains("miso_salmon"))
        #expect(ids.contains("chickpea_curry"))
    }

    @Test func avoidedIngredientIsRemoved() {
        let safe = DinnerFilter.safeDishes(in: catalogue, for: Profile(avoided: ["coconut_milk"]))
        #expect(!safe.isEmpty)
        #expect(safe.allSatisfy { dish in !dish.ingredients.contains { $0.id == "coconut_milk" } })
    }

    @Test func timeRelaxesButSafetyDoesNot() {
        let profile = Profile(allergens: [.milk])
        let result = DinnerFilter.apply(catalogue: catalogue, profile: profile, request: TonightRequest(maxMinutes: 5))
        #expect(result.timeWasRelaxed)
        #expect(!result.dishes.isEmpty)
        #expect(result.dishes.allSatisfy { !catalogue.allergens(of: $0).contains(.milk) })
    }

    @Test func timeLimitHoldsWhenSomethingFits() {
        let result = DinnerFilter.apply(catalogue: catalogue, profile: Profile(), request: TonightRequest(maxMinutes: 15))
        #expect(!result.timeWasRelaxed)
        #expect(result.dishes.allSatisfy { $0.minutes <= 15 })
    }

    @Test func nothingSafeStaysEmpty() {
        let everything = Set(catalogue.ingredients.keys)
        let result = DinnerFilter.apply(catalogue: catalogue, profile: Profile(avoided: everything),
                                        request: TonightRequest(maxMinutes: 15))
        #expect(result.dishes.isEmpty)
        #expect(!result.timeWasRelaxed)
    }
}

@Suite struct RankerChecks {
    @Test func sameInputGivesSameOrder() {
        let first = DinnerRanker.rank(catalogue.dishes, input: input()).map(\.id)
        let second = DinnerRanker.rank(catalogue.dishes, input: input()).map(\.id)
        #expect(first == second)
    }

    @Test func recentDishDropsAndDinnerNotMadeDoesNot() throws {
        let baseline = DinnerRanker.rank(catalogue.dishes, input: input())
        let dishID = try #require(baseline.first?.id)
        let ate = MealRecord(dishID: dishID, date: daysBefore(2), madeIt: true)
        let skipped = MealRecord(dishID: dishID, date: daysBefore(2), madeIt: false)
        func score(_ history: [MealRecord]) -> Double? {
            DinnerRanker.rank(catalogue.dishes, input: input(history: history)).first { $0.id == dishID }?.score
        }
        #expect(try #require(score([ate])) < baseline[0].score - 5)
        #expect(score([skipped]) == baseline[0].score)
    }

    @Test func oldMealsDoNotCount() throws {
        let baseline = DinnerRanker.rank(catalogue.dishes, input: input())
        let dishID = try #require(baseline.first?.id)
        let old = MealRecord(dishID: dishID, date: daysBefore(8), madeIt: true)
        let ranked = DinnerRanker.rank(catalogue.dishes, input: input(history: [old]))
        #expect(ranked.first { $0.id == dishID }?.score == baseline[0].score)
    }

    @Test func cravingLeadsAndIsExplained() throws {
        let top = try #require(DinnerRanker.rank(catalogue.dishes, input: input(TonightRequest(craving: .spicy))).first)
        #expect(top.dish.cravings.contains(.spicy))
        #expect(top.reason == "Spicy, and ready in \(top.dish.minutes) minutes.")
    }

    @Test func cravingReasonNamesIngredientsOnHand() throws {
        let dish = try #require(catalogue.dish(id: "egg_fried_rice"))
        let request = TonightRequest(craving: .comfort, onHand: ["rice", "egg"])
        let ranked = try #require(DinnerRanker.rank([dish], input: input(request)).first)
        #expect(ranked.reason == "Comfort, and you already have 2 of the ingredients.")
    }

    @Test func dislikedDishFallsLatestRatingWins() throws {
        let dishID = "shakshuka"
        let older = MealRecord(dishID: dishID, date: daysBefore(30), madeIt: true, wouldRepeat: false)
        let newer = MealRecord(dishID: dishID, date: daysBefore(20), madeIt: true, wouldRepeat: true)
        func score(_ history: [MealRecord]) -> Double {
            DinnerRanker.rank(catalogue.dishes, input: input(history: history)).first { $0.id == dishID }!.score
        }
        #expect(score([older]) < score([]))
        #expect(score([older, newer]) > score([]))
    }

    @Test func onHandIsCountedOnlyWhenTrue() throws {
        let dish = try #require(catalogue.dish(id: "egg_fried_rice"))
        let request = TonightRequest(onHand: ["rice", "egg"])
        let ranked = try #require(DinnerRanker.rank([dish], input: input(request)).first)
        #expect(ranked.reason == "You already have 2 of the ingredients.")
    }

    @Test func relaxedDishSaysItIsLonger() throws {
        let dish = try #require(catalogue.dish(id: "lentil_soup"))
        let ranked = try #require(DinnerRanker.rank([dish], input: input(TonightRequest(maxMinutes: 15))).first)
        #expect(ranked.reason.contains("longer than you asked"))
    }

    @Test func fallbackReasonIsTheTime() throws {
        let dish = try #require(catalogue.dish(id: "lentil_soup"))
        let ranked = try #require(DinnerRanker.rank([dish], input: input()).first)
        #expect(ranked.reason == "Ready in 40 minutes.")
    }

    @Test func surpriseAvoidsTheLastWeek() throws {
        let dishes = Array(catalogue.dishes.prefix(2))
        let history = [MealRecord(dishID: dishes[0].id, date: daysBefore(1), madeIt: true)]
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<20 {
            #expect(DinnerRanker.surprise(from: dishes, input: input(history: history), using: &generator)?.id == dishes[1].id)
        }
    }
}

@Suite struct SessionChecks {
    @Test func showsThreeDifferentMains() {
        let cards = session(Profile()).cards
        #expect(cards.count == 3)
        #expect(Set(cards.map(\.dish.main)).count == 3)
    }

    @Test func swapNeverRepeatsAndNeverBreaksSafety() {
        var picks = session(Profile(allergens: [.peanuts], diet: .vegetarian))
        var seen = Set(picks.cards.map(\.id))
        while let card = picks.cards.first, picks.swap(dishID: card.id) {
            let newest = picks.cards[0]
            #expect(seen.insert(newest.id).inserted)
            #expect(!catalogue.allergens(of: newest.dish).contains(.peanuts))
        }
        #expect(picks.cards.count == 3)
    }

    @Test func swapPrefersANewMain() throws {
        var picks = session(Profile())
        let card = picks.cards[1]
        let otherMains = Set(picks.cards.map(\.dish.main))
        let swapped = picks.swap(dishID: card.id)
        #expect(swapped)
        #expect(!otherMains.contains(picks.cards[1].dish.main))
    }
}

@Suite struct ShoppingChecks {
    @Test func staplesAndOnHandAreNotBought() throws {
        let dish = try #require(catalogue.dish(id: "sheet_pan_chicken"))
        let missing = Shopping.missing(from: dish, onHand: ["carrot"], catalogue: catalogue).map(\.id)
        #expect(missing == ["chicken_thigh", "potato", "paprika"])
    }

    @Test(arguments: [
        ("onion:1", 2, "1"), ("onion:1", 3, "1½"), ("onion:1", 1, "½"), ("chicken_thigh:500:g", 3, "750 g"),
        ("rice:150:g", 1, "75 g"), ("salt", 4, "to taste"), ("broth:1:cup", 4, "2 cups"), ("broth:1:cup", 2, "1 cup"),
        ("cumin:1:tsp", 1, "½ tsp"), ("peas:0.33:cup", 2, "½ cup"), ("garlic:2:clove", 1, "1 clove"),
    ])
    func quantityScales(encoded: String, people: Int, expected: String) {
        #expect(Shopping.quantityText(DishIngredient(encoded: encoded), people: people) == expected)
    }
}

@Suite struct HistoryChecks {
    @Test func secondChoiceTonightReplacesTheFirst() {
        var data = AppData()
        data.choose(dishID: "a", on: today, calendar: calendar)
        data.choose(dishID: "b", on: today, calendar: calendar)
        #expect(data.history.map(\.dishID) == ["b"])
        #expect(data.tonight(on: today, calendar: calendar)?.dishID == "b")
    }

    @Test func feedbackIsAskedOnLaterDaysOnly() throws {
        var data = AppData()
        data.choose(dishID: "a", on: today, calendar: calendar)
        #expect(data.pendingFeedback(on: today, calendar: calendar) == nil)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let record = try #require(data.pendingFeedback(on: tomorrow, calendar: calendar))
        data.recordFeedback(for: record, madeIt: true, wouldRepeat: false)
        #expect(data.pendingFeedback(on: tomorrow, calendar: calendar) == nil)
        #expect(data.history[0].wouldRepeat == false)
    }

    @Test func feedbackExpires() {
        var data = AppData()
        data.choose(dishID: "a", on: daysBefore(AppData.feedbackWindowDays + 1), calendar: calendar)
        #expect(data.pendingFeedback(on: today, calendar: calendar) == nil)
    }

    @Test func notMadeDiscardsRating() throws {
        var data = AppData()
        data.choose(dishID: "a", on: daysBefore(1), calendar: calendar)
        data.recordFeedback(for: data.history[0], madeIt: false, wouldRepeat: true)
        #expect(data.history[0].wouldRepeat == nil)
    }

    @Test func fileRoundTripsAndBadFileIsNewInstall() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "data.json")
        let file = DataFile(url: url)
        var data = AppData()
        data.profile = Profile(people: 3, allergens: [.sesame])
        try file.save(data)
        #expect(file.load() == data)
        try Data("not json".utf8).write(to: url)
        #expect(file.load().profile == nil)
    }
}

@Suite struct KitchenRecognitionChecks {
    @Test func everyMappedIdExistsAndIsNotAStaple() {
        let mapped = Set(KitchenRecognition.specificLabels.values)
            .union(KitchenRecognition.broadLabels.values.joined())
            .union(KitchenRecognition.packageNames.keys)
        for id in mapped {
            #expect(catalogue.ingredients[id]?.staple == false, "\(id)")
        }
    }

    @Test func everyPickableIngredientCanBeReadFromALabel() {
        for ingredient in catalogue.pickable where !ingredient.staple {
            #expect(KitchenRecognition.packageNames[ingredient.id] != nil, "\(ingredient.id)")
        }
    }

    @Test(arguments: [
        ("Coconut Milk", ["coconut_milk"]), ("ORGANIC EXTRA FIRM TOFU", ["tofu"]), ("Peanut Butter", ["peanut_butter"]),
        ("Diced Tomatoes", ["canned_tomato"]), ("Jalapeños", ["jalapeno"]), ("Potatoes", ["potato"]),
        ("Extra Virgin Olive Oil", []), ("Oat Milk", []), ("Milk Chocolate", []), ("Eggplant", ["eggplant"]),
        ("Contains milk and soy", []), ("wheat flour, sugar, palm oil, salt, milk, eggs, butter", []),
    ])
    func readsProductNames(line: String, expected: [String]) {
        #expect(KitchenRecognition.ingredients(onLabelLine: line) == Set(expected))
    }

    @Test func broadOrUnsureSightingsAreOnlyOffered() {
        let result = KitchenRecognition.findings(
            labels: [VisualLabel(identifier: "cheese", isConfident: true),
                     VisualLabel(identifier: "broccoli", isConfident: false),
                     VisualLabel(identifier: "tomato", isConfident: true),
                     VisualLabel(identifier: "bicycle", isConfident: true)],
            textLines: [], catalogue: catalogue)
        #expect(result.found == ["tomato"])
        #expect(result.possible == ["broccoli", "cheddar", "feta", "mozzarella", "parmesan"])
    }

    @Test func aConfirmedIngredientIsNotAlsoOffered() {
        let result = KitchenRecognition.findings(
            labels: [VisualLabel(identifier: "egg", isConfident: false)], textLines: ["Free range eggs"], catalogue: catalogue)
        #expect(result.found == ["egg"])
        #expect(result.possible.isEmpty)
    }
}

@Suite struct KitchenFreshnessChecks {
    private func data(scanned days: Int?) -> AppData {
        var value = AppData()
        value.onHand = ["egg"]
        value.kitchenUpdated = days.map(daysBefore)
        return value
    }

    @Test func recentListIsUsed() {
        #expect(data(scanned: 2).kitchen(on: today, calendar: calendar) == ["egg"])
    }

    @Test func oldOrUndatedListIsIgnored() {
        #expect(data(scanned: 3).kitchen(on: today, calendar: calendar).isEmpty)
        #expect(data(scanned: nil).kitchen(on: today, calendar: calendar).isEmpty)
    }

    @Test func fileSavedBeforeDatesStillLoads() throws {
        let old = #"{"history":[],"onHand":["egg"],"remindersOn":false}"#
        let decoded = try JSONDecoder().decode(AppData.self, from: Data(old.utf8))
        #expect(decoded.onHand == ["egg"] && decoded.kitchenUpdated == nil)
    }
}

@Suite struct CookFromKitchenChecks {
    private func kitchen(for dish: Dish) -> Set<String> {
        Set(dish.ingredients.map(\.id).filter { catalogue.ingredients[$0]?.staple == false })
    }

    private func kitchenSession(_ onHand: Set<String>, profile: Profile = Profile(), craving: Craving? = nil) -> PickSession {
        let request = TonightRequest(craving: craving, onHand: onHand)
        let filtered = DinnerFilter.apply(catalogue: catalogue, profile: profile, request: request)
        return PickSession(ranked: DinnerRanker.rank(filtered.dishes, input: input(request)),
                           timeWasRelaxed: filtered.timeWasRelaxed, usedKitchen: true)
    }

    @Test func aDinnerYouCanCookComesFirstEvenAgainstACraving() throws {
        for dish in catalogue.dishes {
            let other = Craving.allCases.first { !dish.cravings.contains($0) }
            let first = try #require(kitchenSession(kitchen(for: dish), craving: other).cards.first)
            #expect(first.missing.isEmpty, "\(dish.id) -> \(first.id)")
        }
    }

    @Test func cookableDinnerSaysSoAndNeedsNoShopping() throws {
        let dish = try #require(catalogue.dish(id: "chicken_tacos"))
        let session = kitchenSession(kitchen(for: dish))
        let card = try #require(session.cards.first { $0.id == dish.id })
        #expect(card.reason == "You have everything for this.")
        #expect(!session.needsShopping)
    }

    @Test func aSparseKitchenAdmitsItNeedsShopping() {
        #expect(kitchenSession(["honey"]).needsShopping)
    }

    @Test func namesWhatIsMissingWhenItIsLittle() throws {
        let dish = try #require(catalogue.dish(id: "chicken_tacos"))
        var onHand = kitchen(for: dish)
        let gone = try #require(onHand.sorted().first)
        onHand.remove(gone)
        let ranked = DinnerRanker.rank([dish], input: input(TonightRequest(onHand: onHand)))[0]
        let name = try #require(catalogue.ingredients[gone]?.name.lowercased())
        #expect(ranked.reason == "You'd only need \(name).")
    }

    @Test func aPhotographedAllergenStaysExcluded() throws {
        let dish = try #require(catalogue.dishes.first { catalogue.allergens(of: $0).contains(.peanuts) })
        let session = kitchenSession(kitchen(for: dish), profile: Profile(allergens: [.peanuts]))
        #expect(!session.cards.contains { $0.id == dish.id })
    }

    @Test func swapStaysWithCookableDinnersWhileAnyRemain() throws {
        let everything = Set(catalogue.pickable.map(\.id))
        var session = kitchenSession(everything)
        let card = try #require(session.cards.first)
        #expect(session.swap(dishID: card.id) == true)
        #expect(session.cards.allSatisfy { $0.missing.isEmpty })
    }
}
