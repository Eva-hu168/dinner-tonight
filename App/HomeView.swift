import DinnerCore
import SwiftUI

enum Route: Hashable {
    case tonight
    case picks(PickSession)
    case recipe(dishID: String, reason: String?)
}

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [Route] = []
    @State private var showingProfile = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("What's for dinner?")
                        .font(.largeTitle.bold())
                        .padding(.top, 8)
                    if let pending = model.pendingFeedback {
                        FeedbackCard(record: pending.record, dish: pending.dish)
                            .id(pending.record.date)
                    }
                    if let dish = model.tonight {
                        tonightCard(dish)
                    }
                    decideCard
                }
                .padding()
            }
            .background(Color.page)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Your preferences", systemImage: "slider.horizontal.3") { showingProfile = true }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .tonight:
                    TonightView(path: $path)
                case .picks(let session):
                    PicksView(session: session, path: $path)
                case .recipe(let dishID, let reason):
                    if let dish = model.catalogue.dish(id: dishID) {
                        RecipeView(dish: dish, reason: reason, path: $path)
                    }
                }
            }
            .sheet(isPresented: $showingProfile) { ProfileView() }
        }
    }

    private func tonightCard(_ dish: Dish) -> some View {
        NavigationLink(value: Route.recipe(dishID: dish.id, reason: nil)) {
            HStack(spacing: 14) {
                Emoji(dish.emoji, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tonight").font(.caption.weight(.semibold)).foregroundStyle(Color.brand)
                    Text(dish.name).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                    Text(dish.summary).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var decideCard: some View {
        VStack(spacing: 12) {
            Emoji("🍽️", size: 64)
            Text(model.tonight == nil ? "Three good options, about thirty seconds." : "Changed your mind?")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Help me decide") { path.append(.tonight) }
                .buttonStyle(PrimaryButtonStyle())
            Button("Surprise me") {
                if let dish = model.surprise() {
                    path.append(.recipe(dishID: dish.id, reason: "A surprise that fits your household."))
                } else {
                    path.append(.picks(model.picks(for: TonightRequest())))
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(20)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 22))
    }
}

/// Asks about an earlier dinner, one question at a time.
struct FeedbackCard: View {
    @Environment(AppModel.self) private var model
    let record: MealRecord
    let dish: Dish
    @State private var askingRepeat = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(askingRepeat ? "Would you have it again?" : "Did you make \(dish.name)?")
                .font(.headline)
            HStack(spacing: 10) {
                Button("Yes") { answer(true) }
                    .buttonStyle(PrimaryButtonStyle())
                Button(askingRepeat ? "Not again" : "No") { answer(false) }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .background(Color.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func answer(_ value: Bool) {
        if askingRepeat {
            model.update { $0.recordFeedback(for: record, madeIt: true, wouldRepeat: value) }
        } else if value {
            askingRepeat = true
        } else {
            model.update { $0.recordFeedback(for: record, madeIt: false, wouldRepeat: nil) }
        }
    }
}
