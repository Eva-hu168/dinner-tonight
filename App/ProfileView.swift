import DinnerCore
import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingErase = false
    @State private var remindersDenied = false

    private var profile: Binding<Profile> {
        Binding(get: { model.profile }, set: { value in model.update { $0.profile = value } })
    }

    private var reminders: Binding<Bool> {
        Binding(get: { model.data.remindersOn }, set: { isOn in
            guard isOn else {
                Reminders.cancel()
                model.update { $0.remindersOn = false }
                return
            }
            Task {
                let granted = await Reminders.requestPermission()
                remindersDenied = !granted
                model.update { $0.remindersOn = granted }
            }
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Household") {
                    Stepper("^[\(model.profile.people) person](inflect: true)", value: profile.people, in: 1...8)
                    Picker("Diet", selection: profile.diet) {
                        ForEach(Diet.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Usual cooking time", selection: profile.usualMinutes) {
                        ForEach(TimeOption.all) { Text($0.label).tag($0.minutes) }
                    }
                }
                Section {
                    ForEach(Allergen.allCases) { allergen in
                        Toggle(allergen.label, isOn: Binding(
                            get: { model.profile.allergens.contains(allergen) },
                            set: { isOn in
                                if isOn { profile.wrappedValue.allergens.insert(allergen) }
                                else { profile.wrappedValue.allergens.remove(allergen) }
                            }
                        ))
                    }
                } header: {
                    Text("Allergies")
                } footer: {
                    Text("Dinners with these are never shown. Products vary, so always check labels.")
                }
                Section {
                    NavigationLink {
                        IngredientPicker(selection: profile.avoided)
                            .navigationTitle("Foods to avoid")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        LabeledContent("Foods to avoid", value: "\(model.profile.avoided.count)")
                    }
                }
                Section {
                    Toggle("Next-day reminder", isOn: reminders)
                } footer: {
                    Text(remindersDenied
                         ? "Notifications are off for this app. You can turn them on in the Settings app."
                         : "A morning nudge to say how dinner went, so the picks get better.")
                }
                Section {
                    Button("Erase everything", role: .destructive) { confirmingErase = true }
                } footer: {
                    Text("Your preferences and history stay on this iPhone.")
                }
            }
            .navigationTitle("Your preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Erase your preferences and history?", isPresented: $confirmingErase, titleVisibility: .visible) {
                Button("Erase everything", role: .destructive) {
                    model.eraseEverything()
                    dismiss()
                }
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}
