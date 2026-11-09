import Foundation

/// Everything the app remembers. It stays on this iPhone.
public struct AppData: Codable, Sendable, Hashable {
    public static let maxHistory = 365
    /// A dinner older than this no longer gets a "did you make it?" question.
    public static let feedbackWindowDays = 3
    public static let kitchenFreshDays = 2

    public var profile: Profile?
    public var history: [MealRecord] = []
    public var onHand: Set<String> = []
    /// Nil for a list saved before kitchens had dates; such a list counts as out of date.
    public var kitchenUpdated: Date?
    public var remindersOn = false

    public init() {}

    /// What is at home, if the list is recent. Food gets eaten, so an old photo must not promise a dinner.
    public func kitchen(on date: Date, calendar: Calendar = .current) -> Set<String> {
        guard let kitchenUpdated else { return [] }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: kitchenUpdated),
                                           to: calendar.startOfDay(for: date)).day ?? .max
        return (0...Self.kitchenFreshDays).contains(days) ? onHand : []
    }

    public mutating func setKitchen(_ items: Set<String>, on date: Date) {
        onHand = items
        kitchenUpdated = date
    }

    /// At most one dinner per day: choosing again tonight replaces tonight's choice.
    public mutating func choose(dishID: String, on date: Date, calendar: Calendar = .current) {
        history.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
        history.append(MealRecord(dishID: dishID, date: date))
        history.sort { $0.date < $1.date }
        if history.count > Self.maxHistory { history.removeFirst(history.count - Self.maxHistory) }
    }

    public func tonight(on date: Date, calendar: Calendar = .current) -> MealRecord? {
        history.last { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// The newest unanswered dinner from an earlier day that is still recent enough to ask about.
    public func pendingFeedback(on date: Date, calendar: Calendar = .current) -> MealRecord? {
        history.last { record in
            guard record.madeIt == nil else { return false }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: record.date),
                                               to: calendar.startOfDay(for: date)).day ?? 0
            return (1...Self.feedbackWindowDays).contains(days)
        }
    }

    public mutating func recordFeedback(for record: MealRecord, madeIt: Bool, wouldRepeat: Bool?) {
        guard let index = history.firstIndex(of: record) else { return }
        history[index].madeIt = madeIt
        history[index].wouldRepeat = madeIt ? wouldRepeat : nil
    }
}

/// A missing or unreadable file reads as a new install, which sends the user back through the allergy questions
/// rather than guessing that they have none.
public struct DataFile: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() -> AppData {
        guard let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(AppData.self, from: data)
        else { return AppData() }
        return decoded
    }

    public func save(_ data: AppData) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(data).write(to: url, options: [.atomic, .completeFileProtection])
    }
}
