import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/car_data.dart';

class CarScraper {
  static const String baseUrl = 'https://www.ultimatecarpage.com';
  static const int carsPerPage = 30;
  static const int maxPages = 200; // 1980 / 30

  final http.Client client;

  CarScraper({http.Client? client}) : client = client ?? http.Client();

  Future<String> fetchPage(String url) async {
    try {
      final response = await client.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Failed to load page: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching page: $e');
    }
  }

  List<CarBasicInfo> parseSearchPage(String html) {
    final document = html_parser.parse(html);
    
    // Find the parent container: #frame_main > table > tbody > tr > td
    final frameMain = document.getElementById('frame_main');
    if (frameMain == null) return [];

    final parentContainer = frameMain.querySelector('table > tbody > tr > td');
    if (parentContainer == null) return [];

    final tables = parentContainer.querySelectorAll('table');
    final List<CarBasicInfo> cars = [];

    if (tables.length < 3) return cars; // Need at least first, middle, and last table

    // Skip first and last table, process middle tables
    final Set<String> seenIds = {}; // Track seen car IDs to avoid duplicates
    
    for (int i = 1; i < tables.length - 1; i++) {
      final table = tables[i];
      final rows = table.querySelectorAll('tbody > tr');
      
      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        
        // Each row can have 1 or 2 cars depending on server response
        // Look for td elements with width="465px" that contain car data
        for (final cell in cells) {
          final carTable = cell.querySelector('table[cellpadding="0"][cellspacing="0"]');
          if (carTable != null) {
            final car = _parseCarFromTable(carTable);
            if (car != null && !seenIds.contains(car.id)) {
              seenIds.add(car.id);
              cars.add(car);
            }
          }
        }
      }
    }

    return cars;
  }

  CarBasicInfo? _parseCarFromTable(Element carTable) {
    try {
      // Find the link to the car page
      final link = carTable.querySelector('a[href*="/car/"]');
      if (link == null) return null;

      final href = link.attributes['href'] ?? '';
      if (href.isEmpty) return null;

      // Extract ID and slug from URL: /car/8863/Ferrari-SC40.html
      final match = RegExp(r'/car/(\d+)/([^/]+)\.html').firstMatch(href);
      if (match == null) return null;

      final id = match.group(1)!;
      final fullSlug = match.group(2)!;
      final slug = fullSlug;

      // Extract name from the link text
      final nameLink = carTable.querySelector('a[href*="/car/"]');
      String name = nameLink?.text.trim() ?? slug.replaceAll('-', ' ');
      
      // If name is empty, try to find it in the table structure
      if (name.isEmpty) {
        final nameCells = carTable.querySelectorAll('td');
        for (final cell in nameCells) {
          final cellLink = cell.querySelector('a[href*="/car/"]');
          if (cellLink != null && cellLink.text.trim().isNotEmpty) {
            name = cellLink.text.trim();
            break;
          }
        }
      }

      // Extract number of shots from span.red
      final shotsSpan = carTable.querySelector('span.red');
      int numberOfShots = 0;
      if (shotsSpan != null) {
        numberOfShots = int.tryParse(shotsSpan.text.trim()) ?? 0;
      }

      // Extract produced_in and last_updated from table rows
      int producedIn = 0;
      String lastUpdated = '';
      
      // Look for rows with "Produced in:" and "Last updated:"
      final allText = carTable.text;
      
      // Parse "Produced in: 2025"
      final producedMatch = RegExp(r'Produced in:\s*(\d{4})').firstMatch(allText);
      if (producedMatch != null) {
        producedIn = int.tryParse(producedMatch.group(1)!) ?? 0;
      }
      
      // Parse "Last updated: 10 / 17 / 2025"
      final updatedMatch = RegExp(r'Last updated:\s*([\d\s/]+)').firstMatch(allText);
      if (updatedMatch != null) {
        lastUpdated = updatedMatch.group(1)!.trim();
      }

      // Try alternative method using table structure
      if (producedIn == 0 || lastUpdated.isEmpty) {
        final rows = carTable.querySelectorAll('tr');
        for (final row in rows) {
          final darkCells = row.querySelectorAll('td.dark');
          if (darkCells.length >= 2) {
            final label = darkCells[0].text.trim();
            final value = darkCells[1].text.trim();
            
            if (label.contains('Produced in:') && producedIn == 0) {
              producedIn = int.tryParse(value) ?? 0;
            } else if (label.contains('Last updated:') && lastUpdated.isEmpty) {
              lastUpdated = value;
            }
          }
        }
      }

      return CarBasicInfo(
        id: id,
        name: name,
        slug: slug,
        url: href.startsWith('http') ? href : '$baseUrl$href',
        numberOfShots: numberOfShots,
        producedIn: producedIn,
        lastUpdated: lastUpdated,
      );
    } catch (e) {
      print('Error parsing car table: $e');
      return null;
    }
  }

  Future<CarData> scrapeCarDetails(CarBasicInfo basicInfo) async {
    final html = await fetchPage(basicInfo.url);
    final document = html_parser.parse(html);

    // Scrape car details
    final details = _parseCarDetails(document, basicInfo);
    
    // Scrape article
    final article = _parseArticle(document);
    details.article = article;

    // Scrape images
    final imgs = await _parseImages(document, basicInfo.id, basicInfo.slug);

    // Scrape specifications
    final specs = await _parseSpecifications(basicInfo.id, basicInfo.slug);

    return CarData(
      id: basicInfo.id,
      name: basicInfo.name,
      slug: basicInfo.slug,
      numberOfShots: basicInfo.numberOfShots,
      producedIn: basicInfo.producedIn,
      lastUpdated: basicInfo.lastUpdated,
      data: details,
      imgs: imgs,
      specs: specs,
    );
  }

  CarDetails _parseCarDetails(Document document, CarBasicInfo basicInfo) {
    final details = CarDetails();
    
    // Find the details container: look for div with table containing td.dark with car details
    final frameMain = document.getElementById('frame_main');
    if (frameMain == null) return details;
    
    // Look for div containing table with car details structure
    Element? detailTable;
    final divs = frameMain.querySelectorAll('div');
    
    for (final div in divs) {
      final table = div.querySelector('table');
      if (table != null) {
        // Check if this table has the car details structure (td.dark with labels)
        final rows = table.querySelectorAll('tr');
        bool hasCarDetails = false;
        for (final row in rows) {
          final cells = row.querySelectorAll('td.dark');
          if (cells.length >= 2) {
            final label = cells[0].text.trim().toLowerCase();
            if (label.contains('country of origin') || label.contains('produced in')) {
              hasCarDetails = true;
              break;
            }
          }
        }
        if (hasCarDetails) {
          detailTable = table;
          break;
        }
      }
    }
    
    if (detailTable == null) return details;

    // Parse detail rows from the table
    final rows = detailTable.querySelectorAll('tr');
    for (final row in rows) {
      final cells = row.querySelectorAll('td.dark');
      if (cells.length >= 2) {
        final label = cells[0].text.trim().toLowerCase();
        // Get value from <b> tag if present, otherwise use cell text
        final valueCell = cells[1];
        final value = valueCell.querySelector('b')?.text.trim() ?? valueCell.text.trim();
        
        // Clean up value (remove extra whitespace)
        final cleanValue = value.replaceAll(RegExp(r'[\n\r\t]+'), ' ').trim();

        if (label.contains('country of origin')) {
          details.countryOfOrigin = cleanValue;
        } else if (label.contains('produced in')) {
          details.producedIn = int.tryParse(cleanValue) ?? basicInfo.producedIn;
        } else if (label.contains('numbers built')) {
          details.numbersBuilt = cleanValue;
        } else if (label.contains('engine type')) {
          details.engineType = cleanValue;
        } else if (label.contains('designed by')) {
          details.designedBy = cleanValue;
        } else if (label.contains('source') && !label.contains('download')) {
          details.source = cleanValue;
        } else if (label.contains('last updated')) {
          details.lastUpdated = cleanValue;
        }
      }
    }

    return details;
  }

  String? _parseArticle(Document document) {
    final articleElement = document.getElementById('intelliTxt');
    if (articleElement == null) return null;

    // Clone the element to avoid modifying the original
    final articleClone = articleElement.clone(true);
    
    // Remove script tags and their content
    articleClone.querySelectorAll('script').forEach((script) => script.remove());
    
    // Remove the printer button and related elements
    // Find and remove any elements with onclick="disp_confirm()" or related to printing
    articleClone.querySelectorAll('input[onclick*="disp_confirm"]').forEach((el) => el.remove());
    articleClone.querySelectorAll('a[href*="javascript:disp_confirm"]').forEach((el) => el.remove());
    articleClone.querySelectorAll('img[src*="printer.jpg"]').forEach((el) => el.remove());
    articleClone.querySelectorAll('a[href*="javascript:"]').forEach((el) => el.remove());
    
    // Remove any hidden input elements with onclick
    articleClone.querySelectorAll('input[type="hidden"]').forEach((el) {
      if (el.attributes.containsKey('onclick') || 
          el.attributes['value']?.contains('confirm') == true) {
        el.remove();
      }
    });
    
    // Remove parent elements that contain only printer-related content
    articleClone.querySelectorAll('*').forEach((el) {
      final html = el.outerHtml;
      if (html.contains('disp_confirm') || 
          html.contains('printer.jpg') ||
          (el.localName == 'a' && el.attributes['href']?.contains('javascript:') == true)) {
        el.remove();
      }
    });
    
    // Get the text content after cleaning
    String articleText = articleClone.text.trim();
    
    // Clean up any remaining JavaScript function calls or confirm dialogs in text
    articleText = articleText.replaceAll(RegExp(r'disp_confirm\(\)'), '');
    articleText = articleText.replaceAll(
      RegExp(r'This is an exclusive feature for our premium subscribers[^.]*\.', caseSensitive: false), 
      ''
    );
    articleText = articleText.replaceAll(RegExp(r'Click here to download printer friendly version'), '');
    
    // Clean up extra whitespace
    articleText = articleText.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return articleText.isEmpty ? null : articleText;
  }

  Future<List<String>> _parseImages(Document document, String carId, String slug) async {
    final List<String> imageIds = [];
    
    try {
      // Try to find gallery link from car page
      final galleryLinks = document.querySelectorAll('a[href*="/cg/"]');
      
      if (galleryLinks.isNotEmpty) {
        // Get the gallery page URL
        final galleryUrl = galleryLinks.first.attributes['href'];
        if (galleryUrl != null && galleryUrl.contains('/cg/')) {
          final fullGalleryUrl = galleryUrl.startsWith('http') 
              ? galleryUrl 
              : '$baseUrl$galleryUrl';
          
          final galleryHtml = await fetchPage(fullGalleryUrl);
          final galleryDoc = html_parser.parse(galleryHtml);
          
          // Find all image links in gallery
          final imageLinks = galleryDoc.querySelectorAll('a[href*="/img/"]');
          for (final link in imageLinks) {
            final href = link.attributes['href'] ?? '';
            // Extract image ID from URL like /img/Ferrari-SC40-188517.html
            final match = RegExp(r'-(\d+)\.html$').firstMatch(href);
            if (match != null) {
              final imageId = match.group(1)!;
              if (!imageIds.contains(imageId)) {
                imageIds.add(imageId);
              }
            }
          }
        }
      }
      
      // Also try to extract from image src attributes on car page
      final imgElements = document.querySelectorAll('img[src*="/images/"]');
      for (final img in imgElements) {
        final src = img.attributes['src'] ?? '';
        final match = RegExp(r'/(\d+)\.jpg$').firstMatch(src);
        if (match != null) {
          final imageId = match.group(1)!;
          if (!imageIds.contains(imageId)) {
            imageIds.add(imageId);
          }
        }
      }
    } catch (e) {
      print('Error parsing images: $e');
    }
    
    return imageIds;
  }

  Future<List<Specification>> _parseSpecifications(String carId, String slug) async {
    try {
      final specUrl = '$baseUrl/spec/$carId/$slug.html';
      final html = await fetchPage(specUrl);
      final document = html_parser.parse(html);

      final frameMain = document.getElementById('frame_main');
      if (frameMain == null) return [];

      // Find the specifications container: #frame_main > table:nth-child(5) > tbody > tr > td:nth-child(2)
      // Try to find table with spec structure by looking for td#specstop
      Element? specContainer;
      
      // First, try direct approach: get all tables and check each for spec structure
      final tables = frameMain.querySelectorAll('table');
      for (final table in tables) {
        final tbody = table.querySelector('tbody');
        if (tbody == null) continue;
        
        final rows = tbody.querySelectorAll('tr');
        for (final row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length >= 2) {
            // Check if the second cell contains spec tables
            final secondCell = cells[1];
            final hasSpecTables = secondCell.querySelectorAll('table[cellpadding="0"][cellspacing="0"]').isNotEmpty;
            final hasSpecStop = secondCell.querySelector('td#specstop') != null;
            
            if (hasSpecTables || hasSpecStop) {
              specContainer = secondCell;
              break;
            }
          }
        }
        if (specContainer != null) break;
      }

      // Fallback: try the 5th table approach if direct search didn't work
      if (specContainer == null && tables.length >= 5) {
        final specTable = tables[4]; // 5th table (0-indexed)
        specContainer = specTable.querySelector('tbody > tr > td:nth-child(2)');
      }

      if (specContainer == null) return [];

      final List<Specification> specs = [];
      final tablesInContainer = specContainer.querySelectorAll('table[cellpadding="0"][cellspacing="0"]');

      if (tablesInContainer.isEmpty) return [];

      // Skip first table (usually empty), process middle tables, skip last (resources)
      final startIndex = 1;
      final endIndex = tablesInContainer.length > 1 ? tablesInContainer.length - 1 : tablesInContainer.length;

      for (int i = startIndex; i < endIndex; i++) {
        final table = tablesInContainer[i];
        
        // Find the header row with spec name
        final headerRow = table.querySelector('tr');
        if (headerRow == null) continue;

        final headerCell = headerRow.querySelector('td.darkbg#specstop, td#specstop, td[colspan="2"].darkbg');
        if (headerCell == null) continue;

        final specName = headerCell.text.trim();
        if (specName.isEmpty) continue;

        // Parse specification key-value pairs as a List
        final List<Map<String, dynamic>> specValues = [];
        final dataRows = table.querySelectorAll('tr');

        for (int j = 1; j < dataRows.length; j++) {
          final row = dataRows[j];
          final leftCell = row.querySelector('td#specsleft, td.lightbg#specsleft');
          final rightCell = row.querySelector('td#specsright, td.lightbg#specsright');
          
          if (leftCell != null && rightCell != null) {
            // Clean up whitespace from key and value
            final component = leftCell.text.trim().replaceAll(RegExp(r'[\n\r\t]+'), ' ').trim();
            final capacity = rightCell.text.trim().replaceAll(RegExp(r'[\n\r\t]+'), ' ').trim();
            
            if (component.isNotEmpty && capacity.isNotEmpty) {
              specValues.add({
                'component': component,
                'capacity': capacity,
              });
            }
          }
        }

        if (specValues.isNotEmpty) {
          specs.add(Specification(
            spec: specName.trim().replaceAll(RegExp(r'[\n\r\t]+'), ' '),
            value: specValues,
          ));
        }
      }

      return specs;
    } catch (e) {
      print('Error parsing specifications: $e');
      return [];
    }
  }

  Future<List<CarBasicInfo>> scrapeSearchPages({int startPage = 0, int endPage = maxPages}) async {
    final List<CarBasicInfo> allCars = [];

    for (int page = startPage; page <= endPage; page++) {
      final startIndex = page * carsPerPage;
      String url;
      
      if (page == 0) {
        url = '$baseUrl/search/&modified=2000';
      } else {
        url = '$baseUrl/search/&keys=&method=&carspagestart=$startIndex&modified=2000';
      }

      print('Scraping page ${page + 1} (start: $startIndex)...');
      
      try {
        final html = await fetchPage(url);
        final cars = parseSearchPage(html);
        allCars.addAll(cars);
        print('Found ${cars.length} cars on page ${page + 1}');
        
        // Add delay to be respectful to the server
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('Error scraping page ${page + 1}: $e');
      }
    }

    return allCars;
  }

  Future<List<CarData>> scrapeAllCars({int startPage = 0, int endPage = 2}) async {
    final basicInfos = await scrapeSearchPages(startPage: startPage, endPage: endPage);
    final List<CarData> cars = [];

    print('\nScraping details for ${basicInfos.length} cars...\n');

    for (int i = 0; i < basicInfos.length; i++) {
      final info = basicInfos[i];
      print('[$i/${basicInfos.length}] Scraping ${info.name}...');
      
      try {
        final carData = await scrapeCarDetails(info);
        cars.add(carData);
        print('✓ Successfully scraped ${info.name}');
        
        // Add delay between requests
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        print('✗ Error scraping ${info.name}: $e');
      }
    }

    return cars;
  }

  void dispose() {
    client.close();
  }
}

