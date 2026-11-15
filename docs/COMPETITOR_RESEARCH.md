# Widget landscape and coverage

Reviewed 15 November 2026. Sources below are the projects' own repositories and developer-maintained product descriptions. Features are documented claims, not results of installing or benchmarking the competing applications.

| Project | Documented approach | Present in iGet | Coverage gaps |
| --- | --- | --- | --- |
| [Übersicht](https://github.com/felixhageloh/uebersicht) | JavaScript/React widgets, command output and an extensible widget ecosystem | Desktop panels, independent content, saved layouts and a declarative canvas | JavaScript widgets, shell commands and compatibility with its widget library |
| [Deskset](https://github.com/jokyme/Deskset) | Native panels, Rainmeter skins, configurable window behavior, editor, media and weather | Native panels, desktop/normal/floating levels, click-through, grid/edge snapping, saved layouts, media controls, current weather | Rainmeter/Lua compatibility, audio spectrum, advanced sensors and the broader plugin system |
| [Widgy](https://apps.apple.com/us/app/widgy-widgets-home-lock-watch/id1524540481) | Layer-based text, images, symbols and charts, data sources and shared designs | Editable text/symbol/time/date/progress layers, positions, colors, rotation, order and progress bindings | Full chart/gauge library, arbitrary data sources, community discovery, QR sharing and other-platform surfaces |
| [WidgetWall](https://apps.apple.com/us/app/widgetwall/id1618466427?mt=12) | Desktop tools, games, photos, stickers, media and wallpapers | Photos, emoji stickers, a small companion, dice, noughts-and-crosses, quotations, weather, music, notes and productivity tools | Wallpaper/video library, its other games, stocks, browser widgets and its full tool catalog |
| [Stats](https://github.com/exelban/stats) | Specialized CPU, GPU, memory, disk, network, battery and sensor monitoring | CPU, memory, battery, bounded history and power-aware sampling | GPU, disk/network modules, Bluetooth and SMC/fan/temperature controls |
| [Tenfold](https://github.com/sivaprasad1988/Tenfold) | Notch-centered media, weather, calendar, clipboard and file utilities | Media, weather, focus and local desktop utilities | Notch presentation, clipboard vault, file tray and event calendar |

The current build does not have complete feature parity with these products. The table deliberately includes the gaps; absence from a product description is not proof that a competitor lacks a feature.

## Direction

The intended experience combines a visual canvas with small interactive tools, independent per-widget content and explicit resource behavior. This is a product direction, not a claim that any individual feature is unique. The measurable advantage still needs a controlled device test: time to build a custom layout, energy/CPU while visible and hidden, memory use and package size.

There is no web runtime or imported executable widget code in iGet. A canvas can bind progress to tasks, habits, water and focus without a script. Live providers stop when no visible widget or editor needs them. The interactive companion uses user actions rather than a continuous background simulation. Breathing animation ends after one minute and respects power-saving and reduced-motion settings.

## Source and license boundaries

No competitor implementation was copied into this build. Deskset and Übersicht advertise GPL-3.0 licenses; inspecting their documented behaviors does not make their source part of this MIT project. Stats and Tenfold list MIT licenses, but their code is also not included. Product graphics and the iGet logo remain the assets supplied by this repository.
