# Perch

Perch is a macOS menu bar app for assigning applications to Spaces and reopening or launching them on the right desktop.

It works by posting the same Mission Control keyboard shortcuts you would use manually, then activating or launching the selected app after a short delay. Because of that, Perch needs macOS Accessibility permission and your Desktop switching shortcuts need to match Perch's settings.

## Requirements

- macOS 26.2 or newer
- Xcode 26.3 or newer
- Mission Control shortcuts for `Switch to Desktop 1` through `Switch to Desktop 9`
- Accessibility permission for the built app

The project has no package-manager dependencies. Open the Xcode project and build the `Perch` scheme.

## Run Locally

Clone the repository:

```sh
git clone https://github.com/imZeo/perch-window-management.git
cd perch-window-management
```

Open the project in Xcode:

```sh
open Perch.xcodeproj
```

Select the `Perch` scheme and run it with `Cmd+R`.

Perch is an accessory menu bar app, so it does not show a Dock icon. Look for the bird icon in the macOS menu bar.

## Command-Line Build

You can also verify the app from Terminal:

```sh
xcodebuild \
  -project Perch.xcodeproj \
  -scheme Perch \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .derived-data \
  build
```

The built app will be at:

```text
.derived-data/Build/Products/Debug/Perch.app
```

There is currently no test target, so a successful Debug build is the local smoke test.

## macOS Setup

Enable Desktop switching shortcuts:

1. Open System Settings.
2. Go to Keyboard.
3. Open Keyboard Shortcuts.
4. Select Mission Control.
5. Enable `Switch to Desktop 1`, `Switch to Desktop 2`, and any additional desktops you want Perch to use.

In Perch, set the shortcut assumption to match your macOS shortcuts:

- `Control + Number`
- `Option + Number`
- `Command + Number`

Grant Accessibility access:

1. Run Perch once.
2. Open System Settings.
3. Go to Privacy & Security.
4. Open Accessibility.
5. Enable Perch.
6. Quit and reopen Perch if desktop switching does not work immediately.

## Usage

From the menu bar item you can:

- assign a running app to Desktop 1 through 9
- clear an app's saved desktop assignment
- launch or reopen saved apps on their assigned desktop
- adjust launch delay and shortcut assumptions
- enable or disable launch watching
- open diagnostics for recent Perch activity

Rules and settings are stored locally in Application Support.

## Development Notes

- Perch is an AppKit menu bar utility.
- The app is configured as `LSUIElement`, so it runs without a Dock icon.
- App Sandbox is disabled because Perch relies on synthetic keyboard input for desktop switching.
- Perch does not use private APIs to inspect or manage Spaces.
- Perch does not move windows between desktops; it switches desktops and activates or launches apps.

More implementation notes live in [Perch/README.md](Perch/README.md).
