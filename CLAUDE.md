# IPv64.net iOS

## Design rules

- Colour gradient (`setColorGradient`): only on full screens in the navigation stack, never inside a sheet.
  While a screen presents a sheet, it switches its own gradient off (`setColorGradient(showSheet ? .clear : .orange)`).
- Copying text: always `Clipboard.copy(_:sensitive:)` (IPv64/Helpers/Clipboard.swift). It vibrates on success; use `sensitive: true` for keys, tokens and update URLs.
- Destructive items in a `Menu`: always `DestructiveMenuButton` (IPv64/Helpers/DestructiveMenuButton.swift, red icon and text).
- Expandable sections (statistics, incidents, events, problems, charts, histories): always `HcCollapsibleSection(title:isExpanded:)` (IPv64/Views/Healthcheck/HealthcheckFormFields.swift, header with a chevron that rotates when open), never a hand-rolled header button or a pushed sub-list. Long lists start collapsed.
- Swipe actions: icon only (`.labelStyle(.iconOnly)`, the title stays for VoiceOver); a delete action is always red (`role: .destructive`, `.tint(.red)`).
