import DinnerCore
import ImageIO
import OSLog
import Vision

/// Finds ingredients in a photo, on this iPhone. The photo is read from memory and never written anywhere.
enum KitchenScanner {
    private static let log = Logger(subsystem: "com.dinnertonight.app", category: "KitchenScanner")

    /// Large enough for label text; small enough that a 48-megapixel photo cannot exhaust memory.
    private static let maxPixels = 2048
    private static let gridSize = 3

    static func scan(_ photo: Data, catalogue: Catalogue) async -> KitchenFindings? {
        await Task.detached(priority: .userInitiated) {
            guard let image = decode(photo) else { return nil }
            let seen = attempt("classification") { try labels(in: image) }
            let read = attempt("text reading") { try textLines(in: image) }
            // One reader failing still leaves a useful list; only both failing is a failed scan.
            guard seen != nil || read != nil else { return nil }
            return KitchenRecognition.findings(labels: seen ?? [], textLines: read ?? [], catalogue: catalogue)
        }.value
    }

    private static func attempt<Result>(_ name: String, _ work: () throws -> Result) -> Result? {
        do {
            return try work()
        } catch {
            log.error("Kitchen \(name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Applies the photo's orientation, so text is upright for the reader.
    private static func decode(_ photo: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(photo as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// The classifier describes one scene, so a full shelf is also read in tiles: each tile holds fewer items.
    private static func labels(in image: CGImage) throws -> [VisualLabel] {
        let width = image.width / gridSize, height = image.height / gridSize
        let tiles = (0..<gridSize * gridSize).compactMap { index in
            image.cropping(to: CGRect(x: index % gridSize * width, y: index / gridSize * height, width: width, height: height))
        }
        return try ([image] + tiles).flatMap { picture -> [VisualLabel] in
            let request = VNClassifyImageRequest()
            try VNImageRequestHandler(cgImage: picture).perform([request])
            return (request.results ?? []).compactMap { observation in
                // Apple's per-label precision curves; a raw confidence means something different for each label.
                if observation.hasMinimumRecall(0.01, forPrecision: 0.9) {
                    return VisualLabel(identifier: observation.identifier, isConfident: true)
                }
                return observation.hasMinimumPrecision(0.5, forRecall: 0.2)
                    ? VisualLabel(identifier: observation.identifier, isConfident: false) : nil
            }
        }
    }

    private static func textLines(in image: CGImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }
}
