# IPv64.net iOS

## Design rules

- Colour gradient (`setColorGradient`): only on full screens in the navigation stack, never inside a sheet.
  While a screen presents a sheet, it switches its own gradient off (`setColorGradient(showSheet ? .clear : .orange)`).
- Copying text: always `Clipboard.copy(_:sensitive:)` (IPv64/Helpers/Clipboard.swift). It vibrates on success; use `sensitive: true` for keys, tokens and update URLs.
