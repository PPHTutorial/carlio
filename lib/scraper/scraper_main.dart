import 'dart:convert';
import 'dart:io';
import 'car_scraper.dart';
import '../models/car_data.dart';

Future<void> main() async {
  print('🚗 Ultimate Car Page Scraper');
  print('==============================\n');

  final scraper = CarScraper();
  final List<CarData> allCars = [];
  
  try {
    const int startPage = 26;
    const int endPage = 200; // 1980 / 30 = 200 pages
    
    print('Starting sequential scrape...');
    print('Scraping pages $startPage to $endPage (${endPage - startPage + 1} pages)\n');

    // Scrape page by page, item by item
    for (int page = startPage; page <= endPage; page++) {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📄 Scraping Page ${page + 1}/${endPage + 1}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // Get basic info for this page only
      final startIndex = page * CarScraper.carsPerPage;
      String url;
      
      if (page == 0) {
        url = '${CarScraper.baseUrl}/search/&modified=2000';
      } else {
        url = '${CarScraper.baseUrl}/search/&keys=&method=&carspagestart=$startIndex&modified=2000';
      }

      final html = await scraper.fetchPage(url);
      final basicInfos = scraper.parseSearchPage(html);

      if (basicInfos.isEmpty) {
        print('⚠️  No cars found on page ${page + 1}');
        continue;
      }

      print('Found ${basicInfos.length} cars on page ${page + 1}\n');

      // Scrape each item fully before moving to next
      for (int i = 0; i < basicInfos.length; i++) {
        final info = basicInfos[i];
        final itemNumber = i + 1;
        final totalOnPage = basicInfos.length;
        
        print('[$itemNumber/$totalOnPage] Scraping: ${info.name}...');
        
        try {
          // Fully scrape this item (details, specs, images, article - everything)
          final carData = await scraper.scrapeCarDetails(info);
          allCars.add(carData);
          
          print('   ✓ Successfully scraped ${info.name}');
          print('   📸 Images: ${carData.imgs.length}, 📋 Specs: ${carData.specs.length}');
          
          // Save incrementally every 10 cars
          if (allCars.length % 10 == 0) {
            await _saveProgress(allCars);
          }
          
          // Add delay between requests
          await Future.delayed(const Duration(milliseconds: 800));
        } catch (e) {
          print('   ✗ Error scraping ${info.name}: $e');
          // Continue to next item even if one fails
        }
      }

      // Small delay between pages
      if (page < endPage) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Save progress after each page
      await _saveProgress(allCars);
      
      print('\n📊 Progress: ${allCars.length} cars scraped so far');
    }

    // Final save
    await _saveFinal(allCars);

    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('✅ Scraping completed!');
    print('📊 Total cars scraped: ${allCars.length}');
    print('💾 Data saved to: assets/data/cars_data.json');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
  } catch (e) {
    print('❌ Error during scraping: $e');
    // Try to save what we have
    if (allCars.isNotEmpty) {
      await _saveProgress(allCars);
      print('\n💾 Saved ${allCars.length} cars before error');
    }
  } finally {
    scraper.dispose();
  }
}

Future<void> _saveProgress(List<CarData> cars) async {
  try {
    final jsonData = cars.map((car) => car.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('    ').convert(jsonData);
    final file = File('assets/data/cars_data.json');
    await file.writeAsString(jsonString);
  } catch (e) {
    print('⚠️  Warning: Could not save progress: $e');
  }
}

Future<void> _saveFinal(List<CarData> cars) async {
  try {
    final jsonData = cars.map((car) => car.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('    ').convert(jsonData);
    final file = File('assets/data/cars_data.json');
    await file.writeAsString(jsonString);
    print('✅ Final save completed');
  } catch (e) {
    print('❌ Error saving final file: $e');
  }
}

