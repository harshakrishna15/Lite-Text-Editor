# Lite Text Editor Architecture

The app is organized as feature modules under `Sources/LiteTextEditor`. SwiftPM still builds one executable target, but the source layout enforces independent ownership boundaries so each system can later become a separate target with less churn.

## Dependency Direction

Dependencies should point downward:

```text
App
EditorUI
EditorEngine
WritingTools, Suggestions, Formatting, Documents
Core, DesignSystem
```

Higher layers may coordinate lower layers. Lower layers should not reach back into higher layers.

## Modules

### App

Entry point, app delegate, menus, window behavior, and app-level notifications.

### EditorUI

SwiftUI views and AppKit representables that present editor state and forward user actions. This layer should avoid business logic.

### EditorEngine

The editing surface: `NSTextView` bridge, page layout, selection, typing, undo, zoom coordination, and command routing. This layer owns editor behavior but should delegate feature-specific logic to the lower feature modules.

### WritingTools

Spelling and autocorrect review logic. This module finds spelling issues and tracks ignored ranges; the editor engine applies replacements and updates UI state.

### Suggestions

Autocomplete request models, context building, fallback phrase suggestions, and provider pipeline. This module should not know about `NSTextView`, SwiftUI, or page layout.

### Formatting

Text presets, font previews, and formatting helpers. Formatting commands are coordinated by the editor engine because they mutate rich text directly.

### Documents

Open/save/export, autosave policy, recent documents, preferences, and document structure extraction.

### DesignSystem

Shared styling primitives used by UI modules.

### Core

Shared models used across systems. Keep this layer small and stable.

## Rules

- `AutocompleteTextView` displays and accepts suggestions; it does not choose the app's suggestion provider.
- `EditorController` wires systems together and exposes state to UI.
- `SuggestionProviding` is the boundary for autocomplete engines.
- `SpellingReviewController` owns spelling detection and ignored issue tracking.
- Feature modules should communicate through small value types and protocols, not direct view references.
