# Validation record

Date: 15 November 2026

Host: Apple Silicon, macOS 26.5. Compiler: Apple Swift 6.2.4 in Swift 5 language mode. Deployment target: macOS 14.

| Check | Result |
| --- | --- |
| Core behavior, storage and localization | 90 checks passed |
| Application and desktop lifecycle | 45 checks passed |
| Deterministic connected services | 16 checks passed |
| Pages, editors and three widget sizes in three languages and two appearances | 555 render outputs |
| Standalone Apple Silicon Release build | Passed |
| Standalone Intel Release cross-build | Passed; not executed on Intel hardware |
| WidgetKit source type checking, Apple Silicon and Intel | Passed |
| Property lists, localization resources, entitlements, shell syntax and diff whitespace | Passed |
| Ad hoc application signatures | Verified |

The desktop application is approximately 4.7–4.8 MiB, depending on architecture. Its ZIP is approximately 1.3 MiB. These numbers exclude a signed WidgetKit extension, debug symbols and development tools.

The integration suite checks task creation and repeat-safe completion, widget configuration, layout persistence, space switching, import identity regeneration, undo, backup restore, provider demand and desktop window reconciliation. It also covers the twelve additional desktop widget types, image import, canvas state, free dimensions and window behavior. Desktop windows are created hidden during tests. Render tests use isolated temporary storage and do not control the computer interface.

Localization checks cover supported and unsupported system languages, explicit overrides, legacy document decoding, saved preferences, user-content preservation, catalog coverage, format argument parity, count forms and localized month names. Cached weather descriptions follow the language without another request. English, Turkish and German previews include the minimum window size, light/dark pages, every tool editor and all widget sizes. Representative pages and widget sheets were visually inspected.

Weather transport, fifteen-minute caching, cache reopening, offline retention, invalid responses and preview networking are tested with controlled responses. A separate real Open-Meteo request for London succeeded. Music tests use a controller substitute to verify connection consent, commands, disconnection, denied access and demand-based polling. They do not trigger a real Automation prompt or control a music player.

The original GitHub logo is used for the interface and application icon. The source image and `Config/BrandLogo.png` have SHA-256 `f8e2a85efe435d4f098344d04e0250ab9215da6302da13dfc9628babac299d75`.

## Remaining device checks

Full Xcode and a development team are required to build and install the signed app-extension pair. System-gallery discovery, App Intent execution from installed widgets, and App Group access have not been verified in a signed installation. Source type checking does not cover metadata extraction, extension packaging or system scheduling.

Real Apple Music and Spotify playback and the macOS Automation permission flow remain device checks. Interactive dragging across physical monitors, Intel execution, VoiceOver navigation, and ten-minute idle CPU/RAM/energy measurements also remain device checks. No measured idle-power or memory claim is made. Power profiles and provider demand transitions are implemented and covered by automated checks.
