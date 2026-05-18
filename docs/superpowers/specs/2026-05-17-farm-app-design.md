# Farm Management App — MVP Design Spec
**Date:** 2026-05-17
**Milestone:** 1 (MVP)
**Approach:** Milestone-by-milestone (Option A)

---

## 1. Project Summary

A production-quality Android farm management app for personal/family use. Built with Flutter, targeting Android 8+. Distributed as a manually-installed APK — no Google Play Store required. The app is offline-first: all data is saved locally immediately, then synced to Firebase when internet is available.

The primary user is an older farmer. The UI must use big buttons, large text, clean cards, and minimal typing.

---

## 2. Technology Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Local database | Drift (SQLite) |
| Cloud database | Firebase Firestore |
| Authentication | Firebase Auth (email + password) |
| Photo storage | Firebase Storage |
| State management | Riverpod |
| Navigation | go_router |
| Background sync | workmanager |
| Photo compression | flutter_image_compress |
| Connectivity detection | connectivity_plus |
| Android target | Android 8+ (API 26+) |

---

## 3. Architecture

```
┌─────────────────────────────────────────────────┐
│                  Flutter UI Layer                │
│         Screens + Widgets (go_router nav)        │
└──────────────────────┬──────────────────────────┘
                       │ watches
┌──────────────────────▼──────────────────────────┐
│              Riverpod Providers                  │
│     (state management, business logic)           │
└──────────────────────┬──────────────────────────┘
                       │ calls
┌──────────────────────▼──────────────────────────┐
│              Repository Layer                    │
│   AnimalRepo  ExpenseRepo  BackupRepo  etc.      │
└────────────┬──────────────────────┬─────────────┘
             │                      │
┌────────────▼──────┐   ┌───────────▼─────────────┐
│   Local (Drift)   │   │   Firebase               │
│   SQLite on phone │   │   Firestore + Auth +     │
│   Always written  │   │   Storage                │
│   first           │   │   Sync when online       │
└───────────────────┘   └─────────────────────────┘
                       ▲
┌──────────────────────┴──────────────────────────┐
│              Sync Service (background)           │
│  Triggers: connectivity change + daily timer     │
│  Uploads pending records, downloads on restore   │
└─────────────────────────────────────────────────┘
```

**Key principle:** Every write goes to Drift first (instant, offline-safe), marked `syncStatus: pending`. The sync service picks up pending records and pushes to Firebase when online. If the app is reinstalled, login triggers a full restore from Firestore.

---

## 4. Project Folder Structure

```
lib/
├── main.dart
├── app.dart                    # App root, router setup
├── theme/
│   └── app_theme.dart
├── models/
│   ├── animal.dart
│   ├── expense.dart
│   └── history_entry.dart
├── database/
│   ├── app_database.dart       # Drift database definition
│   └── tables/
│       ├── animals_table.dart
│       ├── expenses_table.dart
│       └── history_table.dart
├── repositories/
│   ├── animal_repository.dart
│   ├── expense_repository.dart
│   └── history_repository.dart
├── services/
│   ├── firebase_service.dart
│   ├── storage_service.dart
│   ├── sync_service.dart
│   └── photo_service.dart
├── providers/
│   ├── animal_provider.dart
│   ├── expense_provider.dart
│   └── sync_provider.dart
├── screens/
│   ├── auth/
│   │   └── login_screen.dart
│   ├── home/
│   │   └── home_dashboard_screen.dart
│   ├── animals/
│   │   ├── sheep_dashboard_screen.dart
│   │   └── add_edit_sheep_screen.dart
│   ├── expenses/
│   │   └── expenses_screen.dart
│   └── backup/
│       └── backup_restore_screen.dart
└── widgets/
    ├── stat_card.dart
    ├── sheep_card.dart
    └── big_button.dart
```

---

## 5. Data Models

### Animals Table
```
id               TEXT PRIMARY KEY  (UUID)
userId           TEXT              (Firebase auth uid)
type             TEXT              (sheep, cow, goat, chicken, rabbit, other)
nameOrNumber     TEXT
gender           TEXT              (male, female)
breed            TEXT
color            TEXT
birthDate        TEXT              (ISO 8601 date string)
weight           REAL
healthStatus     TEXT              (healthy, sick, pregnant)
status           TEXT              (active, sold, dead)
purchaseDate     TEXT
purchasePrice    REAL
sellerName       TEXT
sellerPhone      TEXT
purchaseLocation TEXT
photoLocalPath   TEXT
photoCloudUrl    TEXT
notes            TEXT
createdAt        TEXT
updatedAt        TEXT
syncStatus       TEXT              (pending, synced, failed)
```

### Expenses Table
```
id               TEXT PRIMARY KEY
userId           TEXT
amount           REAL
category         TEXT              (animal_purchase, animal_food, medicine,
                                   veterinary, seeds, fertilizer, water,
                                   tools, transport, worker_payment,
                                   maintenance, other)
date             TEXT
relatedType      TEXT              (animal, crop, tree_project, product, general)
relatedId        TEXT
description      TEXT
receiptPhotoLocalPath TEXT
receiptPhotoCloudUrl  TEXT
createdAt        TEXT
updatedAt        TEXT
syncStatus       TEXT
```

### History Table
```
id               TEXT PRIMARY KEY
userId           TEXT
actionType       TEXT              (sheep_bought, sheep_sold, sheep_dead,
                                   expense_added, income_added,
                                   backup_completed, restore_completed)
title            TEXT
description      TEXT
relatedType      TEXT
relatedId        TEXT
date             TEXT
createdAt        TEXT
syncStatus       TEXT
```

---

## 6. Auto-Linking Rules

When a sheep is saved with `purchasePrice > 0`:
1. AnimalRepository saves the sheep record to Drift (syncStatus: pending)
2. AnimalRepository calls ExpenseRepository to insert an expense:
   - `category: animal_purchase`
   - `amount: sheep.purchasePrice`
   - `date: sheep.purchaseDate`
   - `relatedType: animal`
   - `relatedId: sheep.id`
   - `description: "Purchase of [sheep name/number]"`
3. HistoryRepository inserts a history entry: "Sheep [name] was bought for [price]"
4. Riverpod providers are invalidated → dashboards refresh automatically

The farmer never manually creates the expense. It is created in a single database transaction so both records succeed or both fail together.

**Note on history entries:** History records are insert-only — they are never updated after creation, so no conflict resolution is needed for the history table. The `updatedAt` conflict rule applies only to animals and expenses.

---

## 7. Firebase Structure

### Firestore
```
users/
  {userId}/
    animals/      {animalId}    → mirrors local animals table
    expenses/     {expenseId}   → mirrors local expenses table
    history/      {historyId}   → mirrors local history table
    settings/
      appSettings               → lastBackupDate, appVersion
```

### Firebase Storage
```
users/{userId}/animals/{animalId}/photo.jpg
users/{userId}/receipts/{expenseId}/receipt.jpg
```

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

---

## 8. Sync Strategy

### Write flow (offline-first)
1. User performs action → data written to Drift immediately with `syncStatus: pending`
2. UI updates instantly from local data
3. SyncService detects pending records → uploads to Firestore → marks `synced`
4. If upload fails: `syncStatus` stays `pending`, retried next sync cycle

### Sync triggers
- Connectivity change detected (offline → online) via `connectivity_plus`
- Daily background job via `workmanager` (user-configurable, default: every 24h). **Note:** Android 8+ battery optimization may delay background jobs. The app will prompt the user once to disable battery optimization for reliable daily sync.
- Manual "Backup Now" button press

### Restore flow (after reinstall)
1. User installs APK → opens app → logs in with Firebase email/password
2. App detects empty local database
3. App downloads all Firestore documents for `userId` → inserts into Drift
4. Photo local paths are empty; cloud URLs are restored — photos load from Firebase Storage on demand
5. App shows "Restore complete — [N] records restored"

### Conflict resolution
- `updatedAt` timestamp wins: newest record is kept
- Cloud data is **never deleted automatically** unless the user explicitly confirms

### Photo handling
- Photos are captured/selected locally first
- Compressed to max 1024px / ~200KB using `flutter_image_compress` before upload
- Both `photoLocalPath` (device) and `photoCloudUrl` (Firebase) are stored
- After restore: `photoLocalPath` is empty, `photoCloudUrl` is populated. The image widget checks local path first; if empty or file missing, it falls back to `photoCloudUrl` from Firebase Storage. No manual re-download needed.

---

## 9. Screen Flow (MVP)

```
App Launch
    │
    ▼
Login Screen (Firebase Auth — email + password)
    │
    ▼
Home Dashboard
    ├── Stat cards: total sheep, expenses this month, income, pending sync count
    ├── Latest history entries
    └── Bottom navigation: Home | Animals | Money | Backup

Animals Tab
    └── Sheep Dashboard
            ├── Stats: total, active, sold, dead, males, females
            ├── Search + filter bar
            ├── Grid/list of sheep cards (photo, name, gender, age, status)
            └── [+ Add Sheep] FAB button
                    └── Add Sheep Screen
                            ├── Photo (camera or gallery)
                            ├── Name or number (required)
                            ├── Gender dropdown (required)
                            ├── Purchase date (date picker)
                            ├── Purchase price
                            ├── Seller name, phone, location
                            ├── Age / birth date
                            ├── Weight, breed, color
                            ├── Health status dropdown
                            └── Notes
                            └── [Save] → auto-creates expense + history

Money Tab
    └── Expenses Screen
            ├── Total expenses, this month
            ├── Filter by category / date
            └── Expenses list (amount, category, date, linked animal)

Backup Tab
    └── Backup & Restore Screen
            ├── Last backup date
            ├── Sync status (synced / pending / failed)
            ├── Pending changes count
            ├── [Backup Now] button
            └── [Restore from Cloud] button
```

---

## 10. UI Principles

- Minimum tap target height: **56px**
- Base font size: **16px**, key numbers: **20px+**
- Color system: Green = income/healthy, Red = expense/sick/dead, Blue = neutral
- All category inputs: dropdown (no free typing)
- All date inputs: date picker
- Empty states: clear message + large action button
- Loading states: spinner + short text message
- Error states: red banner + retry button
- No crashes on missing internet — all errors caught and shown gracefully

---

## 11. APK Build & Distribution

### Build commands
```bash
# Debug APK (for testing)
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Release APK (for daily use, signed)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Manual installation steps (for dad's phone)
1. Build the APK on development machine
2. Copy APK to phone via USB cable, WhatsApp, or email
3. On phone: Settings → Security → Enable "Install from unknown sources"
4. Open the APK file on the phone → tap Install
5. Open app → login with Firebase email/password
6. If reinstalling after data loss: login automatically triggers cloud restore

### Release signing
A `keystore.jks` file and `key.properties` file will be generated and configured locally. These files must not be committed to git (added to `.gitignore`).

---

## 12. Deliverables

| File | Purpose |
|---|---|
| `README.md` | Full project setup guide |
| `FIREBASE_SETUP.md` | Step-by-step Firebase project creation |
| `INSTALL.md` | How to build and install the APK |
| `FIRESTORE_RULES.txt` | Ready-to-paste security rules |
| `docs/test-add-sheep.md` | Test checklist for add sheep flow |
| `docs/test-restore.md` | Test checklist for delete + restore flow |

---

## 13. MVP Acceptance Criteria

The MVP is complete when this full flow works end-to-end:

1. Open app on fresh install
2. Login with Firebase email + password
3. Tap Add Sheep
4. Take or choose a photo
5. Enter sheep details including purchase price
6. Tap Save
7. Sheep appears in Sheep Dashboard
8. Expense appears automatically in Expenses screen (category: Animal Purchase)
9. Home Dashboard numbers update
10. Tap "Backup Now" → data uploads to Firebase
11. Delete and reinstall the app
12. Login with same credentials
13. All sheep and expense data is restored from Firebase
14. Sheep photo loads from Firebase Storage URL

---

## 14. Out of Scope (Milestone 1)

The following are deferred to Milestone 2 and 3:
- Selling sheep / marking as dead
- Sheep profile page
- Crops module
- Tree projects module
- Products and stock module
- Reminders
- Income module
- Other animal types (cows, goats, chickens)
- Arabic / French localization
- PIN code lock
