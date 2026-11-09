import DinnerCore
import PhotosUI
import SwiftUI

/// Photograph the ingredients, then correct what the phone made of them.
struct KitchenScanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showingCamera = false
    @State private var showingAdd = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var scanning = false
    @State private var message: String?
    /// Stay on screen after being unticked, so a mistaken tap can be undone.
    @State private var shown: Set<String> = []
    @State private var offered: Set<String> = []

    private var selection: Binding<Set<String>> {
        Binding(get: { model.kitchen }, set: { model.setKitchen($0) })
    }

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    private func ingredients(_ ids: Set<String>) -> [Ingredient] {
        ids.compactMap { model.catalogue.ingredients[$0] }.sorted { $0.name < $1.name }
    }

    private var listed: [Ingredient] { ingredients(shown.union(model.kitchen).subtracting(offered)) }
    private var suggested: [Ingredient] { ingredients(offered.subtracting(model.kitchen)) }
    private var hasResults: Bool { !listed.isEmpty || !suggested.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !hasResults && !scanning { intro }
                    if scanning {
                        ProgressView("Looking at your photo…")
                            .frame(maxWidth: .infinity, minHeight: 90)
                    }
                    if let message {
                        Label(message, systemImage: "camera.metering.unknown")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }
                    if hasResults { results }
                    photoButtons
                    Button("Add something by hand") { showingAdd = true }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding()
            }
            .background(Color.page)
            .navigationTitle("Your kitchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        selection.wrappedValue = []
                        shown = []
                        offered = []
                        message = nil
                    }
                    .disabled(!hasResults)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { photo in scan(photo) }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingAdd) { addSheet }
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                libraryItem = nil
                Task {
                    if let photo = try? await item.loadTransferable(type: Data.self) {
                        scan(photo)
                    } else {
                        message = "That photo couldn't be opened. Try another one."
                    }
                }
            }
        }
    }

    private var intro: some View {
        VStack(spacing: 10) {
            Emoji("📷", size: 56)
            Text("Show me what you've got").font(.title3.bold())
            Text("Photograph your ingredients and you'll get dinners you can cook without going shopping. Turn labels toward the camera. Fridge and cupboard can be separate photos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Photos stay on this iPhone and aren't saved.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !listed.isEmpty {
                chipGroup("In your kitchen", items: listed)
            }
            if !suggested.isEmpty {
                chipGroup("Do you have any of these?", items: suggested)
            }
            Text("Photos can miss things or get them wrong, so tap to fix this list. Dinners are matched to what's ticked.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func chipGroup(_ title: String, items: [Ingredient]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            FlowLayout {
                ForEach(items) { item in
                    Chip(title: item.name, isOn: selection.wrappedValue.contains(item.id)) { toggle(item.id) }
                }
            }
        }
    }

    @ViewBuilder private var photoButtons: some View {
        let isFirst = !hasResults
        if cameraAvailable {
            Button(isFirst ? "Take a photo" : "Take another photo") { showingCamera = true }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(scanning)
        }
        PhotosPicker(selection: $libraryItem, matching: .images) {
            Text(isFirst ? "Choose a photo" : "Add from your photos").frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(scanning)
    }

    private var addSheet: some View {
        NavigationStack {
            IngredientPicker(selection: Binding(
                get: { model.kitchen },
                set: { value in
                    shown.formUnion(value)
                    offered.subtract(value)
                    model.setKitchen(value)
                }
            ))
            .navigationTitle("Add ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingAdd = false }
                }
            }
        }
    }

    private func toggle(_ id: String) {
        var items = model.kitchen
        if items.remove(id) == nil {
            items.insert(id)
            offered.remove(id)
        }
        shown.insert(id)
        model.setKitchen(items)
    }

    private func scan(_ photo: Data) {
        scanning = true
        message = nil
        Task {
            let findings = await KitchenScanner.scan(photo, catalogue: model.catalogue)
            scanning = false
            guard let findings else {
                message = "That photo couldn't be read. Try another one."
                return
            }
            if findings.isEmpty {
                message = "No ingredients spotted in that photo. Try moving closer, or add them by hand."
                return
            }
            model.setKitchen(model.kitchen.union(findings.found))
            shown.formUnion(findings.found)
            offered.subtract(findings.found)
            // Something the user has already answered about is not asked again.
            offered.formUnion(findings.possible.subtracting(shown))
        }
    }
}

/// The system camera. It handles permission and the denied state itself.
struct CameraPicker: UIViewControllerRepresentable {
    let onPhoto: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let photo = (info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.85) {
                parent.onPhoto(photo)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
