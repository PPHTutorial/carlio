# Premium Features Setup Guide

## 🔥 Firebase Setup

### Step 1: Install FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

### Step 2: Configure Firebase
```bash
flutterfire configure
```
This will:
- Connect to your Firebase project
- Create `lib/firebase_options.dart`
- Add `google-services.json` to `android/app/`
- Add `GoogleService-Info.plist` to `ios/Runner/`

### Step 3: Update main.dart
After running `flutterfire configure`, update `lib/main.dart`:
```dart
import 'firebase_options.dart';

void main() async {
  // ...
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
```

### Step 4: Configure Firestore Security Rules
⚠️ **CRITICAL:** You must configure Firestore security rules to allow users to write their own data.

**The rules file is also saved as `FIRESTORE_RULES.txt` in your project root for easy copy-paste.**

1. Go to Firebase Console → Firestore Database → Rules
2. **Copy and paste the rules from `FIRESTORE_RULES.txt`** or use the rules below:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - users can only read/write their own document
    match /users/{userId} {
      // Allow read if user is authenticated and accessing their own data
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Allow create if user is authenticated and creating their own document
      allow create: if request.auth != null && request.auth.uid == userId;
      
      // Allow update if user is authenticated and updating their own document
      allow update: if request.auth != null && request.auth.uid == userId;
      
      // Allow delete if user is authenticated and deleting their own document
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // Transactions collection - users can only read/write their own transactions
    match /transactions/{transactionId} {
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
    }
    
    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Important Notes:**
- These rules ensure users can only access their own data
- The rules are simplified for easier setup - users can create their own documents when authenticated
- Make sure to click **"Publish"** after pasting the rules
- For testing, you can temporarily use more permissive rules:
  ```javascript
  // TEMPORARY TESTING RULES (NOT FOR PRODUCTION)
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      match /{document=**} {
        allow read, write: if request.auth != null;
      }
    }
  }
  ```

3. Click **"Publish"** to apply the rules (this is critical!)
4. Wait a few seconds for the rules to propagate
5. Try signing up again

## 📱 AdMob Setup

### Step 1: Get Your Ad Unit IDs
1. Create AdMob account: https://admob.google.com
2. Create app (if not already)
3. Create ad units:
   - One Rewarded Ad unit
   - One Interstitial Ad unit

### Step 2: Update Ad Service
Edit `lib/core/services/ad_service.dart`:
```dart
static const String _rewardedAdUnitId = 'ca-app-pub-XXXXXXXXXX/YYYYYYYYYY'; // Your ID
static const String _interstitialAdUnitId = 'ca-app-pub-XXXXXXXXXX/ZZZZZZZZZZ'; // Your ID
```

### Step 3: Add App ID to Android
Edit `android/app/src/main/AndroidManifest.xml`:
Add inside `<application>` tag:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXX~AAAAAAAAAA"/>
```

### Step 4: Add App ID to iOS
Edit `ios/Runner/Info.plist`:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXX~AAAAAAAAAA</string>
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
</array>
```

## 💰 In-App Purchase Setup

### Android (Google Play Console)
1. Go to: Monetize → Products → Subscriptions
2. Create subscriptions:
   - `monthly_subscription` - Monthly, $55
   - `yearly_subscription` - Yearly, $250
   - `lifetime_subscription` - Lifetime, $1000
3. Go to: Monetize → Products → In-app products
4. Create products:
   - `credits_10` - One-time purchase
   - `credits_25` - One-time purchase
   - `credits_50` - One-time purchase

### iOS (App Store Connect)
1. Go to: My Apps → [Your App] → Features → In-App Purchases
2. Create subscriptions (same as Android)
3. Create consumable products (same as Android)

### Update Product IDs (if needed)
Edit `lib/core/services/purchase_service.dart` if your product IDs differ.

## 🖼️ Watermark Image

Ensure `assets/images/watermark.png` exists. If not, create a watermark image and place it in:
- `assets/images/watermark.png`

## 🔧 Native Implementation Needed

### Wallpaper Setting (Android)
Create `android/app/src/main/kotlin/.../MainActivity.kt`:
```kotlin
import android.app.WallpaperManager
import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.carcollection/wallpaper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setWallpaper") {
                val imagePath = call.argument<String>("imagePath")
                try {
                    val bitmap = BitmapFactory.decodeFile(imagePath)
                    val wallpaperManager = WallpaperManager.getInstance(this)
                    wallpaperManager.setBitmap(bitmap)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
```

### AR Support (Optional)
Implement AR platform channels in native code if you want full AR functionality.

## ✅ Verification Checklist

- [ ] Firebase project created and configured
- [ ] `flutterfire configure` completed successfully
- [ ] AdMob account created
- [ ] Ad unit IDs added to `ad_service.dart`
- [ ] AdMob App ID added to AndroidManifest.xml
- [ ] AdMob App ID added to Info.plist
- [ ] In-app purchase products created in stores
- [ ] Product IDs match in `purchase_service.dart`
- [ ] Watermark image exists at `assets/images/watermark.png`
- [ ] Native wallpaper implementation added (Android)

## 🚀 Testing

1. **Test Auth Flow:**
   - Sign up new user
   - Sign in existing user
   - Check Firestore user document created

2. **Test Free User Flow:**
   - Try to download image → Should prompt for ads
   - Watch 2 ads → Should unlock download
   - Download should have watermark

3. **Test Pro User Flow:**
   - Purchase subscription (test mode)
   - Try to download → Should use credits
   - Download should NOT have watermark

4. **Test Purchases:**
   - Test subscription purchase
   - Test credit purchase
   - Verify credits added to Firestore

## 📝 Notes

- Credit pricing for packages not specified - you'll need to set prices in stores
- Minimum 10 credits purchase requirement is enforced in UI
- Each action (download/wallpaper) costs 3 credits
- Free users need 2 ad watches per image
- Download All Images is Pro-only feature

