# Dinner Tonight

An iPhone app that gets you from "what's for dinner?" to a decision in about thirty seconds. Everything stays on the device: no account, no server.

## Layout

| Path | Content |
|---|---|
| `Packages/DinnerCore` | Foundation only: catalogue, safety filter, ranker, reasons, shopping amounts, saved data. Tested on macOS. |
| `Packages/DinnerCore/Sources/DinnerCore/Resources/catalogue.json` | The ingredient table and dishes. |
| `App/` | SwiftUI screens, `AppModel`, reminders. |
| `project.yml` | XcodeGen spec for `DinnerTonight.xcodeproj`, which is not checked in. |

## Commands

```sh
swift test --package-path Packages/DinnerCore
xcodegen generate
```

## Rules worth keeping

- A dish has no allergen or diet field. Both are derived from its ingredients, so add new foods to the ingredient table and tag them conservatively, including what products of that type commonly contain.
- Allergens, diet and foods to avoid are never relaxed. Only the time limit is, and the screen says so.
- No calories, weight-loss framing or medical claims.
- `parmesan` counts as vegetarian here, though traditional parmesan uses animal rennet; the app tells people to check labels.

## Before release

The allergen tags in the ingredient table have been tested for consistency, not reviewed by a dietitian or food-safety professional. Have one review them. Allergen wording and terms of use also need a legal check.

## Kitchen photos

The Tonight screen's kitchen step takes a photo and recognises ingredients on the phone with Apple's Vision framework. No photo is saved or sent anywhere.

- `App/KitchenScanner.swift` runs image classification (whole photo and a 3×3 grid) and text reading.
- `KitchenRecognition` in DinnerCore maps results to catalogue ingredients. Specific, confident sightings and package names are ticked; broad or unsure ones are offered unticked. The person always reviews the list.
- With a kitchen known, dinners cookable without shopping rank first. A kitchen list is ignored after `AppData.kitchenFreshDays`.
- Photos never affect allergen, diet or avoided-food filtering.
- The classifier does not work in the Simulator (it fails to start or returns unrelated labels), so only text reading can be checked there. The camera needs a real iPhone.
