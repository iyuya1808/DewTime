# Localization Guide

DewTime supports **Japanese** and **English** via String Catalog + in-app language setting.

## Architecture

- `DewTimeLiveActivityShared/LocalizationManager.swift` — language preference (App Group `UserDefaults`)
- `DewTimeLiveActivityShared/L10n.swift` — typed string accessors
- `DewTimeLiveActivityShared/Localizable.xcstrings` — ja/en translations
- Settings → Display → Language: System / 日本語 / English

## Adding a new user-facing string

1. Pick a key: `{domain}.{screen}.{element}` (e.g. `timer.departure.confirm.title`)
2. Add accessor in `L10n.swift` (or `L10nModels.swift` / `L10nGarden.swift`):

```swift
static var myLabel: String { tr("my.feature.label", default: "日本語ラベル") }
```

3. Add to `Localizable.xcstrings` with **ja** and **en**
4. Use in UI: `Text(L10n.MyFeature.myLabel)`
5. Run tests: `xcodebuild test ... -only-testing:DewTimeTests/LocalizationGuardTests`

## Do not

- Hardcode Japanese in `Views/`, `Models/`, `Support/`, or Extension code
- Use localized text for filters, switches, or business rules
- Forget Extension targets when adding keys (shared catalog in `DewTimeLiveActivityShared/`)

## Adding a third language later

1. Add `case ko` (etc.) to `AppLanguage`
2. Add column to `Localizable.xcstrings`
3. Add picker chip in `SettingsView`
