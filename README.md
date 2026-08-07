# YouPlay

A React Native iOS app (built with Expo) that transforms YouTube into a podcast experience. Listen to your favorite channels in the background with a clean interface, fully integrated system audio player.

## Features

- **Search & Follow:** Search for YouTube channels and follow them to always have them at your fingertips
- **Native Background Player:** The player uses native `expo-audio` to play audio in the background, with full support for iOS lock screen controls
- **Playback Queue:** Add episodes to your queue for seamless listening

## Development

The project is specifically focused on the iOS ecosystem, but feel free to extend it to Android too.

### Installation

To install dependencies (the necessary patches, including the ones for `expo-audio`, will be applied automatically thanks to the `postinstall` script):

```bash
npm install
```

### Running on an iOS Device

Since this is an app with native code (and cannot be run in Expo Go), you must build and run it on your own wired device:

```bash
npx expo run:ios --device
```

### Release Build (Production)

To test the real performance of the app without the overhead of the development server, you can build the Release version:

```bash
npx expo run:ios --device --configuration Release
```
