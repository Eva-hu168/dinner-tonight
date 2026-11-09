import CoreText
import DinnerCore
import SwiftUI

/// An emoji at a fixed size. On an iPhone this is plain text.
struct Emoji: View {
    let text: String
    let size: CGFloat

    init(_ text: String, size: CGFloat) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Text(verbatim: text).font(font).accessibilityHidden(true)
    }

    private var font: Font {
        #if targetEnvironment(simulator)
        if let descriptor = SimulatorEmojiFont.descriptor {
            return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
        }
        #endif
        return .system(size: size)
    }
}

#if targetEnvironment(simulator)
/// COMPAT: some Simulator runtimes ship without an emoji font, so every emoji draws as a box.
/// The Mac's own copy is readable from the Simulator.
enum SimulatorEmojiFont {
    nonisolated(unsafe) static let descriptor: CTFontDescriptor? = {
        let url = URL(fileURLWithPath: "/System/Library/Fonts/Apple Color Emoji.ttc")
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return nil }
        return (CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor])?.first
    }()
}
#endif

extension Color {
    static let brand = Color(red: 0.75, green: 0.29, blue: 0.13)
    static let page = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
}

/// Lays children left to right and wraps to a new row when the width runs out.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    private func rows(_ subviews: Subviews, width: CGFloat) -> [(indices: [Int], height: CGFloat)] {
        var rows: [(indices: [Int], height: CGFloat)] = []
        var used: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if rows.isEmpty || used + size.width > width {
                rows.append(([], 0))
                used = 0
            }
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            used += size.width + spacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .greatestFiniteMagnitude
        let rows = rows(subviews, width: width)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }
}

struct Chip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background(isOn ? Color.brand : Color.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.secondary.opacity(isOn ? 0 : 0.25)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(Color.brand.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(Color.brand)
            .background(Color.brand.opacity(configuration.isPressed ? 0.2 : 0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text).font(.headline)
    }
}

/// Search and tap chips over the catalogue's ingredients, grouped by aisle.
struct IngredientPicker: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: Set<String>
    @State private var query = ""

    private var groups: [(name: String, items: [Ingredient])] {
        let matches = model.catalogue.pickable.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
        return ["Produce", "Protein", "Dairy", "Grains", "Pantry"].compactMap { name in
            let items = matches.filter { $0.group == name }
            return items.isEmpty ? nil : (name, items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groups, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: group.name)
                        FlowLayout {
                            ForEach(group.items) { item in
                                Chip(title: item.name, isOn: selection.contains(item.id)) {
                                    if selection.remove(item.id) == nil { selection.insert(item.id) }
                                }
                            }
                        }
                    }
                }
                if groups.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .padding()
        }
        .background(Color.page)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search ingredients")
    }
}

extension Dish {
    var summary: String { "\(minutes) min · \(effort.label) · \(cuisine)" }
}
