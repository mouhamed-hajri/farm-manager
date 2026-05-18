# Firebase Setup Guide

## Step 1: Create Firebase Project

1. Go to https://console.firebase.google.com
2. Click "Add project"
3. Name: `farm-manager` (or any name you like)
4. Disable Google Analytics (optional for MVP)
5. Click "Create project"

## Step 2: Register Android App

1. In the Firebase project, click the Android icon
2. Android package name: `com.example.farm_manager`
3. App nickname: `مزرعتي`
4. Click "Register app"
5. Download `google-services.json`
6. Place it at: `android/app/google-services.json`
   ⚠️ This file is in .gitignore — do not commit it

## Step 3: Enable Authentication

1. In Firebase console → Authentication → Get started
2. Sign-in method → Email/Password → Enable → Save
3. Add a user: Authentication → Users → Add user
   - Email: (your email)
   - Password: (a strong password)

## Step 4: Create Firestore Database

1. Firestore Database → Create database
2. Choose "Start in production mode"
3. Select a location close to you (e.g., `europe-west1`)
4. Click Done

## Step 5: Apply Security Rules

1. Firestore → Rules
2. Replace everything with the contents of `FIRESTORE_RULES.txt`
3. Click "Publish"

## Step 6: Enable Storage

1. Storage → Get started
2. Choose "Start in production mode"
3. Select the same location as Firestore
4. Apply these rules in Storage → Rules:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

## Step 7: Verify

Run the app, log in with the user you created, add a sheep, tap Backup Now.
Check Firestore console — you should see the data under `users/{uid}/animals`.
