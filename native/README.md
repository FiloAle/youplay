# YouPlay Native

SwiftUI version of YouPlay, with no third-party dependencies. Requires iOS 26.

Open `YouPlay.xcodeproj` in Xcode and run the `YouPlay` scheme. It has the Expo app's bundle ID, so it installs as an update of it.

## Structure

| Folder | Contents |
|---|---|
| `YouPlay/App` | App entry point, navigation, orientation |
| `YouPlay/DesignSystem` | Tokens and reusable components. Rules are in [DESIGN.md](DESIGN.md) |
| `YouPlay/YouTube` | InnerTube and RSS clients, parsing, models |
| `YouPlay/Library` | Followed channels, categories, backups |
| `YouPlay/Player` | Player, queue, drag gesture, lock screen |
| `YouPlay/Screens` | Home, Followed, Search, Channel |

## Data from the Expo app

`SubscriptionStore` reads the file the Expo app keeps in Documents (`subscriptions-backup.json`), in every format it has ever written. It inherits the file because it has the Expo app's bundle ID (`com.filippoaleee.youplay`). Exported backups work with the Importa action too.

## YouTube clients

InnerTube has no public contract. If playback or parsing breaks, start from `InnerTubeClient.swift` (client names and versions) and `InnerTubeParser.swift` (response keys). The values come from `youtubei.js`, whose `Constants` file is the first place to check for updates.

## Measuring frames

Debug builds log every player transition:

```bash
xcrun simctl spawn booted log show --last 5m --style compact --predicate 'subsystem == "com.filippoaleee.youplay.native"'
```
