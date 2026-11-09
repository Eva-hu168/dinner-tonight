// COMPAT: image prompts need the iOS 27 SDK, which ships with Swift 6.4; older Xcode builds the Vision path only.
#if compiler(>=6.4)
import CoreGraphics
import DinnerCore
import FoundationModels
import OSLog

/// Lists the ingredients in a photo with Apple's on-device language model, which reads a whole fridge shelf,
/// where the image classifier sees one scene. Answers are limited to catalogue ingredient names.
@available(iOS 27, *)
enum KitchenModelReader {
    private static let log = Logger(subsystem: "com.dinnertonight.app", category: "KitchenModelReader")

    /// Greedy decoding can repeat an item; the cap ends such a loop.
    private static let maxItemsPerList = 40

    private static let instructions = """
        You look at a photo of someone's fridge, cupboard or kitchen counter and say which ingredients from \
        the allowed list it shows. Name an ingredient only when it is in the photo. Packaged food counts when \
        its label or shape shows what it is. Leave out food that is not on the list.
        """

    /// Nil when the model is unavailable on this iPhone or fails, so the caller falls back to Vision.
    static func look(at image: CGImage, catalogue: Catalogue) async -> (seen: [String], unsure: [String])? {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            log.info("On-device model unavailable: \(String(describing: model.availability), privacy: .public)")
            return nil
        }
        do {
            let session = LanguageModelSession(model: model, instructions: instructions)
            let response = try await session.respond(
                schema: schema(choices: KitchenRecognition.modelChoices(in: catalogue)),
                options: GenerationOptions(samplingMode: .greedy)
            ) {
                "Which of the allowed ingredients are in this photo?"
                Attachment(image)
            }
            return (try response.content.value([String].self, forProperty: "seen"),
                    try response.content.value([String].self, forProperty: "unsure"))
        } catch {
            log.error("On-device model failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Both lists refer to one shared enumeration, so the ingredient names appear once in the prompt.
    private static func schema(choices: [String]) throws -> GenerationSchema {
        let ingredient = DynamicGenerationSchema(name: "Ingredient", anyOf: choices)
        func list(_ name: String, _ description: String) -> DynamicGenerationSchema.Property {
            DynamicGenerationSchema.Property(
                name: name, description: description,
                schema: DynamicGenerationSchema(arrayOf: DynamicGenerationSchema(referenceTo: "Ingredient"),
                                                maximumElements: maxItemsPerList))
        }
        let root = DynamicGenerationSchema(name: "KitchenPhoto", properties: [
            list("seen", "Ingredients clearly visible in the photo."),
            list("unsure", "Ingredients that may be in the photo but are partly hidden, blurry or hard to tell apart."),
        ])
        return try GenerationSchema(root: root, dependencies: [ingredient])
    }
}
#endif
