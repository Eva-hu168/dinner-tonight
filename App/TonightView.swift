import DinnerCore
import SwiftUI

struct TonightView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [Route]
    @State private var minutes: Int?
    @State private var effort: Effort?
    @State private var craving: Craving?
    @State private var loaded = false
    @State private var showingKitchen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                group("How much time tonight?") {
                    ForEach(TimeOption.all) { option in
                        Chip(title: option.label, isOn: minutes == option.minutes) { minutes = option.minutes }
                    }
                }
                group("How much effort?") {
                    ForEach(Effort.allCases) { level in
                        Chip(title: level.askLabel, isOn: effort == level) { effort = effort == level ? nil : level }
                    }
                }
                group("In the mood for?") {
                    ForEach(Craving.allCases) { option in
                        Chip(title: option.label, isOn: craving == option) { craving = craving == option ? nil : option }
                    }
                }
                Button { showingKitchen = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill").foregroundStyle(Color.brand)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Photograph your ingredients")
                            Text(kitchenSummary).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .padding()
                    .frame(minHeight: 54)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(Color.page)
        .navigationTitle("Tonight")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Show me dinners") {
                let request = TonightRequest(maxMinutes: minutes, maxEffort: effort, craving: craving, onHand: model.kitchen)
                path.append(.picks(model.picks(for: request)))
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            .background(.bar)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            minutes = model.profile.usualMinutes
        }
        .sheet(isPresented: $showingKitchen) { KitchenScanView() }
    }

    private var kitchenSummary: String {
        let count = model.kitchen.count
        return count == 0 ? "Get dinners you can cook without shopping" : "\(count) ingredient\(count == 1 ? "" : "s") ready to use"
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            FlowLayout { content() }
        }
    }
}
