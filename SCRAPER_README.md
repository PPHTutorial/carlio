# Car Data Scraper

To populate the app with car data, you need to run the scraper script.

## How to Run the Scraper

1. **Navigate to the project root directory**

2. **Run the scraper:**
   ```bash
   dart run lib/scraper/scraper_main.dart
   ```

   Or if you want to specify a range of pages:
   ```bash
   dart run lib/scraper/scraper_main.dart
   ```

3. **Wait for completion:**
   - The scraper will download car data from ultimatecarpage.com
   - It will save the data to `cars_data.json` in the project root
   - Progress will be shown in the terminal

4. **Add the file to assets:**
   - Copy `cars_data.json` to `assets/cars_data.json`
   - Or update `pubspec.yaml` to include the file from the root if preferred

5. **Rebuild the app:**
   ```bash
   flutter pub get
   flutter run
   ```

## Note

- The scraper may take some time depending on how many pages you scrape
- The default setup scrapes pages 0-66 (approximately 1980 cars)
- You can modify the range in `lib/scraper/scraper_main.dart`

## Alternative: Place JSON file manually

If you already have a `cars_data.json` file:
1. Copy it to `assets/cars_data.json`
2. Run `flutter pub get`
3. Restart the app

The app will automatically load the data from assets.

