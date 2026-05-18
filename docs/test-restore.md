# Test Checklist: Delete & Restore Flow

## Setup
- [ ] App installed and logged in
- [ ] At least 3 sheep added, each with purchase price
- [ ] "Backup Now" completed successfully (pending count = 0)
- [ ] Note the number of sheep and expenses shown

## Delete App Data
- [ ] On Android: Settings → Apps → مزرعتي → Storage → Clear Data
  OR uninstall and reinstall the APK

## Restore Flow
- [ ] Open app → Login screen appears (not home screen)
- [ ] Login with same Firebase email + password
- [ ] App shows Home Dashboard (empty — local DB is clear)
- [ ] Go to Backup tab → tap "Restore from Cloud"
- [ ] Confirmation dialog appears → tap Restore
- [ ] Progress indicator shows while downloading
- [ ] Success message: "تمت الاستعادة: N حيوان، N مصروف"

## Verify Data
- [ ] Sheep count on Home Dashboard matches pre-delete count
- [ ] Go to Animals tab → all sheep appear in list
- [ ] Each sheep card shows correct name, gender, status
- [ ] Go to Money tab → all expenses appear
- [ ] Expense amounts match what was entered before

## Photo Restore
- [ ] Sheep with photo: local path is now empty, but photo loads from Firebase Storage URL
- [ ] Image widget does not show error/broken icon
- [ ] Photo loads when scrolling through list (may take a moment on slow connection)

## History
- [ ] History entries visible on Home tab after restore
- [ ] Backup Completed entry appears in history list

## Edge Cases
- [ ] Restore with no internet → error message shown (not a crash)
- [ ] Restore with empty Firestore (brand new account) → "0 records restored" message
