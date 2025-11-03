# Where to Put Your Credentials

## 🔑 Firebase Credentials

### Automatic Setup (Recommended)
Run: `flutterfire configure`

This automatically:
- Creates `lib/firebase_options.dart`
- Adds `android/app/google-services.json`
- Adds `ios/Runner/GoogleService-Info.plist`

### Manual Setup (If needed)
1. **Android**: Download `google-services.json` from Firebase Console
   - Place in: `android/app/google-services.json`

2. **iOS**: Download `GoogleService-Info.plist` from Firebase Console
   - Place in: `ios/Runner/GoogleService-Info.plist`

3. **Update main.dart**:
   ```dart
   import 'firebase_options.dart';
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

## 📱 AdMob Credentials

### Ad Unit IDs Location
File: `lib/core/services/ad_service.dart`
Lines: 14-15

Replace:
```dart
static const String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917'; // Test ID
static const String _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test ID
```

With your actual ad unit IDs:
```dart
static const String _rewardedAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
static const String _interstitialAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ';
```

### AdMob App ID Location

**Android**: `android/app/src/main/AndroidManifest.xml`
```xml
<application>
  <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-XXXXXXXXXXXXXXXX~AAAAAAAAAA"/>
</application>
```

**iOS**: `ios/Runner/Info.plist`
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~AAAAAAAAAA</string>
```

## 💳 In-App Purchase Product IDs

File: `lib/core/services/purchase_service.dart`
Lines: 11-16

Current product IDs (update if yours differ):
- `monthly_subscription`
- `yearly_subscription`
- `lifetime_subscription`
- `credits_10`
- `credits_25`
- `credits_50`

## 📝 Summary

| Credential Type | Location | File |
|----------------|----------|------|
| Firebase Config | Auto-generated | After `flutterfire configure` |
| Ad Unit IDs | Code | `lib/core/services/ad_service.dart` |
| AdMob App ID (Android) | Manifest | `android/app/src/main/AndroidManifest.xml` |
| AdMob App ID (iOS) | Info.plist | `ios/Runner/Info.plist` |
| Product IDs | Code | `lib/core/services/purchase_service.dart` |

