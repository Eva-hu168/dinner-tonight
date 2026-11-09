import DinnerCore
import SwiftUI

struct PicksView: View {
    @Environment(AppModel.self) private var model
    @State var session: PickSession
    @Binding var path: [Route]
    @State private var outOfOptions = false

    var body: some View {
        Group {
            if session.cards.isEmpty {
                ContentUnavailableView(
                    "Nothing fits right now",
                    systemImage: "fork.knife",
                    description: Text("No dinner in the collection is free of your allergens and foods to avoid. Your preferences can be changed from the home screen.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        if session.timeWasRelaxed {
                            Label("Nothing fits that time limit, so these are the closest.", systemImage: "clock")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        }
                        if session.needsShopping {
                            Label("Nothing can be cooked from just your kitchen, so these need the fewest extras.", systemImage: "basket")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        }
                        ForEach(session.cards) { card in
                            pickCard(card)
                                .transition(.opacity)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.page)
        .navigationTitle("Tonight's three")
        .navigationBarTitleDisplayMode(.inline)
        .alert("That's everything that fits tonight", isPresented: $outOfOptions) {
            Button("OK", role: .cancel) {}
        }
    }

    private func pickCard(_ card: RankedDish) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: Route.recipe(dishID: card.id, reason: card.reason)) {
                HStack(alignment: .top, spacing: 14) {
                    Emoji(card.dish.emoji, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.dish.name).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        Text(card.dish.summary).font(.subheadline).foregroundStyle(.secondary)
                        Text(card.reason).font(.subheadline).foregroundStyle(Color.brand).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary).padding(.top, 4)
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 10) {
                Button("Swap") {
                    withAnimation { outOfOptions = !session.swap(dishID: card.id) }
                }
                .buttonStyle(SecondaryButtonStyle())
                Button("Choose") {
                    model.choose(card.dish)
                    path.append(.recipe(dishID: card.id, reason: card.reason))
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
    }
}
