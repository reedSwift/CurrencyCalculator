# Currency Calculator 

A USDc ↔ fiat currency exchange calculator for iOS.

---

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 26 (beta) |
| iOS Deployment Target | 26.4 |
| Swift | 5.10 |

> **Note:** The project uses Xcode 26's `PBXFileSystemSynchronizedRootGroup` — it will not open correctly in Xcode 15 or earlier.

---

## Getting Started

1. Clone the repo
2. Open `CurrencyCalculator.xcodeproj`
3. Select any iOS 26 simulator
4. **Signing:** Go to *Targets → CurrencyCalculator → Signing & Capabilities* and select your own development team
5. `Cmd+R` to build and run

No external dependencies. No package manager setup needed.

---

## Architecture — MVVM-C

The app uses **MVVM-C** (Model–View–ViewModel + Coordinator), a pragmatic choice for a single-feature app that still demonstrates production-ready separation of concerns.

```
┌─────────────────────────────────────────────────┐
│  SceneDelegate                                  │
│      └── AppCoordinator  ◄── foreground events  │
│              └── MainViewController             │
│                    ├── ExchangeCardView (SwiftUI)│
│                    └── CurrencyPickerVC          │
│                          └── CurrencyListView    │
│                                                  │
│  ExchangeViewModel  ◄── all views observe this  │
│      └── ExchangeRateService (protocol)          │
└─────────────────────────────────────────────────┘
```

### Why MVVM-C and not VIPER or Clean Architecture?

- **VIPER** would be over-engineered for a single screen — 5 files per screen for one feature adds ceremony without benefit
- **Clean Architecture** would add Use Case objects wrapping a single service call — appropriate at scale, excessive here
- **MVVM-C** hits the right balance: testable ViewModel, navigation owned by the Coordinator, no UIKit in business logic

### UIKit + SwiftUI hybrid

The navigation shell (`MainViewController`, `CurrencyPickerViewController`) is UIKit. The UI surfaces (`ExchangeCardView`, `CurrencyListView`) are SwiftUI, hosted via `UIHostingController`. This reflects the real-world state of most production iOS codebases — pure SwiftUI navigation is not yet stable enough for complex flows.

---

## Project Structure

Feature-based organisation — folders reflect *what the app does*, not *what technology it uses*.

```
CurrencyCalculator/
├── App/                        # Lifecycle: AppDelegate, SceneDelegate,
│                               # AppConfiguration, AppEnvironment (DI root)
├── Coordinators/               # Navigation layer
│   ├── Coordinator.swift       # Protocol
│   └── AppCoordinator.swift    # Root coordinator
├── Features/
│   └── Exchange/
│       ├── ViewModels/
│       │   └── ExchangeViewModel.swift
│       └── Views/
│           ├── ExchangeCardView.swift          # Main screen (SwiftUI)
│           ├── CurrencyListView.swift          # Picker sheet (SwiftUI)
│           ├── MainViewController.swift        # Host VC (UIKit)
│           └── CurrencyPickerViewController.swift
├── Core/
│   ├── Models/                 # Currency.swift, Ticker.swift
│   ├── Services/               # ExchangeRateService (network + cache)
│   └── Formatters/             # CurrencyFormatter
├── DesignSystem/               # Figma-matched tokens, typography, spacing
└── Constants/                  # Strings (all user-facing copy in one place)
```

**Dependency direction:** `Features` → `Core` → nothing. `Core` never imports from `Features`.

---

## Features

- **Bidirectional conversion** — edit either field; the other updates instantly
- **Live exchange rates** — fetched from the DolarApp API on launch
- **Retry** — tap Retry on network failure to re-fetch without restarting the app
- **Background refresh** — silent rate refresh when app returns to foreground
- **Offline support (rates)** — cached rates served up to 24 hours; banner indicates staleness with age
- **Offline support (currencies)** — currency list cached indefinitely; an old list is never dangerously wrong, only potentially incomplete
- **Currency picker** — bottom sheet with all available fiat currencies
- **Input sanitization** — digits only, one decimal point, max 2dp, max 10 integer digits, leading-zero stripping
- **Dark mode** — semantic system colors throughout, no hardcoded hex for UI chrome
- **Accessibility** — VoiceOver labels, values, and hints on all interactive elements

---

## Key Technical Decisions

### Dual cache strategy

Rates and currencies are cached separately with different invalidation rules:

| Cache | Staleness check | Rationale |
|-------|----------------|-----------|
| Exchange rates | 24h max age | Stale rates cause incorrect conversions — hard failure after threshold |
| Currency list | None | A slightly outdated currency list is never dangerous, just possibly missing a new entry — show what we have rather than nothing |

### Unidirectional data flow

`ExchangeViewModel` is the single source of truth. Both UIKit VCs and SwiftUI views observe the same `@Published` properties via `@ObservedObject`. No state lives in views.

### Feedback-loop prevention

Both text fields bind to the same ViewModel. Without protection, editing one field triggers a recompute that writes to the other, which fires a Combine event, which triggers another recompute — infinite loop. Solved with an `isRecomputing` flag set synchronously before any write and cleared in a `defer` block, exploiting `@Published`'s synchronous subscriber notification.

### Task lifecycle

All async fetch tasks are stored in `private var fetchTask: Task<Void, Never>?`. Starting a new fetch cancels any in-flight task, preventing concurrent writes to `rates` and `rateLoadState` if the user taps Retry or selects currencies rapidly.

### AppEnvironment as composition root

`AppEnvironment` constructs and owns all dependencies. `AppCoordinator` receives it at init. Nothing below the coordinator knows how dependencies are constructed — this is the injection seam that makes unit testing possible without a DI framework.

---

## Testing

65 test cases across 4 suites. Run with `Cmd+U`.

| Suite | Cases | What it covers |
|-------|-------|---------------|
| `ExchangeViewModelTests` | 37 | Conversion math, swap logic, currency selection, input sanitization, offline states, retry, background refresh |
| `ModelTests` | 18 | `Ticker` decoding and mid-rate calculation, `Currency` model, `AppConfiguration` URL construction, service currencies cache |
| `CurrencyFormatterTests` | 6 | Amount and rate formatting, infinity/NaN guards |
| `AppConfigurationTests` | 3 | Config loading from JSON |

All tests use a `MockExchangeRateService` — no network calls in the test suite. `ExchangeRateServiceCurrenciesTests` uses temporary file URLs so cache tests are fully isolated.

---

## Design System

All Figma tokens are codified in `DesignSystem.swift` under the `DS` namespace:

- `DS.Colors` — brand green (`#22D081`), text primary, semantic surface colors
- `DS.Typography` — `TextStyle` bundles `Font` + `tracking` (letter-spacing) to match Figma's % tracking values
- `DS.Spacing` / `DS.Size` — every pixel value named by role, not by value
- `DS.Animation` — swap spring animation

The app uses **Messina Sans Narrow** as specified in the designs. If the font files are not present, SwiftUI silently falls back to the system font — the app runs without crashing.

---

## Known Limitations

- **Flag emoji generation** — country flags are generated from ISO currency code prefixes. A proper implementation would use stored flag assets.
- **Single feature** — the architecture is deliberately structured to scale (add `Features/History/`, `Features/Portfolio/` etc.) but only the Exchange feature is implemented.
