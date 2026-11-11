# IPv64.net iOS

## Design rules

- Colour gradient (`setColorGradient`): only on full screens in the navigation stack, never inside a sheet.
  While a screen presents a sheet, it switches its own gradient off (`setColorGradient(showSheet ? .clear : .orange)`).
