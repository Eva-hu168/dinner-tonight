import DinnerCore
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var profile = Profile()
    @State private var noAllergies = false

    private let lastStep = 3

    /// Allergies need an explicit answer: an empty selection must never be read as "none".
    private var canContinue: Bool {
        step != 1 || noAllergies || !profile.allergens.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: Double(lastStep + 1))
                    .padding(.horizontal)
                    .padding(.top, 8)
                Group {
                    switch step {
                    case 0: household
                    case 1: allergies
                    case 2: avoid
                    default: cookingTime
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Button(step == lastStep ? "Start deciding" : "Continue") {
                    if step == lastStep { finish() } else { step += 1 }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.4)
                .padding()
            }
            .background(Color.page)
            .toolbar {
                if step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { step -= 1 }
                    }
                }
            }
        }
    }

    private func finish() {
        let finished = profile
        model.update { $0.profile = finished }
    }

    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.largeTitle.bold())
            Text(detail).foregroundStyle(.secondary)
        }
    }

    private var household: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heading("Let's get dinner sorted", "A few questions, once. Then deciding takes seconds.")
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "How many people are eating?")
                    Stepper("^[\(profile.people) person](inflect: true)", value: $profile.people, in: 1...8)
                        .padding()
                        .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "How does your household eat?")
                    FlowLayout {
                        ForEach(Diet.allCases) { diet in
                            Chip(title: diet.label, isOn: profile.diet == diet) { profile.diet = diet }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var allergies: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heading("Any food allergies?", "Include everyone who's eating. Dinners with these are never shown.")
                FlowLayout {
                    ForEach(Allergen.allCases) { allergen in
                        Chip(title: allergen.label, isOn: profile.allergens.contains(allergen)) {
                            noAllergies = false
                            if profile.allergens.remove(allergen) == nil { profile.allergens.insert(allergen) }
                        }
                    }
                }
                Chip(title: "No allergies", isOn: noAllergies) {
                    noAllergies.toggle()
                    if noAllergies { profile.allergens = [] }
                }
                Text("Something else? Add it on the next screen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private var avoid: some View {
        VStack(alignment: .leading, spacing: 8) {
            heading("Anything to avoid?", "Tap foods you won't eat. Skip this if you eat it all.")
                .padding(.horizontal)
            IngredientPicker(selection: $profile.avoided)
        }
    }

    private var cookingTime: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heading("How long do you usually cook?", "You can change this any night.")
                FlowLayout {
                    ForEach(TimeOption.all) { option in
                        Chip(title: option.label, isOn: profile.usualMinutes == option.minutes) {
                            profile.usualMinutes = option.minutes
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct TimeOption: Identifiable {
    let minutes: Int?
    var id: Int { minutes ?? 0 }
    var label: String { minutes.map { "\($0) min" } ?? "No limit" }

    static let all = [15, 30, 45].map { TimeOption(minutes: $0) } + [TimeOption(minutes: nil)]
}
