import DinnerCore
import Foundation
@testable import KitchenScanning
import Testing

struct Photo: Decodable, Sendable, CustomTestStringConvertible {
    let file, source, author, license: String
    /// Catalogue ingredients a person can see in the photo.
    let visible: [String]
    /// Ingredients the scanner found when the photo was added; a later miss is a regression.
    let mustFind: [String]
    var testDescription: String { file }
}

private let photos: [Photo] = {
    let url = Bundle.module.url(forResource: "Photos", withExtension: nil)!
    return try! JSONDecoder().decode([Photo].self, from: Data(contentsOf: url.appending(path: "photos.json")))
}()

@Suite struct KitchenPhotoChecks {
    @Test(arguments: photos)
    func keepsWhatItFoundBefore(photo: Photo) async throws {
        let catalogue = try Catalogue.bundled()
        let url = try #require(Bundle.module.url(forResource: "Photos", withExtension: nil)).appending(path: photo.file)
        let findings = try #require(await KitchenScanner.scan(Data(contentsOf: url), catalogue: catalogue))
        let listed = findings.found.union(findings.possible)
        let seen = Set(photo.visible).intersection(listed)
        print("\(photo.file): ticked \(findings.found.sorted()), offered \(findings.possible.sorted()), " +
              "\(seen.count)/\(photo.visible.count) visible listed")
        #expect(Set(photo.mustFind).isSubset(of: listed), "missing \(Set(photo.mustFind).subtracting(listed).sorted())")
    }
}
