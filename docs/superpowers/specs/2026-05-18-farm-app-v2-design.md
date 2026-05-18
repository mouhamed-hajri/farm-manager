# Farm App v2 — Design

**Date:** 2026-05-18
**Status:** Approved, ready for implementation
**Audience:** Solo dev (user) building for their father in Tunisia
**Existing data:** None (pre-launch, can wipe DB)

## 1. Goal

Upgrade the current sheep-only Flutter/Firebase app ("Ma Ferme" / "مزرعتي") into a full farm management app covering animals (multi-species, expandable), crops, fields (with rental tracking), expenses, sales, reports, and reminders. Must remain offline-first, bilingual (French/Arabic with RTL), and simple enough for a non-technical user.

## 2. Architecture (unchanged)

- **Flutter** (Material 3, RTL-aware)
- **Riverpod** (state)
- **go_router** (navigation)
- **Drift** (local SQLite, schema v2 — drop & recreate)
- **Firebase Auth** (per-user isolation via UID)
- **Cloud Firestore** (mirror under `users/{uid}/{collection}`)
- **Cloudinary** (photo storage — already wired, no Firebase Storage)
- **Workmanager** (background sync, daily)
- **flutter_local_notifications** (NEW — for reminders)
- **intl** + ARB files (FR + AR localization)

### Multi-tenancy

Each Firebase Auth user gets a fully isolated farm. All Drift queries filter by `userId`; Firestore paths are `users/{uid}/...`. Sharing a single farm between accounts is out of scope for v2.

## 3. Data Model

All tables include: `id` (uuid), `userId`, `createdAt`, `updatedAt`, `syncStatus` (pending/synced/failed).

### 3.1 `species`

User-managed list of animal kinds.

| Field | Type | Notes |
|---|---|---|
| nameFr | text | "Moutons", "Vaches", "Chèvres" |
| nameAr | text | Arabic name |
| iconEmoji | text | "🐑", "🐄", "🐐" |
| idPrefix | text(3) | Uppercase, e.g., "MOU", "VAC". Unique across user's species. Auto-suggested from `nameFr[:3].toUpperCase()` but editable. |
| isDefault | bool | True for seeded Moutons/Vaches |

**Seed:** Moutons (MOU, 🐑), Vaches (VAC, 🐄).

### 3.2 `animals`

Replaces current `animals` table.

| Field | Type | Notes |
|---|---|---|
| speciesId | text | FK → species.id |
| farmId | text | **Generated, immutable**: `PREFIX-YEAR-NNNN` (e.g., `MOU-2026-0001`). Unique per user. |
| nickname | text? | Optional human name |
| gender | text | male/female |
| birthDate | text? | ISO date |
| breed | text? | |
| color | text? | |
| weight | real? | kg |
| healthStatus | text | healthy/sick/pregnant (default healthy) |
| status | text | active/sold/dead (default active) |
| purchaseDate | text? | |
| purchasePrice | real? | TND |
| sellerName | text? | |
| sellerPhone | text? | |
| purchaseLocation | text? | |
| photoLocalPath | text? | |
| photoCloudUrl | text? | Cloudinary URL |
| motherId | text? | FK → animals.id (null if bought, not bred) |
| fatherId | text? | FK → animals.id |
| deathDate | text? | Set when status=dead |
| deathCause | text? | |
| deathNotes | text? | |
| notes | text? | |

### 3.3 `farm_id_counters`

Tracks the last-used number per (prefix, year).

| Field | Type |
|---|---|
| prefix | text |
| year | int |
| lastNumber | int |

Primary key: `(userId, prefix, year)`. Incremented atomically in a Drift transaction when an animal is inserted. Never decremented (deleted/sold/dead animals keep their ID).

### 3.4 `fields`

Plots of land. NEW.

| Field | Type | Notes |
|---|---|---|
| name | text | "Champ 1", "Terrain Sud" |
| areaText | text? | Free text: "5 hectares" / "2000 m²" |
| locationText | text? | |
| ownership | text | owned/rented |
| photoLocalPath | text? | |
| photoCloudUrl | text? | |
| rentAmount | real? | TND |
| rentPeriod | text? | month/year/total |
| rentStartDate | text? | ISO date |
| rentEndDate | text? | ISO date |
| landlordName | text? | |
| landlordPhone | text? | |
| notes | text? | |

### 3.5 `crops`

Crops/trees/products. Replaces nothing (new entity).

| Field | Type | Notes |
|---|---|---|
| nameFr | text | "Oranges", "Patates", "Olives", "Tomates" |
| nameAr | text | |
| iconEmoji | text? | "🍊", "🥔", "🫒", "🍅" |
| kind | text | tree/crop/vegetable/other |
| seasonMonths | text | JSON array of months 1–12. Empty list = year-round. |
| fieldId | text? | FK → fields.id (optional) |
| areaOrCountText | text? | Free text: "200 arbres" or "1 hectare" |
| photoLocalPath | text? | |
| photoCloudUrl | text? | |
| notes | text? | |

**Seed:** Oranges (🍊, tree, season=Nov–Mar), Patates (🥔, vegetable, season=12 months), Olives (🫒, tree, season=Oct–Dec), Tomates (🍅, vegetable, season=Jun–Sep).

### 3.6 `expenses` (extended)

Adds scope-aware categorization.

| Field | Type | Notes |
|---|---|---|
| scope | text | animal / crop / field / general |
| linkedAnimalId | text? | FK → animals.id when scope=animal and user picked a specific animal |
| linkedSpeciesId | text? | FK → species.id when scope=animal (always set for animal expenses) |
| linkedCropId | text? | FK → crops.id when scope=crop |
| linkedFieldId | text? | FK → fields.id when scope=field |
| amount | real | TND |
| date | text | ISO date |
| category | text | scope-specific (see below) |
| description | text? | |
| receiptPhotoLocalPath | text? | Already in current schema |
| receiptPhotoCloudUrl | text? | Already in current schema |

**Animal categories:** food, medicine, veterinary, vaccination, transport, worker_salary, other
**Crop categories:** seeds, fertilizer, water, pesticide, worker_salary, transport, equipment, other
**Field categories:** rent_payment, maintenance, other
**General categories:** fuel, tools, repair, electricity, rent (farm rent), other

### 3.7 `sales`

NEW. Unified for all income.

| Field | Type | Notes |
|---|---|---|
| scope | text | animal / crop / product / other |
| linkedAnimalId | text? | FK → animals.id |
| linkedCropId | text? | FK → crops.id |
| productName | text? | "Lait", "Œufs", "Laine", or any custom for scope=other |
| quantity | real | |
| unit | text | kg / grande_caisse / petite_caisse / piece / litre |
| unitPrice | real | TND per unit |
| totalPrice | real | quantity × unitPrice (auto-computed, stored) |
| buyerName | text? | |
| buyerPhone | text? | |
| saleDate | text | ISO date (default today) |
| receiptPhotoLocalPath | text? | NEW |
| receiptPhotoCloudUrl | text? | NEW |
| notes | text? | |

**Animal sale transaction:** when scope=animal, creating the sale in a Drift transaction also flips the animal's `status` to `sold` and logs an `animal_sold` activity entry. For animals, `quantity=1`, `unit=piece` (hidden in UI).

### 3.8 `reproduction_events`

NEW. Tracks matings, pregnancies, births.

| Field | Type | Notes |
|---|---|---|
| animalId | text | The mother (or for `mating` event, the female participant) |
| eventType | text | mating / pregnancy_confirmed / birth |
| partnerId | text? | The male partner (FK → animals.id), if known |
| eventDate | text | ISO date |
| dueDate | text? | Set on pregnancy_confirmed |
| offspringCount | int? | Set on birth |
| notes | text? | |
| pregnancyGroupId | text? | UUID grouping mating→pregnancy_confirmed→birth events for one pregnancy. Auto-generated when the user starts a new pregnancy. |

**Offspring creation:** on a `birth` event, the user can tap "Créer les jeunes" → form pre-fills speciesId = mother's species, motherId = this animal, fatherId = partnerId. Each baby gets a new farm_id from the counter.

### 3.9 `health_events`

NEW. Powers the Health tab.

| Field | Type | Notes |
|---|---|---|
| animalId | text | FK → animals.id |
| eventType | text | treatment / vaccination / illness / recovery |
| description | text | |
| date | text | ISO date |
| vetName | text? | |
| nextDueDate | text? | For vaccinations with a follow-up date |
| notes | text? | |

### 3.10 `reminders`

NEW. Auto-generated only — no manual reminders in v2.

| Field | Type | Notes |
|---|---|---|
| title | text | "Contrat de location" |
| body | text | "Le contrat de [Champ 1] expire dans 30 jours. Appeler [landlord] au [phone]." |
| triggerDate | text | ISO date |
| category | text | rent_expiry / pregnancy_due / vaccination_due |
| linkedType | text? | field / animal |
| linkedId | text? | |
| isDone | bool | Marked true when user dismisses or the date passes |
| platformNotificationId | int? | The integer ID used by flutter_local_notifications, so we can cancel/reschedule |

**Reminder lifecycle:**
- Created automatically when:
  - A field is saved with `ownership=rented` and `rentEndDate` set → 3 reminders (30/7/0 days before expiry)
  - A `pregnancy_confirmed` event is saved with `dueDate` → 1 reminder, 7 days before
  - A `health_event` is saved with `eventType=vaccination` and `nextDueDate` → 1 reminder on that date
- Scheduled with `flutter_local_notifications.zonedSchedule()`
- If the source row is edited (e.g., rent end date changed), all related reminders are cancelled and rescheduled
- If the source row is deleted, related reminders are cancelled

### 3.11 `history` (extended — keeps current table name)

The existing `history` table stays. We just add new action types to the `actionType` column (it's a free-text field). No schema change. UI calls it "Activités récentes" / "Historique" in French. New action types:

`animal_added, animal_sold, animal_died, animal_offspring_created, expense_added, sale_added, crop_added, crop_sold, field_added, field_rent_set, species_added, reproduction_logged, health_logged, vaccination_logged, backup_completed, restore_completed`

### 3.12 `settings`

NEW. Single row per user.

| Field | Type | Notes |
|---|---|---|
| language | text | fr / ar (default fr) |
| currency | text | Default TND |
| mode | text | simple / advanced (default simple) |
| lastBackupDate | text? | ISO |

## 4. Farm-ID Generation

```dart
Future<String> generateFarmId(String userId, String speciesPrefix) async {
  final year = DateTime.now().year;
  return await transaction(() async {
    final existing = await (select(farmIdCounters)
          ..where((t) =>
              t.userId.equals(userId) &
              t.prefix.equals(speciesPrefix) &
              t.year.equals(year)))
        .getSingleOrNull();
    final next = (existing?.lastNumber ?? 0) + 1;
    await into(farmIdCounters).insertOnConflictUpdate(FarmIdCountersCompanion(
      userId: Value(userId),
      prefix: Value(speciesPrefix),
      year: Value(year),
      lastNumber: Value(next),
    ));
    return '$speciesPrefix-$year-${next.toString().padLeft(4, '0')}';
  });
}
```

- Called from animal repository's `insert()`.
- In the "Add animal" form, the field shows `MOU-2026-XXXX` placeholder until species is picked, then a **preview** (counter+1 without incrementing) — final ID locked on save.
- Counters table is synced to Firestore so reinstall + restore keeps counter continuity.

## 5. Screens & Navigation

Bottom nav (5 tabs):

### 5.1 Accueil
- Header: greeting + month name
- Stat cards (2-col grid):
  - Animaux actifs (total + breakdown by species expandable)
  - Vendus ce mois
  - Morts ce mois
  - Dépenses ce mois (TND)
  - Revenus ce mois (TND)
  - Bénéfice / Perte ce mois (TND, green/red)
  - Champs (count + count rented)
- Quick action buttons row: + Animal · + Dépense · + Vente · Sauvegarder
- Activités récentes (last 15 activity_log entries)

### 5.2 Animaux
- Top: grid of species cards (emoji, FR name, AR subtitle, active count). Last card is "+" to add a new species.
- Tap species → species screen:
  - **Top stats bar** for this species: Actifs (count), Vendus (lifetime), Morts (lifetime), Dépensé (TND, all-time), Gagné (TND, all-time), Bénéfice/Perte (color-coded).
  - Filter chips: Actifs (default), Vendus, Morts (each toggles the visible section)
  - Body: scrollable list. Active animals always shown. Below, two collapsed sections "Animaux vendus" and "Animaux morts" that expand on tap.
  - FAB "+" → add new animal of this species
- Tap animal → profile page with tabs:
  - **Résumé:** photo (with "Changer la photo" button), farm_id, nickname, sex, age (computed from birthDate), breed, weight, health status, parents (if set, tap to view), purchase info, current status. Action buttons: Modifier · Vendre · Marquer décédé · Supprimer.
  - **Dépenses:** list of expenses linked to this animal (sum at top)
  - **Santé:** list of `health_events`. FAB to add new event.
  - **Reproduction:** (only if female) Groups events by `pregnancyGroupId`. Each group is a card: mating date, partner, due date, birth date, offspring count, horizontal scroll of offspring cards (tap → profile). FAB to add new event.
  - **Photos:** photo gallery (currently just the main photo; v2 single-photo per animal — gallery expansion possible later)
  - **Historique:** activity_log filtered for this animal

### 5.3 Cultures
- Segmented control: **Champs / Cultures**
- **Champs** tab: list of fields. Each card shows: name, photo thumbnail, ownership badge (Possédé / Loué), if rented: rent expiry countdown ("expire dans 45 jours") in orange/red based on proximity. FAB "+" to add.
  - Tap field → detail: photo (changeable), area, location, ownership info, if rented: full rent contract, list of crops on this field, expenses linked to field (sum), total profit/loss.
- **Cultures** tab: list of crops. Each card shows: photo, FR name, AR subtitle, season indicator (e.g., "Saison: Nov–Mar" or "Toute l'année"), field link if set, total profit-to-date for current year.
  - FAB "+" to add custom crop.
  - Tap crop → detail with tabs: Résumé (photo, season, field, area/count, notes) · Dépenses · Ventes · Photos

### 5.4 Finances
Segmented control: **Dépenses / Ventes / Rapports**

- **Dépenses** tab:
  - Filter chips by scope (Toutes / Animaux / Cultures / Champs / Général) and date range (mois actuel default)
  - List sorted by date desc
  - FAB "+" → add expense form: scope picker → category picker → amount + date + notes + optional photo + optional links (animal/crop/field)
- **Ventes** tab:
  - Filter chips by scope and date range
  - List
  - FAB "+" → add sale form: scope picker → form fields per scope, with unit picker for crop/product (default Grande caisse for crop)
- **Rapports** tab:
  - Date range picker: Aujourd'hui / Cette semaine / Ce mois / Cette année / Personnalisé
  - Renders:
    - Totaux: Dépenses, Revenus, Bénéfice/Perte
    - Dépenses par catégorie: animal, crop, field, general (bar chart-ish, can be simple list)
    - Revenus par catégorie: animal, crop, product
    - Bénéfice par espèce (for each species: spent, earned, profit)
    - Bénéfice par culture
    - Bénéfice par champ
    - Top 5 catégories de dépenses
    - Liste des transactions récentes

### 5.5 Plus (settings)
- Espèces (CRUD list)
- Cultures (CRUD list of crop types)
- Catégories de dépenses (read-only list, future: custom categories)
- Langue (FR / AR toggle)
- Devise (default TND, dropdown of common currencies)
- Mode (Simple / Avancé toggle)
- Sauvegarde & restauration (existing screen, refined)
- Compte (sign out)
- À propos

## 6. Simple vs Advanced Mode

Simple mode hides these fields on forms (they remain in DB, just not shown):

- Animal form: weight, color, sellerPhone, purchaseLocation, breed
- Crop form: areaOrCountText, fieldId (auto-blank)
- Expense form: receipt photo, description
- Sale form: buyerPhone, receipt photo

Advanced mode shows everything. Toggle is in Plus → Mode.

## 7. Photos

- Single photo per entity (animal, crop, field, expense receipt, sale receipt). Future: multi-photo gallery if requested.
- Capture flow: image_picker (camera or gallery) → flutter_image_compress → save to app docs dir → store local path immediately → on next sync, upload to Cloudinary, save URL, delete local file (or keep cached).
- Replace flow: every photo widget has a "Changer la photo" overlay button → same picker → overwrites local path, schedules re-upload, replaces cloud URL after sync.

## 8. Sync

- Existing pattern: each entity has `syncStatus` (pending/synced). `SyncService.syncPending()` uploads pending rows to Firestore and pulls cloud changes back.
- Extended to handle: species, fields, crops, sales, reproduction_events, health_events, reminders, farm_id_counters, settings.
- Conflict resolution: last-write-wins by `updatedAt`.
- Daily background sync via Workmanager (already wired).
- Restore: pulls all collections under `users/{uid}/`, inserts into local DB with `syncStatus=synced`. Counters restored — next animal continues numbering correctly.

## 9. Reminders (flutter_local_notifications)

- Init in `main()`: request POST_NOTIFICATIONS permission on Android 13+; init the plugin with appropriate channel ("farm_reminders" channel, importance=high).
- A central `ReminderService`:
  - `scheduleRentReminders(Field f)` — cancels existing, schedules 3 new at 30/7/0 days before `rentEndDate` at 09:00 local. Stores rows in `reminders` table.
  - `schedulePregnancyReminder(ReproductionEvent e)` — 7 days before `dueDate` at 09:00.
  - `scheduleVaccinationReminder(HealthEvent e)` — on `nextDueDate` at 09:00.
  - `cancelForLinkedRow(type, id)` — cancels all platform notifs whose `linkedType`/`linkedId` matches; marks DB rows done.
- Called from repositories after insert/update/delete on the source entity.

## 10. Localization

- All UI strings in `.arb` files (FR + AR).
- Existing `app_localizations_fr.dart`/`_ar.dart` already generated. Will add ~200 new strings.
- RTL: `MaterialApp.locale` already drives `Directionality`; new widgets use logical paddings (`EdgeInsetsDirectional`), not left/right.
- Date formatting uses `intl` with the active locale.

## 11. Currency

- Stored as raw number (real, TND). Displayed using `NumberFormat.currency(locale: ..., symbol: 'TND ')`.
- User-changeable in settings, but stored values are not converted (no FX). Changing currency just changes display.

## 12. Out of scope for v2

- Manual user-defined reminders (skill says yes to auto-only)
- Multi-account farm sharing
- Multi-photo galleries per entity
- Custom expense/sale categories (categories are hardcoded enums)
- Custom units beyond the 5 listed
- Cloud Functions / FCM-pushed reminders (local only)
- iOS support (Android-only build target stays)
- Tree-by-tree tracking (groups only)

## 13. Implementation phases (single PR, built in order)

1. Schema v2 + new tables + species seed + auto-ID system
2. Animals: species grid, profile tabs (Résumé, Photos, Historique), sold/dead sections, photo replace
3. Fields entity (CRUD + rent UI)
4. Crops entity (CRUD + field link)
5. Expenses overhaul (scope picker + scope-specific categories)
6. Sales entity (unified, with animal-sale-flips-status transaction, receipt photo)
7. Health events + Reproduction events (full pregnancy/offspring linkage)
8. Reminders (notification plumbing + 3 auto categories)
9. Reports page
10. Dashboard rebuild + new activity log types
11. Settings (species/crops/categories/language/currency/mode)
12. Localization strings (FR + AR) for all new UI
13. Build APK, install on emulator, run the 11-step smoke test:
    1. Add a sheep, 2. Add a cow, 3. Add a custom species,
    4. Add an animal expense, 5. Sell an animal,
    6. Check sold-animals collapsed section,
    7. Add an orange crop, 8. Add a crop expense,
    9. Add an orange sale, 10. Check report profit/loss,
    11. Backup and restore (verify counters restored, IDs continue).

## 14. Cross-cutting requirements

### 14.1 Farm-ID visibility
The generated `farm_id` (e.g., `MOU-2026-0001`) is shown prominently on:
- Animal list cards (large, top-left, monospace)
- Animal profile header (large, alongside nickname if set)
- Expense rows when `linkedAnimalId` is set (small badge)
- Sale rows when `scope=animal` (small badge)
- Reports tables (column or inline label)
- Activity log entries that reference an animal

### 14.2 Form validation
All forms validate before save:
- **Required fields**: species (animal), name (species/crop/field), amount (expense/sale), date (any date field), unit + quantity + unitPrice (sale)
- **Numeric**: prices ≥ 0, quantity > 0, weight > 0 if set
- **Dates**: not in the future (except rent_end_date, due_date, vaccination next_due_date)
- **Species idPrefix**: must be 3 uppercase letters, must be unique per user — duplicates rejected inline
- Validation errors render under the field in red; save button stays disabled until all errors clear

### 14.3 Edit / delete confirmation
- Every detail page has **Modifier** and **Supprimer** actions.
- Delete shows a confirmation dialog: "Êtes-vous sûr de vouloir supprimer [X] ? Cette action est irréversible." → Annuler / Supprimer.
- Deleting an animal does NOT free its `farm_id` (counter never decrements).
- Deleting a row cancels any related reminders (rent / pregnancy / vaccination).
- Deleting a species is blocked if any animals reference it ("Impossible : N animaux utilisent cette espèce.").
- Deleting a field is blocked if any crops reference it.

### 14.4 Search (deferred but flagged)
The user spec mentions farm_id in "search results". v2 includes a simple search box on the Animaux screen that filters the active species's animal list by `farm_id` or `nickname` (live, client-side). Global search across all entities is deferred to v3.

### 14.5 Backup screen
Existing screen already has: last backup date, pending count, manual backup button, restore button with confirmation dialog, conflict-free restore via `insertOnConflictUpdate`. Auto-backup runs daily via Workmanager. v2 extends `restoreFromCloud()` to handle all new tables (species, fields, crops, sales, reproduction_events, health_events, reminders, farm_id_counters, settings) and re-schedules local reminders after restore.

### 14.6 Why I added "field" as a 4th expense scope
Your original spec listed 3 scopes (animal / crop / general). I added **field** so rent payments and field maintenance can be tracked per-field, and reports can show profit/loss per field. If you prefer, field expenses can fold into "general" with a free-text note instead — but that loses the per-field reporting. Flag this if you want it changed.

## 15. Verification

- After each phase: `flutter analyze` must be clean.
- After phase 13: `flutter build apk --release` must succeed; APK must install on emulator-5554 and launch without crashing; all 11 smoke-test steps must pass.

## 16. Open questions

None — all clarified in brainstorming session 2026-05-18, with one flagged decision in §14.6 (field as 4th expense scope) for confirmation.
