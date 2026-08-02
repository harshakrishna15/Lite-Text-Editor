# Lite Text Editor

Lite Text Editor is a native macOS rich-text writing app prototype for Apple Silicon.

## Current MVP

- Native `NSTextView` rich-text editor
- Native macOS menu-bar sections for Home, Insert, Layout, and Review
- Compact macOS titlebar with document tabs, outline access, and bold/italic/underline controls
- App settings sheet for writing and autocomplete configuration
- File menu actions for open, save, save as, PDF export, and print
- Paper-style writing surface with a centered 8.5 x 11 inch Letter page, 1-inch margins, and desk background
- Content-driven full-page rendering: one full page until text spills, then two full pages, and so on
- Optimized page rendering that redraws only visible page areas while scrolling
- Symmetric desk space above and below the document page
- Empty new document default with black 12 pt Courier text
- Multiple renameable tabs inside one document, automatically named Tab 1, Tab 2, and upward
- macOS spellcheck, optional autocorrect, grammar checking, smart quotes, and smart dashes
- Google Docs-style typed list shortcuts (`- ` or `* ` for bullets, `1. ` for numbering, and checkbox syntax)
- Google Docs-style list editing with Enter to continue, Enter twice to exit, and Tab/Shift+Tab to nest
- Courier-only document typography with regular, bold, and italic variants
- Bottom zoom bar with a fixed-size dropdown, step buttons, and a click/drag zoom slider
- Bottom-left document counter dropdown for words, characters, sentences, paragraphs, lines, pages, and reading time
- Google Docs-style spelling review card with Enter-to-change and automatic next-issue navigation
- Local phrase autocomplete fallback
- Document-aware suggestion request pipeline
- Document-memory suggestions from repeated wording in the current document
- 2-5 word suggestion limit, configurable from `Lite Text Editor > Settings...`
- `Tab` accepts one word at a time
- `Option+Right` also accepts one word
- `Esc` dismisses the current suggestion
- Save multi-tab documents as a single `.ltedoc` file
- Open legacy `.rtf`, `.txt`, `.docx`, and `.odt` files as one-tab documents
- Export the active tab to `.pdf`

## Architecture

Source files are split into feature modules under `Sources/LiteTextEditor` so editor surface work, writing tools, suggestions, local AI, documents, formatting, and UI can be changed independently. See `ARCHITECTURE.md` for the dependency rules.

## Build

```sh
swift build
```

## Run

```sh
swift run "Lite Text Editor"
```

## Keyboard Shortcuts

- `Command+O`: open LTEDOC, RTF, TXT, DOCX, or ODT
- `Command+S`: save
- `Command+Shift+S`: save as
- `Command+Shift+E`: export PDF
- `Command+B`: bold
- `Command+I`: italic
- `Command+U`: underline
- `Command+L`: align left
- `Command+R`: align right
- `Command+J`: justify
- `Command+Shift+8`: bulleted list
- `Command+Shift+7`: numbered list
- `Command+[`: decrease indent
- `Command+]`: increase indent
- `Command+Option+X`: open spelling review
- `Enter`: change the current spelling review suggestion
- `Command++`: zoom in
- `Command+-`: zoom out
- `Command+0`: actual size
- `Command+Option+0`: fit page to screen
- `Tab`: accept the next autocomplete word
- `Command+P`: print

## Local AI Plan

The app already has a `LocalModelSuggestionProviding` boundary. Each request includes:

- Compact current document context
- Current paragraph
- Text immediately before the cursor
- Text immediately after the cursor
- The configured 2-5 word limit

The next step is to wire that request to MLX Swift LM with a small local 4-bit model, then use the same 2-5 word post-processing before showing suggestions.
