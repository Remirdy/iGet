# Development

iGet targets macOS 14 and later. The desktop application uses SwiftUI and AppKit; the system extension uses WidgetKit and App Intents. Core, data and design sources are shared directly by the two targets to avoid extra runtime framework bundles. There are no third-party runtime dependencies, embedded browser engines or always-on background network services.

## Build

With Command Line Tools installed:

```sh
make local
open build/iGet.app
```

This creates an ad hoc signed standalone application for the current Mac architecture in the local iGet build cache, links it from `build/iGet.app`, and writes `build/iGet.zip`. Keeping the signed bundle outside cloud-managed folders avoids cloud metadata invalidating its signature. It does not install the WidgetKit extension or enable launch at login for distribution. Set `IGET_ARCH=x86_64` or `IGET_ARCH=arm64` to cross-compile against the installed SDK. Release compilation uses size optimization and whole-module optimization.

To build and verify standalone Release archives for both Apple Silicon (`arm64`) and Intel (`x86_64`):

```sh
make packages
```

This runs `./scripts/package-release.sh`, validates architecture slices, bundle metadata, localization resources, and strict ad hoc signatures on extracted copies, and writes `iGet-0.3.0-apple-silicon.zip`, `iGet-0.3.0-intel.zip`, and `SHA256SUMS.txt` under `build/releases/`.

For the app and extension together, install full Xcode, open `iGet.xcodeproj`, select the same development team for both targets, and enable `group.com.twobitdev.iGet` for both bundle identifiers. Build with Xcode or run:

```sh
make release
```

The command-line Xcode build disables signing for compile validation. A distributable application requires a valid signing identity, registered App Group, archive, and notarization. Never substitute the standalone build for a signed extension test.

`project.yml` is the project source. After adding source files, install XcodeGen and run `make generate`. Commit the regenerated project with the changes.

## Verification

```sh
make test
./scripts/render-previews.sh
```

Core checks cover absolute focus deadlines, pause/resume, repeated completion, calendar-day countdowns across daylight saving time, habit streaks, import rejection, database rollback, reopening, and concurrent SQLite writers. Test databases are temporary. Integration checks exercise the application controller, undo, restore, provider demand and hidden desktop-window reconciliation. Preview rendering exercises all pages, tool editors and three widget sizes in both appearances without controlling the computer interface or changing the user's workspace data. Outputs are under `build/previews`.

The extension can also be type-checked using Command Line Tools:

```sh
find Packages iGetWidgets -name '*.swift' -print > build/widget-sources.txt
swiftc -typecheck -swift-version 5 -application-extension -D WIDGET_EXTENSION @build/widget-sources.txt
```

A type check is not an installation test. Verify real system-widget discovery, App Intent execution and App Group access in a signed application on a physical Mac.

## Data

`WorkspaceDatabase` stores one versioned document in SQLite. Every mutation begins an immediate transaction, rereads the latest document, validates it and commits. WAL mode and a busy timeout allow the app and extension to write without overwriting a stale in-memory snapshot. The App Group container is preferred; standalone builds use Application Support when group access is unavailable. Existing unrecognized or corrupt data is reported and retained.

Tasks and habits use stable UUIDs. Widget task actions set a target state rather than toggling blindly. Focus actions compare the expected state before applying an operation. Running focus sessions store one absolute deadline; no per-second persistence is performed. A single scheduled completion reconciles the deadline, with a second reconciliation on wake and activation.

Theme files contain schema version, name and a bounded list of widget configurations. Imports reject unknown fields, unsupported tools/palettes, nonfinite coordinates, invalid dimensions and files larger than 20 MB. Imported widget identifiers are regenerated. Imported scripts are rejected. Connected widget types use their built-in providers; a pack cannot define a remote endpoint or executable source. Import review happens before creating a new space. Backups are separate, replace the local document only after explicit confirmation, and can be undone within the current session.

## Resource policy

Live CPU and battery providers run only when a corresponding desktop widget or tool editor needs them. Closing the editor, disabling the widget, hiding the desktop layout, or switching to an unrelated space removes that demand. Display sleep and system sleep suspend sampling. Automatic mode follows the system low-power notification; thermal pressure overrides all modes. Balanced sampling is every 3 seconds; power saver is every 15 seconds. Timers allow 20% tolerance. History is bounded to 40 CPU samples. RAM represents active, wired and compressed pages, not the process's resident memory.

Clock views update by the minute. Focus text uses system timer rendering. Notes debounce writes by 600 milliseconds and flush pending text on leaving the editor, app deactivation and termination. Widget timeline reload requests are coalesced after local mutations; the operating system decides the actual extension refresh schedule.

## Release checks

- Verify desktop drag, locked positions and monitor disconnection on physical displays.
- Test small, medium and large system widgets, including completion actions while the app is closed.
- Test app restart, display sleep, system sleep, date and time-zone changes, and App Group failures.
- Inspect keyboard navigation, VoiceOver, increased contrast and long task titles.
- Measure a Release build after a 60-second warmup, then collect ten minutes with desktop widgets visible and hidden. Record CPU, physical footprint, energy impact, hardware, OS, power source and profile. Treat size, CPU and memory goals as targets until measured.

## Personalization

WidgetOptions is optional on DesktopTile, so existing version-one records decode with defaults. Style, content, game state, images and canvas layers belong to the widget instance. Dimensions, colors, opacity, fonts, links, layers and payload sizes are validated before commit. Sliders keep their draft locally while dragging and commit when released; canvas drags commit one position update on release. Surface changes reuse the hosting view unless dimensions change, preserving interactive view state.

Run `./scripts/test-services.sh` for deterministic provider checks. Set `IGET_TEST_LIVE_WEATHER=1` when running `build/service-tests` to include a real public-city forecast request. Music tests never trigger an Automation permission prompt.

## Languages

`LocalizationManager` resolves the saved language override or the first supported macOS preferred language. Turkish, English and German are supported; unsupported system languages fall back to English. Settings changes are persisted in the workspace document and apply immediately. Missing language fields in older backups default to the system setting.

`LocalizationCatalog` contains the application strings and translated format templates. Identifiers for tools, categories, tabs and presets stay stable; only display labels are translated. User notes, task titles, custom widget headings, saved quotes and imported text are retained verbatim. The selected locale also drives dates, month names and number formatting. macOS permission text and App Intent metadata use the standard resources in `Config/Localization`.

Core checks verify language resolution, overrides, catalog coverage, format argument parity, singular/plural forms and older backup decoding. Integration checks verify live changes, persistence and preservation of user content. Preview rendering covers all three languages in both appearances.
