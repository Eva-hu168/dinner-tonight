import Foundation

/// One thing the image classifier reported for a photo.
public struct VisualLabel: Sendable, Hashable {
    public let identifier: String
    /// True when the classifier is sure enough to tick the ingredient without asking.
    public let isConfident: Bool

    public init(identifier: String, isConfident: Bool) {
        self.identifier = identifier
        self.isConfident = isConfident
    }
}

public struct KitchenFindings: Sendable, Hashable {
    /// Ingredient ids to tick straight away.
    public var found: Set<String>
    /// Ingredient ids to offer unticked: a vague or unsure sighting is a question, not a fact.
    public var possible: Set<String>

    public init(found: Set<String> = [], possible: Set<String> = []) {
        self.found = found
        self.possible = possible.subtracting(found)
    }

    public var isEmpty: Bool { found.isEmpty && possible.isEmpty }
}

/// Turns what the phone saw into catalogue ingredients. A wrong result only misorders dinners and is corrected
/// on the review screen; allergens and diet are decided by `DinnerFilter` and never read this.
public enum KitchenRecognition {
    /// Classifier labels that name one catalogue ingredient.
    static let specificLabels: [String: String] = [
        "avocado": "avocado", "bacon": "bacon", "bell_pepper": "bell_pepper", "bread": "bread", "white_bread": "bread",
        "broccoli": "broccoli", "butter": "butter", "carrot": "carrot", "cashew": "cashews", "celery": "celery",
        "cilantro": "cilantro", "corn": "corn", "cucumber": "cucumber", "egg": "egg", "eggplant": "eggplant",
        "garlic": "garlic", "green_beans": "green_beans", "honey": "honey", "jalapeno": "jalapeno", "lemon": "lemon",
        "lettuce": "lettuce", "lime": "lime", "mushroom": "mushroom", "onion": "onion", "pasta": "pasta",
        "pea": "peas", "peanut": "peanuts", "potato": "potato", "quinoa": "quinoa", "rice": "rice", "salmon": "salmon",
        "sausage": "sausage", "spaghetti": "pasta", "spinach": "spinach", "tomato": "tomato", "yogurt": "yogurt",
        "zucchini": "zucchini",
    ]

    /// Classifier labels too broad to name one ingredient, so they are only ever offered.
    static let broadLabels: [String: [String]] = [
        "bean": ["black_beans", "chickpeas", "kidney_beans", "white_beans"],
        "beef": ["beef_strips", "ground_beef"],
        "cheese": ["cheddar", "feta", "mozzarella", "parmesan"],
        "fish": ["salmon", "white_fish"],
        "grain": ["couscous", "quinoa", "rice"],
        "herb": ["basil", "cilantro", "parsley"],
        "meat": ["beef_strips", "ground_beef", "pork_chop"],
        "pepper_veggie": ["bell_pepper", "jalapeno"],
        "poultry": ["chicken_breast", "chicken_thigh", "ground_turkey"],
        "ramen": ["ramen"],
        "seafood": ["shrimp", "white_fish"],
        "shellfish": ["shrimp"],
        "tortilla": ["corn_tortilla", "flour_tortilla"],
        "tuna": ["tuna_can"],
    ]

    /// Words on packaging for each ingredient, singular; a trailing "s" or "es" also matches.
    static let packageNames: [String: [String]] = [
        "chicken_thigh": ["chicken thigh"], "chicken_breast": ["chicken breast"], "ground_turkey": ["ground turkey"],
        "ground_beef": ["ground beef", "beef mince"], "beef_strips": ["beef strip", "stir fry beef"],
        "pork_chop": ["pork chop"], "bacon": ["bacon"], "sausage": ["sausage"], "salmon": ["salmon"],
        "white_fish": ["white fish", "cod", "tilapia", "haddock"], "tuna_can": ["tuna"], "shrimp": ["shrimp", "prawn"],
        "egg": ["egg"], "tofu": ["tofu"], "chickpeas": ["chickpea", "garbanzo"], "black_beans": ["black bean"],
        "white_beans": ["white bean", "cannellini"], "kidney_beans": ["kidney bean"], "lentils": ["lentil"],
        "butter": ["butter"], "cheddar": ["cheddar"], "mozzarella": ["mozzarella"],
        "parmesan": ["parmesan", "parmigiano"], "feta": ["feta"], "yogurt": ["yogurt", "yoghurt"],
        "sour_cream": ["sour cream"], "milk": ["milk"], "onion": ["onion"], "garlic": ["garlic"], "ginger": ["ginger"],
        "tomato": ["tomato"], "cherry_tomato": ["cherry tomato"], "bell_pepper": ["bell pepper"], "carrot": ["carrot"],
        "celery": ["celery"], "broccoli": ["broccoli"], "spinach": ["spinach"], "kale": ["kale"],
        "zucchini": ["zucchini", "courgette"], "eggplant": ["eggplant", "aubergine"], "mushroom": ["mushroom"],
        "potato": ["potato"], "sweet_potato": ["sweet potato"], "cucumber": ["cucumber"], "lettuce": ["lettuce"],
        "cabbage": ["cabbage"], "green_onion": ["green onion", "scallion"], "green_beans": ["green bean"],
        "corn": ["corn", "sweetcorn"], "peas": ["pea"], "avocado": ["avocado"], "jalapeno": ["jalapeno"],
        "lemon": ["lemon"], "lime": ["lime"], "cilantro": ["cilantro"], "basil": ["basil"], "parsley": ["parsley"],
        "rice": ["rice"], "arborio_rice": ["arborio", "risotto rice"], "quinoa": ["quinoa"], "couscous": ["couscous"],
        "pasta": ["pasta", "spaghetti", "penne", "fusilli", "rigatoni", "linguine"], "rice_noodles": ["rice noodle"],
        "ramen": ["ramen"], "flour": ["flour"], "flour_tortilla": ["flour tortilla"], "corn_tortilla": ["corn tortilla"],
        "bread": ["bread"], "burger_bun": ["burger bun", "hamburger bun"],
        "breadcrumbs": ["breadcrumb", "bread crumb", "panko"],
        "canned_tomato": ["canned tomato", "diced tomato", "crushed tomato", "chopped tomato"],
        "tomato_paste": ["tomato paste", "tomato puree"], "tomato_soup": ["tomato soup"],
        "coconut_milk": ["coconut milk"], "chicken_broth": ["chicken broth", "chicken stock"],
        "vegetable_broth": ["vegetable broth", "vegetable stock"], "soy_sauce": ["soy sauce"],
        "fish_sauce": ["fish sauce"], "oyster_sauce": ["oyster sauce"], "gochujang": ["gochujang"], "miso": ["miso"],
        "red_curry_paste": ["red curry"], "sesame_oil": ["sesame oil"], "sesame_seeds": ["sesame seed"],
        "peanut_butter": ["peanut butter"], "peanuts": ["peanut"], "cashews": ["cashew"], "pesto": ["pesto"],
        "curry_powder": ["curry powder"], "cumin": ["cumin"], "paprika": ["paprika"],
        "chili_flakes": ["chili flake", "red pepper flake"], "chili_powder": ["chili powder"], "oregano": ["oregano"],
        "honey": ["honey"], "vinegar": ["vinegar"], "cornstarch": ["cornstarch", "corn starch"],
        "mayo": ["mayo", "mayonnaise"], "salsa": ["salsa"], "olives": ["olive"],
    ]

    /// Products whose names contain an ingredient word but are not that ingredient.
    static let lookalikes = [
        "olive oil", "vegetable oil", "milk chocolate", "almond milk", "oat milk", "soy milk", "rice cake",
        "rice krispie", "rice vinegar", "corn flake", "cream cheese", "butter cookie", "peanut butter cup",
        "egg noodle", "garlic powder", "onion powder", "ginger ale",
    ]

    /// Longest first, so "coconut milk" is taken before "milk" can match inside it.
    private static let phrases: [(text: String, id: String?)] = {
        let named = packageNames.flatMap { id, names in names.map { (text: $0, id: Optional(id)) } }
        let blocked = lookalikes.map { (text: $0, id: String?.none) }
        return (named + blocked).sorted { ($0.text.count, $0.text) > ($1.text.count, $1.text) }
    }()

    /// A product name is short; a longer line is an ingredients panel, where every word would match.
    private static let maxWordsOnLabel = 6

    /// Ingredients named by one line of text read from packaging.
    static func ingredients(onLabelLine line: String) -> Set<String> {
        let words = line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
            .split { !$0.isLetter }.map(String.init)
        guard !words.isEmpty, words.count <= maxWordsOnLabel,
              !words.contains(where: { $0.hasPrefix("contain") || $0.hasPrefix("ingredient") }) else { return [] }
        var remaining = " " + words.joined(separator: " ") + " "
        var found: Set<String> = []
        for phrase in phrases {
            for form in [phrase.text, phrase.text + "s", phrase.text + "es"] where remaining.contains(" \(form) ") {
                remaining = remaining.replacingOccurrences(of: " \(form) ", with: "  ")
                if let id = phrase.id { found.insert(id) }
            }
        }
        return found
    }

    public static func findings(labels: [VisualLabel], textLines: [String], catalogue: Catalogue) -> KitchenFindings {
        var found = Set(textLines.flatMap(ingredients(onLabelLine:)))
        var possible: Set<String> = []
        for label in labels {
            if let id = specificLabels[label.identifier] {
                if label.isConfident { found.insert(id) } else { possible.insert(id) }
            } else if let ids = broadLabels[label.identifier] {
                possible.formUnion(ids)
            }
        }
        return KitchenFindings(found: found.filter { catalogue.ingredients[$0] != nil },
                               possible: possible.filter { catalogue.ingredients[$0] != nil })
    }

    /// The answers the on-device language model may give: one name per pickable ingredient.
    /// INVARIANT: pickable names are unique, so each answer maps back to exactly one id.
    public static func modelChoices(in catalogue: Catalogue) -> [String] {
        catalogue.pickable.map(\.name)
    }

    /// `seen` and `unsure` are names from `modelChoices`; anything else is dropped. Label text is read as for
    /// the classifier, since a product name settles what the model may only guess.
    public static func findings(seen: [String], unsure: [String], textLines: [String],
                                catalogue: Catalogue) -> KitchenFindings {
        let ids = Dictionary(catalogue.pickable.map { ($0.name, $0.id) }, uniquingKeysWith: { first, _ in first })
        let found = Set(textLines.flatMap(ingredients(onLabelLine:))).union(seen.compactMap { ids[$0] })
        return KitchenFindings(found: found.filter { catalogue.ingredients[$0] != nil },
                               possible: Set(unsure.compactMap { ids[$0] }))
    }
}
