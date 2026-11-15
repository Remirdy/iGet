# Connected widgets

## Weather

The weather widget requests current temperature, humidity, wind and WMO condition code from the [Open-Meteo Forecast API](https://open-meteo.com/en/docs). It sends the chosen city's coordinates, not the device's location. Presets and manually entered coordinates are supported.

Requests are deduplicated by coordinates and cached for fifteen minutes. A small cache in the application's cache folder preserves the last reading across restarts. Failed requests keep that reading with a stale/offline label. Hidden or removed weather widgets cancel their demand. Preview tests disable outgoing connections.

Weather data attribution is shown in the widget, with links to Open-Meteo and [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The default endpoint is Open-Meteo's free non-commercial service. A commercial release must use an appropriately licensed endpoint or subscription, as described in [Open-Meteo's pricing and usage terms](https://open-meteo.com/en/pricing). The data service does not add a runtime dependency to the application; its server source is not bundled.

## Apple Music and Spotify

The music widget uses fixed Apple events for the selected player. It does not execute imported script text. Connecting is explicit; the application does not contact a player on first launch. The selected player must be open with a track available.

macOS Automation permission is required for the actual player connection. The app declares `NSAppleEventsUsageDescription`, the automation entitlement and the selected bundle identifiers. A denied or missing player produces a reconnectable state and stops polling. Hidden music widgets stop polling. A connected visible widget polls every five seconds, or fifteen seconds under the saver policy.

The automated controller tests use a fake player to exercise read, play/pause, previous, next, disconnect and denial behavior. They do not grant macOS permissions or claim to validate a real player on the host.

## Photos and launchers

Photo selection uses the user's file picker. A resized JPEG is stored in the widget; original metadata is not copied. Images are bounded to 512 KB after optimization and a memory cache is limited to 16 MiB. Exported space packs include these images and any custom widget text.

Website shortcuts accept http/https addresses without embedded credentials. Application shortcuts store an installed application's bundle identifier, not an imported executable path. Opening either requires a click. No shortcuts are launched during preview or automated tests.
