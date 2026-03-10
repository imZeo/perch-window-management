# Perch

Perch is a macOS menu bar app for assigning apps to Spaces and manually reopening them on the right desktop.

## v1 Scope

- AppKit menu bar app
- Show regular running apps
- Assign a bundle ID to desktop numbers 1 through 9
- Save assignment rules locally in Application Support
- Manual action: open on assigned desktop
- No auto-enforcement
- No window movement
- No deep accessibility automation

## Current Implementation

- Menu bar shell with running app discovery
- Local JSON rule persistence
- Synthetic `Control` + number Space switching
- Launch or activate after the Space switch delay
- Settings window with:
  - accessibility permission status
  - saved app assignments
  - manual open and remove actions for saved rules

## Architecture

```text
Perch/
├── App/
├── Models/
├── Services/
├── UI/
└── Utilities/
```

## Notes

- Perch must be granted Accessibility access for desktop switching to work.
- The current implementation assumes macOS keyboard shortcuts for `Switch to Desktop 1...9` are enabled.
- The target is configured as a UI agent menu bar app and should not run with App Sandbox enabled.
