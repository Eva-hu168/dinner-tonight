# Kitchen photo tests

Real photos run through the App's scanner (`App/KitchenScanner.swift`, `App/KitchenModelReader.swift`, symlinked into `Sources/KitchenScanning`) on macOS:

```sh
swift test --package-path Tests/KitchenPhotos
```

`Photos/photos.json` lists, per photo, the catalogue ingredients visible in it (`visible`) and those the scanner found when the photo was added (`mustFind`). The test fails when a `mustFind` ingredient is no longer listed, and prints how many visible ingredients were listed. Vision results can shift between macOS releases; with the on-device model available, the model path runs instead.

## Photo sources

All from Wikimedia Commons, resized to 1280 px wide.

| File | Author | License | Source |
|---|---|---|---|
| `fridge-door-bottles.jpg` | Bretwa | CC0 | [Food_into_a_refrigerator_-_20111002.jpg](https://commons.wikimedia.org/wiki/File:Food_into_a_refrigerator_-_20111002.jpg) |
| `fridge-produce-drawers.jpg` | Alabama Extension | CC0 | [Fruits_and_Vegetables_in_Refrigerator_-_50837631333.jpg](https://commons.wikimedia.org/wiki/File:Fruits_and_Vegetables_in_Refrigerator_-_50837631333.jpg) |
| `fridge-open-at-night.jpg` | W.carter | CC BY-SA 4.0 | [Open_refrigerator_with_food_at_night.jpg](https://commons.wikimedia.org/wiki/File:Open_refrigerator_with_food_at_night.jpg) |
| `vegetable-bin-close.jpg` | Alabama Extension | CC0 | [Vegetables_in_Refrigerator_Bin.jpg](https://commons.wikimedia.org/wiki/File:Vegetables_in_Refrigerator_Bin.jpg) |
| `vegetable-bin-wide.jpg` | Alabama Extension | CC0 | [Vegetables_in_Refrigerator_Bin_-_50838442242.jpg](https://commons.wikimedia.org/wiki/File:Vegetables_in_Refrigerator_Bin_-_50838442242.jpg) |
| `french-door-fridge-showroom.jpg` | Maurizio Pesce from Milan, Italia | CC BY 2.0 | [Samsung_French_Door_Refrigerator_with_Food_Showcase_Design_(16676046120).jpg](https://commons.wikimedia.org/wiki/File:Samsung_French_Door_Refrigerator_with_Food_Showcase_Design_(16676046120).jpg) |
| `leftover-containers.jpg` | USDAgov | Public domain | [Food_Safety_-_Cut_Waste_in_Refrigerators_(20200605-FSIS-LSC-0066).jpg](https://commons.wikimedia.org/wiki/File:Food_Safety_-_Cut_Waste_in_Refrigerators_(20200605-FSIS-LSC-0066).jpg) |
| `leftovers-with-lemon.jpg` | USDAgov | Public domain | [Food_Safety_-_Cut_Waste_in_Refrigerators_(20200605-FSIS-LSC-0090).jpg](https://commons.wikimedia.org/wiki/File:Food_Safety_-_Cut_Waste_in_Refrigerators_(20200605-FSIS-LSC-0090).jpg) |
| `crisper-drawers-open.jpg` | Yoninah | CC BY-SA 4.0 | [Open_crisper_drawers.jpg](https://commons.wikimedia.org/wiki/File:Open_crisper_drawers.jpg) |
| `red-peppers-counter.jpg` | Shixart1985 | CC BY 2.0 | [Red_bell_peppers_on_a_kitchen_counter.jpg](https://commons.wikimedia.org/wiki/File:Red_bell_peppers_on_a_kitchen_counter.jpg) |
