# 🏗️ Architecture Visualization

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       ASTATINE APP                              │
│                   (Flutter Application)                         │
└─────────────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
        ┌────────────┐ ┌──────────┐ ┌────────────┐
        │  Login UI  │ │Dashboard │ │ Chat Room  │
        │  (auth)    │ │  (main)  │ │ (children) │
        └────────────┘ └──────────┘ └────────────┘
              │             │             │
              │             ▼             │
              │      ┌──────────────┐     │
              │      │ Language:    │     │
              │      │ VI or EN     │     │
              │      │ (persisted)  │     │
              │      └──────────────┘     │
              │             │             │
              └─────────────┼─────────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
        ┌──────────────┐          ┌───────────────┐
        │ToastService │          │AppLocalizations
        │              │          │                │
        │ • show...()  │          │ • t()          │
        │ • navigatorKey
        │              │          │ • AppStrings   │
        └──────────────┘          └───────────────┘
              │                           │
       Show Notifications         Provide UI Text
       (success, error,           (VI or EN)
        warning, info,
        astReward)
```

---

## Toast Service Architecture

```
┌─────────────────────────────────────────────┐
│           ToastService (Static)             │
│                                             │
│  showSuccess(msg, title?)                   │
│  showError(msg, title?)                     │
│  showWarning(msg, title?)                   │
│  showInfo(msg, title?)                      │
│  showAstReward(amount, msg, title?)         │
└─────────────────────────────────────────────┘
                    │
                    │ Uses global
                    ▼
        ┌───────────────────────┐
        │   navigatorKey        │
        │ (GlobalKey<Navigator>)│
        │ (set in MaterialApp)  │
        └───────────────────────┘
                    │
                    │ Gets overlay from
                    ▼
        ┌───────────────────────┐
        │  Overlay.of(context)  │
        └───────────────────────┘
                    │
                    │ Inserts entry into
                    ▼
        ┌───────────────────────┐
        │  OverlayEntry(        │
        │   _ToastOverlay()      │
        │  )                     │
        └───────────────────────┘
                    │
                    │ Renders as
                    ▼
     ┌─────────────────────────────┐
     │    Toast Widget             │
     │                             │
     │ ┌───────────────────────┐   │
     │ │ Title (top-right)     │   │
     │ │ Message (animated in) │   │
     │ │ (3s auto-dismiss)     │   │
     │ └───────────────────────┘   │
     │                             │
     │ Animations:                 │
     │ • Slide-in from right       │
     │ • Fade-out after duration   │
     │ • Original Discord style    │
     └─────────────────────────────┘
```

---

## Localization Architecture

```
┌──────────────────────────────────────────────┐
│      AppLocalizations (Static)               │
│                                              │
│  t(key, isVietnamese: bool) → String        │
│  • category.key lookup                       │
│  • Falls back to English if missing          │
│  • Returns translated string                 │
└──────────────────────────────────────────────┘
        │                   │
        ├──────┬────────────┤
        │      │            │
        ▼      ▼            ▼
     ┌─────┐┌─────────┐┌─────────┐
     │ VI  ││ EN      ││AppStrings
     │Dict ││Dictionary
   │ │     ││ (EnBACK  ││
     │     ││         │
     │{vi} ││ {en}    │└─────────┘
     │dict ││ dict    │    │
     │}    ││}        │    │
     └─────┘└─────────┘    │
        │      │           │
        │      │        AppStrings
        │      │        .vi.property
        │      │        .en.property
        ▼      ▼           ▼
     1500+ 1500+    Type-safe access
     Vietnamese English
     strings   strings
```

**Dictionary Structure:**
```
{
  'common': {                              ← Category
    'save': 'Lưu'    / 'Save',
    'close': 'Đóng'  / 'Close',
    // ...
  },
  'dashboard': {
    'appName': 'Astatine' / 'Astatine',
    'assignments': 'Nhiệm vụ' / 'Assignments',
    // ...
  },
  'assignments': { /* ... */ },
  'dailyQuests': { /* ... */ },
  'toastMessages': { /* ... */ },
  'errors': { /* ... */ }
}
```

---

## Language State Flow

```
┌─────────────────────────────────────────────────────────┐
│  USER STARTS APP                                        │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
        ┌─────────────────────┐
        │  LoginScreen        │
        │  (authentication)   │
        │                     │
        │ • Radio VI / EN     │
        │ • User selects lang │
        │ • isVietnamese=true │
        │   or false          │
        └─────────────────────┘
                    │
            User clicks Login
                    │
                    ▼
        ┌─────────────────────┐
        │  Authentication     │
        │  (services call)    │
        │                     │
        │  Login succeeds ✓   │
        └─────────────────────┘
                    │
        Navigator.push()
        with isVietnamese: true/false
                    │
                    ▼
        ┌──────────────────────────┐
        │  MainLayoutScreen        │
        │                          │
        │  Receives:               │
        │  isVietnamese = true/false
        │                          │
        │  Stores in:              │
        │  widget.isVietnamese     │
        └──────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
    ┌──────┐  ┌──────┐  ┌──────────┐
    │Dashboard
│ │Chat  │  │Settings
   │      │  │      │  │          │
    └──────┘  └──────┘  └──────────┘
        │           │           │
        │ Pass isVietnamese to all
        │ child widgets
        │
        ▼
    ┌──────────────────────────────┐
    │ All screens use:             │
    │ AppLocalizations.t(key,      │
    │   isVietnamese: widget.isVN) │
    │                              │
    │ → All text displays in       │
    │   selected language!         │
    └──────────────────────────────┘

RESULT: Consistent language throughout session
```

---

## Integration Points in App

```
┌─────────────────────────────────────────────────┐
│          MaterialApp (authentication.dart)      │
│                                                 │
│  navigatorKey: ToastService.navigatorKey ✓      │
│  home: LoginScreen()                            │
│                                                 │
│  → Enables ToastService globally               │
│  → ToastService can now show overlays           │
└─────────────────────────────────────────────────┘
           │
           │ After login
           ▼
┌─────────────────────────────────────────────────┐
│     MaterialApp (main_dashboard.dart)           │
│                                                 │
│  navigatorKey: ToastService.navigatorKey ✓      │
│  home: MainLayoutScreen(isVietnamese: true)    │
│                                                 │
│  → Enables ToastService in main app            │
│  → MainLayoutScreen gets language preference   │
│  → Passes language to all child screens        │
└─────────────────────────────────────────────────┘
           │
           ├─→ All screens use:
           │   AppLocalizations.t(key, isVietnamese: ...)
           │
           └─→ All screens use:
               ToastService.showSuccess/Error/...()
```

---

## Data Flow: Showing a Toast

```
┌──────────────────────────────────────────┐
│  Screen Event                            │
│  (Button tap, API response, error)       │
└──────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────┐
│  Call ToastService                       │
│  .showSuccess("message")                 │
│  No context needed!                      │
└──────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────┐
│  ToastService._show() static method      │
│                                          │
│  1. Get overlay from navigatorKey        │
│  2. Create OverlayEntry with _ToastOverlay
│  3. Insert into overlay                  │
└──────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────┐
│  _ToastOverlay Widget                    │
│                                          │
│  1. Animate slide-in from top-right      │
│  2. Display for 3 seconds                │
│  3. Animate fade-out                     │
│  4. Remove from overlay                  │
│                                          │
│  UI Displays:                            │
│  ┌─────────────────────┐                │
│  │ Title               │ ← Top-right    │
│  │ Message             │ ← Green/red    │
│  │ (3s then vanishes)  │ ← Discord style
│  └─────────────────────┘                │
└──────────────────────────────────────────┘
            │
            ▼
    User sees toast!
```

---

## Data Flow: Showing Localized Text

```
┌──────────────────────────────────────────┐
│  Screen Build Method                     │
│                                          │
│  Text(_t('assignments.title'))           │
│    where                                 │
│  String _t(key) =>                       │
│    AppLocalizations.t(key,               │
│      isVietnamese: widget.isVietnamese)  │
└──────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────┐
│  AppLocalizations.t()                    │
│                                          │
│  1. Split key: 'assignments.title'       │
│  2. Extract category: 'assignments'      │
│  3. Extract key: 'title'                 │
│  4. Look up in dictionary:               │
│     _vi['assignments']['title'] or       │
│     _en['assignments']['title']          │
│  5. Return string                        │
└──────────────────────────────────────────┘
            │
            ▼
    ┌───────────────────────┐
    │ isVietnamese = true?  │
    └───────────────────────┘
       │                 │
      YES               NO
       │                 │
       ▼                 ▼
  ┌────────┐        ┌────────┐
  │"Bài tập"         "Assignments"
  └────────┘        └────────┘
       │                 │
       └────────┬────────┘
              │
              ▼
    Text Widget displays string
    in user's selected language!
```

---

## Backward Compatibility

```
OLD CODE (Still Works!)
┌─────────────────────────────────────────────┐
│  DiscordToast.showSuccess(                  │
│    context,                                 │
│    'Message',                               │
│    'Title'                                  │
│  )                                          │
└─────────────────────────────────────────────┘
        │
        │ Deprecated but still works
        │ Routes to new ToastService
        ▼
    [Internally calls]
    ToastService.showSuccess('Message', title: 'Title')
        │
        ▼
    Toast appears (same as before!)

NEW CODE (Recommended)
┌─────────────────────────────────────────────┐
│  ToastService.showSuccess(                  │
│    'Message',                               │
│    title: 'Title'                           │
│  )                                          │
└─────────────────────────────────────────────┘
        │
        │ Direct call, no context needed
        │
        ▼
    Toast appears (clean and simple!)

RESULT: Both work, new way is cleaner
```

---

## File Organization

```
lib/
├── services/
│   ├── toast_service.dart              ← Toast Service implementation
│   │   ├── ToastService (class)
│   │   ├── ToastType (enum)
│   │   ├── DiscordToast (deprecated wrapper)
│   │   └── _ToastOverlay (widget)
│   │
│   └── REFACTORING_GUIDE.md            ← API Reference & examples
│
├── localization/
│   ├── app_localizations.dart          ← Localization dictionary
│   │   ├── _vi (dictionary)
│   │   ├── _en (dictionary)
│   │   ├── AppLocalizations.t() (function)
│   │   └── AppStrings (class with properties)
│   │
│   └── CLASSROOM_CHAT_MIGRATION_EXAMPLE.md ← Step-by-step example
│
├── toast.dart                          ← Barrel export (public API)
│
├── discord_toast.dart                  ← Updated to wrap new service
│
├── authentication.dart                 ← Login + ToastService integration
│
├── main_dashboard.dart                 ← Dashboard + language flow
│
├── ARCHITECTURE.md                     ← System design & rationale
│
└── REFACTORING_SUMMARY.md              ← Executive overview

Also at project root:
├── README_REFACTORING.md               ← Master index
├── QUICK_START.md                      ← Quick reference
├── IMPLEMENTATION_COMPLETE.md          ← Final status
└── REFACTORING_COMPLETION_CHECKLIST.md ← Detailed checklist
```

---

## Integration Checklist

```
✅ REQUIRED (Already Done)

☑ MaterialApp has navigatorKey: ToastService.navigatorKey
  └─ authentication.dart:  ✓
  └─ main_dashboard.dart:  ✓

☑ Language selection at login
  └─ LoginScreen.isVietnamese: ✓

☑ Language state preserved through auth
  └─ MainLayoutScreen(isVietnamese: ...): ✓

☑ All child screens receive isVietnamese
  └─ Each screen constructor: ready for migration

☑ Toast Service ready globally
  └─ Import 'package:astatine_dashboard/toast.dart': ✓

☑ Localization dictionary complete
  └─ 80+ keys, VI/EN, all categories: ✓


🔲 PER-SCREEN (Ready When Needed)

For each screen to migrate:
☐ Replace hardcoded strings with AppLocalizations.t()
☐ Replace toast calls with ToastService.showX()
☐ Add _t() helper method for convenience
☐ Test both languages
☐ Update language strings as needed in dictionary
```

---

## Success = Consistency

```
BEFORE Refactoring
┌─────────────────────────────────────────┐
│  Chat Screen                            │
│  - DiscordToast.show(context, msg)      │
│  - Hardcoded Vietnamese text            │
│  - No fallback to English               │
│  - Context passed through 5 methods     │
└─────────────────────────────────────────┘

│ + Different patterns │ in each screen
│ + String duplication │
│ + Context juggling   │
▼

AFTER Refactoring
┌─────────────────────────────────────────┐
│  Chat Screen                            │
│  - ToastService.showSuccess(msg)        │
│  - Localized text from dictionary       │
│  - Automatic English fallback           │
│  - Context not needed                   │
└─────────────────────────────────────────┘

│ + Consistent pattern  │ everywhere
│ + Centralized strings │
│ + No context juggling │
│ + Professional feel   │
▼

RESULT: Clean, maintainable, user-friendly app!
```

---

This visualization should help you understand:
- ✅ How Toast Service works
- ✅ How Localization works  
- ✅ How language state flows through the app
- ✅ How to integrate new modules
- ✅ Data flow for common operations
- ✅ File organization

See the documentation files for detailed guidance on using and migrating to these modules.
