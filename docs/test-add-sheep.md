# Test Checklist: Add Sheep Flow

Run these checks after building the app.

## Setup
- [ ] Fresh install or cleared app data
- [ ] Logged in with Firebase email + password

## Add Sheep — Basic
- [ ] Tap FAB button on Sheep screen → Add Sheep screen opens
- [ ] "Name or number" field is required — saving with empty name shows error
- [ ] "Gender" dropdown shows male/female options
- [ ] Save a sheep with name only → appears in Sheep list
- [ ] Sheep card shows name, gender badge, health status, status badge

## Add Sheep — With Photo
- [ ] Tap photo area → bottom sheet shows Camera + Gallery options
- [ ] Take photo with camera → photo shows in form
- [ ] Choose from gallery → photo shows in form
- [ ] Save → sheep card shows the photo

## Add Sheep — With Purchase Price (Auto-link)
- [ ] Fill in name + purchase date + purchase price = 500
- [ ] Tap Save
- [ ] Sheep appears in Sheep Dashboard
- [ ] Switch to Money tab → expense row shows "شراء حيوان" for 500 دج
- [ ] Home tab History shows "تم شراء [name]" entry

## Auto-link in Single Transaction
- [ ] Simulate app kill after Save button pressed (don't actually kill, just verify)
- [ ] Both sheep AND expense appear together, or neither (no orphan records)

## Stats Update
- [ ] After adding active sheep → "الأغنام" count on Home Dashboard increases
- [ ] After adding sheep with price → "مصاريف الشهر" on Home increases
- [ ] Sheep Dashboard stats (Total, Active, Male/Female) update correctly

## Sync Status
- [ ] Newly added sheep has syncStatus = pending (check via Backup tab pending count)
- [ ] After "Backup Now" → pending count drops to 0
- [ ] Firestore console shows the animal under users/{uid}/animals
