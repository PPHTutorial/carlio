import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'car_scraper.dart';

Future<void> main() async {
  print('🧪 Testing Car Scraper');
  print('======================\n');

  final scraper = CarScraper();
  
  try {
    // Test with the search page URL
    final testUrl = 'https://www.ultimatecarpage.com/search/&modified=2000';
    print('Fetching test page: $testUrl\n');
    
    final html = await scraper.fetchPage(testUrl);
    final cars = scraper.parseSearchPage(html);
    
    print('✅ Found ${cars.length} cars on the page\n');
    
    if (cars.isEmpty) {
      print('❌ No cars found. Please check the parsing logic.');
      return;
    }
    
    // Display first few cars
    print('Sample cars found:\n');
    for (int i = 0; i < cars.length && i < 5; i++) {
      final car = cars[i];
      print('Car ${i + 1}:');
      print('  ID: ${car.id}');
      print('  Name: ${car.name}');
      print('  Slug: ${car.slug}');
      print('  Produced in: ${car.producedIn}');
      print('  Number of shots: ${car.numberOfShots}');
      print('  Last updated: ${car.lastUpdated}');
      print('  URL: ${car.url}');
      print('');
    }
    
    // Test scraping details for first car
    if (cars.isNotEmpty) {
      print('Testing detail scraping for: ${cars.first.name}...\n');
      
      // Test car details parsing
      print('Testing car details parsing...');
      final carHtml = await scraper.fetchPage(cars.first.url);
      final carDoc = html_parser.parse(carHtml);
      
      final frameMain = carDoc.getElementById('frame_main');
      if (frameMain != null) {
        final divs = frameMain.querySelectorAll('div');
        print('  Found ${divs.length} divs in frame_main');
        
        for (int i = 0; i < divs.length && i < 10; i++) {
          final div = divs[i];
          final table = div.querySelector('table');
          if (table != null) {
            final hasDarkCells = table.querySelectorAll('td.dark').isNotEmpty;
            if (hasDarkCells) {
              print('  Div $i: Found table with dark cells');
              final rows = table.querySelectorAll('tr');
              print('    Table has ${rows.length} rows');
              if (rows.isNotEmpty) {
                final firstRow = rows.first;
                final cells = firstRow.querySelectorAll('td.dark');
                if (cells.length >= 2) {
                  print('    First row: ${cells[0].text.trim()} = ${cells[1].text.trim()}');
                }
              }
            }
          }
        }
      }
      
      // Test specifications directly
      print('\nTesting specifications parsing...');
      final specUrl = 'https://www.ultimatecarpage.com/spec/${cars.first.id}/${cars.first.slug}.html';
      final specHtml = await scraper.fetchPage(specUrl);
      final specDoc = html_parser.parse(specHtml);
      
      final frameMain2 = specDoc.getElementById('frame_main');
      if (frameMain2 != null) {
        final tables = frameMain2.querySelectorAll('table');
        print('  Found ${tables.length} tables in frame_main');
      }
      
      final carData = await scraper.scrapeCarDetails(cars.first);
      
      print('\n✅ Car details scraped:');
      print('  Car Details:');
      print('    Country of origin: ${carData.data.countryOfOrigin ?? "N/A"}');
      print('    Produced in: ${carData.data.producedIn ?? carData.producedIn}');
      print('    Numbers built: ${carData.data.numbersBuilt ?? "N/A"}');
      print('    Engine type: ${carData.data.engineType ?? "N/A"}');
      print('    Designed by: ${carData.data.designedBy ?? "N/A"}');
      print('    Source: ${carData.data.source ?? "N/A"}');
      print('    Last updated: ${carData.data.lastUpdated ?? carData.lastUpdated}');
      print('  Article length: ${carData.data.article?.length ?? 0} characters');
      print('  Images: ${carData.imgs.length}');
      print('  Specifications: ${carData.specs.length}');
      
      if (carData.specs.isNotEmpty) {
        print('\n  Specification categories:');
        for (final spec in carData.specs) {
          print('    - ${spec.spec}: ${spec.value.length} items');
          if (spec.value.isNotEmpty) {
            final firstItem = spec.value.first;
            print('      Example: ${firstItem['component']} = ${firstItem['capacity']}');
          }
        }
      }
      
      if (carData.data.article != null) {
        final articlePreview = carData.data.article!.length > 200 
            ? '${carData.data.article!.substring(0, 200)}...'
            : carData.data.article!;
        print('  Article preview: $articlePreview');
        
        // Check if unwanted content is still present
        if (carData.data.article!.contains('disp_confirm') || 
            carData.data.article!.contains('printer.jpg') ||
            carData.data.article!.contains('premium subscribers')) {
          print('\n⚠️  WARNING: Article still contains unwanted content!');
        } else {
          print('\n✅ Article cleaned successfully!');
        }
      }
    }
    
  } catch (e, stackTrace) {
    print('❌ Error during testing: $e');
    print('\nStack trace:');
    print(stackTrace);
  } finally {
    scraper.dispose();
  }
}

