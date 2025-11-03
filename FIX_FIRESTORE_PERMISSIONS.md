# Fix Firestore Permission Denied Error

## Quick Fix Steps

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com
   - Select your project

2. **Navigate to Firestore Database → Rules**

3. **Copy and paste these rules** (from `FIRESTORE_RULES.txt`):

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

4. **Click "Publish"** (IMPORTANT - rules won't work until published!)

5. **Wait 10-30 seconds** for rules to propagate

6. **Restart your app** and try again

## Testing Rules (Temporary - Only for Development)

If you need to test quickly, you can temporarily use these more permissive rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

⚠️ **WARNING:** These rules allow any authenticated user to read/write any document. Only use for testing, then switch back to the secure rules above!

## Verify Rules Are Active

1. Check the Firebase Console → Firestore → Rules
2. Look for a green checkmark or "Published" status
3. Rules should update within seconds, but can take up to 1 minute

## Common Issues

- **Rules not published**: Make sure you clicked "Publish" after pasting
- **User not authenticated**: Make sure user is signed in before accessing Firestore
- **Rules syntax error**: Check for typos in the rules (Firebase will show errors)
- **Wrong collection name**: Make sure collection is `users` (lowercase)

