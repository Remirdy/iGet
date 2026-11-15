# Product roadmap

## Current implementation

Twenty-one desktop widgets: Clock, Focus, Tasks, Countdown, Notes, Calendar, Habits, Battery, System monitor, Photo, Sticker, Dice, Noughts & crosses, Water tracker, Quote, Pocket pet, Breathing, Launcher, Weather, Music and Custom canvas.

The application uses the repository's original logo throughout. Light and dark appearances follow its navy, purple and lilac colors, with eight widget palettes and custom colors.

Studio supports independent titles/content, free dimensions, opacity, borders, corners, fonts, transparent/material surfaces, shadows, position locking, click-through and three window levels. Canvas layers support text, emoji/SF symbols, time, dates and progress, with positioning, order, width, rotation and colors. Progress can bind to real tasks, focus, habits and water data.

Spaces provide starter layouts, saved independent widget arrangements, duplication and file sharing. Photos and custom text are included in reviewed space packs. Backup restore and removal undo remain available. The system WidgetKit extension continues to register seven local tools; the new interactive collection belongs to the live desktop engine.

## Verification and device gates

Core and controller checks cover persisted customization, existing-record migration, game rules, image import, canvas bindings, window behavior, weather cache/failures and playback command dispatch. Live weather is separately exercised against the public service. Interface renders cover all widget families and both appearances.

Real Apple Music/Spotify permission and playback checks, signed WidgetKit installation, physical monitor dragging, VoiceOver and ten-minute resource measurements remain device checks. Refer to VALIDATION.md for the exact evidence, and INTEGRATIONS.md for provider behavior and service requirements.

## Competitive coverage

See COMPETITOR_RESEARCH.md. Complete parity with every competing widget ecosystem has not been achieved. Larger gaps include executable skin compatibility, advanced sensors, audio spectrum, charts, wallpaper/video collections, additional games, clipboard/file-tray tools, calendar events and community distribution.

## Next architectural work

- Separate blob storage from the transactional document if larger photo collections become common.
- Display-relative positioning and explicit monitor assignments.
- Reusable canvas components, more data sources and live chart layers.
- Localization, accessibility audit and signed release validation.
- Additional integrations only with measured resource cost and contextual permission flows.
