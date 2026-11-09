import DinnerCore
import Foundation
import Observation

@MainActor @Observable
final class AppModel {
    let catalogue: Catalogue
    private(set) var data: AppData
    @ObservationIgnored private let file: DataFile

    init() {
        do {
            catalogue = try Catalogue.bundled()
        } catch {
            // INVARIANT: the bundled catalogue is checked by DinnerCoreTests; without it nothing can be shown safely.
            fatalError("Bundled catalogue failed to load: \(error)")
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = DataFile(url: support.appending(path: "dinner-tonight.json"))
        data = file.load()
    }

    /// The only path that changes the data, so the file and the screen cannot drift apart.
    func update(_ change: (inout AppData) -> Void) {
        change(&data)
        // A failed save costs at most this session's changes; the next launch reads the last good file.
        try? file.save(data)
    }

    var profile: Profile { data.profile ?? Profile() }

    private func rankingInput(_ request: TonightRequest) -> RankingInput {
        RankingInput(catalogue: catalogue, request: request, history: data.history, today: Date())
    }

    func picks(for request: TonightRequest) -> PickSession {
        let filtered = DinnerFilter.apply(catalogue: catalogue, profile: profile, request: request)
        return PickSession(ranked: DinnerRanker.rank(filtered.dishes, input: rankingInput(request)),
                           timeWasRelaxed: filtered.timeWasRelaxed,
                           usedKitchen: !request.onHand.isEmpty)
    }

    var kitchen: Set<String> { data.kitchen(on: Date()) }

    func setKitchen(_ items: Set<String>) {
        update { $0.setKitchen(items, on: Date()) }
    }

    func surprise() -> Dish? {
        let dishes = DinnerFilter.safeDishes(in: catalogue, for: profile)
        var generator = SystemRandomNumberGenerator()
        return DinnerRanker.surprise(from: dishes, input: rankingInput(TonightRequest()), using: &generator)
    }

    func choose(_ dish: Dish) {
        update { $0.choose(dishID: dish.id, on: Date()) }
        if data.remindersOn { Reminders.scheduleFeedback(dishName: dish.name) }
    }

    var tonight: Dish? {
        data.tonight(on: Date()).flatMap { catalogue.dish(id: $0.dishID) }
    }

    var pendingFeedback: (record: MealRecord, dish: Dish)? {
        guard let record = data.pendingFeedback(on: Date()), let dish = catalogue.dish(id: record.dishID) else { return nil }
        return (record, dish)
    }

    func eraseEverything() {
        Reminders.cancel()
        update { $0 = AppData() }
    }
}
