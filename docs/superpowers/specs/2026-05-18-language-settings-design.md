# Language Settings — Design Spec
**Date:** 2026-05-18
**Feature:** Bilingual support (Arabic / French) with user-controlled language setting

---

## 1. Summary

Add a dedicated Settings tab (5th bottom-nav tab) with a two-button language toggle. Switching between Arabic and French takes effect immediately without restart. Arabic uses RTL layout; French uses LTR — the direction flips automatically. The selected language is persisted across app sessions via `shared_preferences`.

---

## 2. UI Design

### Settings screen
- **Tab**: 5th tab in bottom nav — icon: `Icons.settings`, label: `الإعدادات` / `Paramètres`
- **Language section**: Two full-width side-by-side buttons inside a card
  - Active language: green background, white text, checkmark
  - Inactive language: grey background, grey text
  - Sub-caption: "تغيير فوري" / "Changement immédiat"
- **Account section**: shows current user email + logout button (moved from app bar)
- **Version**: shown at bottom of screen

### Language switch behaviour
- Tap a button → locale updates instantly via Riverpod → `MaterialApp.router` rebuilds with new locale → all text and layout direction change
- No dialog, no confirmation, no restart

---

## 3. Localisation Architecture

### Tool: Flutter's official `flutter_localizations` + `flutter gen-l10n`

**Files created:**
```
lib/l10n/
  app_ar.arb       ← Arabic strings (template)
  app_fr.arb       ← French strings
  l10n.dart        ← extension: BuildContext.l10n shorthand
l10n.yaml          ← gen-l10n config
```

**Generated (not committed):**
```
lib/l10n/generated/
  app_localizations.dart
  app_localizations_ar.dart
  app_localizations_fr.dart
```

All user-visible strings extracted from every screen and widget into both ARB files. Category labels and dropdown values are included as ARB keys so they translate correctly.

### Locale state
```
lib/providers/language_provider.dart
```
- `languageProvider`: `StateNotifierProvider<LanguageNotifier, Locale>`
- On init: reads saved locale from `shared_preferences` (default: Arabic)
- On change: saves to `shared_preferences`, updates state → triggers rebuild

### App wiring (`lib/app.dart`)
```dart
MaterialApp.router(
  locale: ref.watch(languageProvider),
  supportedLocales: [Locale('ar'), Locale('fr')],
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  ...
)
```

---

## 4. New Screen

**`lib/screens/settings/settings_screen.dart`**
- Stateless `ConsumerWidget`
- Watches `languageProvider` to highlight active language
- Calls `ref.read(languageProvider.notifier).setLanguage(...)` on button tap
- Shows user email from `currentUserProvider`
- Logout button calls `firebaseAuthProvider.signOut()`

---

## 5. Files Modified

| File | Change |
|---|---|
| `pubspec.yaml` | Add `flutter_localizations`, `shared_preferences`; add `generate: true` |
| `l10n.yaml` | New — gen-l10n config |
| `lib/app.dart` | Add locale props to `MaterialApp.router`; add 5th Settings branch to `StatefulShellRoute` |
| `lib/screens/home/home_dashboard_screen.dart` | Replace hardcoded strings with `context.l10n.*` |
| `lib/screens/animals/sheep_dashboard_screen.dart` | Replace strings |
| `lib/screens/animals/add_edit_sheep_screen.dart` | Replace strings + dropdown values |
| `lib/screens/expenses/expenses_screen.dart` | Replace strings + category labels |
| `lib/screens/backup/backup_restore_screen.dart` | Replace strings; remove logout (moved to Settings) |
| `lib/screens/auth/login_screen.dart` | Replace strings |
| `lib/widgets/sheep_card.dart` | Replace gender/health/status labels |
| `lib/models/expense.dart` | Remove static `label()` method — labels now in ARB |

---

## 6. ARB Keys (representative sample)

```json
{
  "appTitle": "مزرعتي",
  "navHome": "الرئيسية",
  "navAnimals": "الحيوانات",
  "navMoney": "المال",
  "navBackup": "نسخ",
  "navSettings": "إعدادات",
  "loginEmail": "البريد الإلكتروني",
  "loginPassword": "كلمة المرور",
  "loginButton": "تسجيل الدخول",
  "sheepDashboardTitle": "الأغنام",
  "addSheepTitle": "إضافة خروف",
  "saveButton": "حفظ وإضافة",
  "genderMale": "♂ ذكر",
  "genderFemale": "♀ أنثى",
  "healthHealthy": "بصحة جيدة",
  "healthSick": "مريض",
  "healthPregnant": "حامل",
  "statusActive": "نشط",
  "statusSold": "مباع",
  "statusDead": "مات",
  "catAnimalPurchase": "شراء حيوان",
  "catAnimalFood": "علف",
  "catMedicine": "دواء",
  "backupTitle": "النسخ الاحتياطي",
  "backupNow": "رفع الآن",
  "restoreFromCloud": "استعادة من السحابة",
  "settingsTitle": "الإعدادات",
  "settingsLanguage": "اللغة",
  "settingsAccount": "الحساب",
  "settingsLogout": "تسجيل الخروج",
  "settingsVersion": "الإصدار",
  "languageChangeInstant": "تغيير فوري بدون إعادة تشغيل"
}
```

---

## 7. Dependencies Added

| Package | Purpose |
|---|---|
| `flutter_localizations` (SDK) | Locale delegates for Material widgets |
| `intl: ^0.19.0` | Already present — used by gen-l10n |
| `shared_preferences: ^2.3.2` | Persist selected language across sessions |

---

## 8. Out of Scope

- More than 2 languages
- Per-screen language override
- Language detection from device locale (always defaults to Arabic)
