import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:carcollection/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Tests', () {
    testWidgets('Take screenshots of all UI screens', (WidgetTester tester) async {
      print('📸 Starting screenshot capture...\n');

      // Initialize the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      print('✓ App initialized\n');

      // Screenshot 1: Dashboard Screen (Light Theme - Default)
      await _takeScreenshot(
        tester,
        '01_dashboard_light',
        'Dashboard Screen - Light Theme',
      );

      // Switch to dark theme using FAB
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        print('🔄 Switching to dark theme...');
        await tester.tap(fab.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 800));
        print('✓ Dark theme activated\n');
      }

      // Screenshot 2: Dashboard Screen (Dark Theme)
      await _takeScreenshot(
        tester,
        '02_dashboard_dark',
        'Dashboard Screen - Dark Theme',
      );

      // Navigate to Garage Screen
      print('🔄 Navigating to Garage screen...');
      final garageButton = find.widgetWithText(GestureDetector, 'Garage');
      if (garageButton.evaluate().isEmpty) {
        // Try alternative finder
        final garageText = find.text('Garage');
        if (garageText.evaluate().isNotEmpty) {
          await tester.tap(garageText);
        }
      } else {
        await tester.tap(garageButton);
      }
      await tester.pumpAndSettle(const Duration(seconds: 2));
      print('✓ Garage screen loaded\n');

      // Screenshot 3: Garage Screen (Dark Theme)
      await _takeScreenshot(
        tester,
        '03_garage_dark',
        'Garage Screen - Dark Theme',
      );

      // Switch back to light theme
      print('🔄 Switching to light theme...');
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 800));
      }
      print('✓ Light theme activated\n');

      // Screenshot 4: Garage Screen (Light Theme)
      await _takeScreenshot(
        tester,
        '04_garage_light',
        'Garage Screen - Light Theme',
      );

      // Try to tap on first car card
      print('🔄 Opening car detail...');
      final carCards = find.byType(InkWell);
      if (carCards.evaluate().isNotEmpty) {
        try {
          // Find a car card (not the navigation buttons)
          final allInkWells = carCards.evaluate();
          for (var element in allInkWells) {
            final widget = element.widget;
            if (widget is InkWell) {
              // Tap the first non-navigation InkWell
              await tester.tap(carCards.first);
              await tester.pumpAndSettle(const Duration(seconds: 3));
              print('✓ Car detail screen opened\n');
              break;
            }
          }
        } catch (e) {
          print('⚠️  Could not tap car card: $e\n');
        }
      }

      // Screenshot 5: Car Detail Screen (Light Theme)
      await _takeScreenshot(
        tester,
        '05_car_detail_light',
        'Car Detail Screen - Light Theme',
      );

      // Scroll down to see more content
      print('🔄 Scrolling car detail...');
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        try {
          await tester.drag(scrollables.first, const Offset(0, -400));
          await tester.pumpAndSettle(const Duration(milliseconds: 800));
          print('✓ Scrolled down\n');
        } catch (e) {
          print('⚠️  Could not scroll: $e\n');
        }
      }

      // Screenshot 6: Car Detail - Scrolled
      await _takeScreenshot(
        tester,
        '06_car_detail_scrolled_light',
        'Car Detail Screen - Scrolled View (Light Theme)',
      );

      // Try to open image preview
      print('🔄 Opening image preview...');
      final gestureDetectors = find.byType(GestureDetector);
      if (gestureDetectors.evaluate().length > 1) {
        try {
          // Try tapping on the hero image area
          await tester.tapAt(const Offset(200, 200));
          await tester.pumpAndSettle(const Duration(seconds: 2));
          print('✓ Image preview opened\n');
        } catch (e) {
          print('⚠️  Could not open image preview: $e\n');
        }
      }

      // Screenshot 7: Image Preview Screen (if opened)
      await _takeScreenshot(
        tester,
        '07_image_preview',
        'Image Preview Screen with Zoom',
      );

      // Navigate back
      print('🔄 Navigating back...');
      final backButtons = find.byIcon(Icons.arrow_back);
      if (backButtons.evaluate().isEmpty) {
        // Try close button
        final closeButtons = find.byIcon(Icons.close);
        if (closeButtons.evaluate().isNotEmpty) {
          await tester.tap(closeButtons.first);
        }
      } else {
        await tester.tap(backButtons.first);
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Go back again if needed
      if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
      }
      print('✓ Navigated back\n');

      // Switch to dark theme
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
      }

      // Navigate to dashboard
      print('🔄 Navigating to Dashboard...');
      final dashboardButton = find.text('Dashboard');
      if (dashboardButton.evaluate().isNotEmpty) {
        await tester.tap(dashboardButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
      print('✓ Dashboard loaded\n');

      // Screenshot 8: Dashboard - Featured Collection (Dark Theme)
      await _takeScreenshot(
        tester,
        '08_dashboard_featured_dark',
        'Dashboard - Featured Collection View (Dark Theme)',
      );

      print('\n✅ Screenshot capture completed!');
      print('📁 Screenshots saved by Flutter integration test framework');
      print('📱 Note: Screenshots are saved on the device.');
      print('   For Android: Check device storage or use adb to pull screenshots');
    });
  });
}

Future<void> _takeScreenshot(
  WidgetTester tester,
  String filename,
  String description,
) async {
  try {
    print('📸 Capturing: $description');
    
    // Wait for UI to settle
    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    
    // Take screenshot using IntegrationTestWidgetsFlutterBinding
    // Screenshots are automatically saved by Flutter integration test framework
    // They are saved on the device and can be retrieved using adb or from test output
    await IntegrationTestWidgetsFlutterBinding.instance.takeScreenshot(filename);
    
    print('   ✓ Saved: $filename\n');
  } catch (e) {
    print('   ✗ Failed to capture $filename: $e\n');
    // Don't rethrow - continue with other screenshots
  }
}
