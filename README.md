# Lite Text Editor

A lightweight, native rich-text editor for macOS.

## Features

- Paper-style writing surface with automatic page layout
- Multiple renameable tabs in each document
- Text formatting, alignment, lists, and indentation
- Document outline and writing statistics
- Spelling, grammar, autocorrect, and smart punctuation
- Local, document-aware autocomplete
- Open RTF, TXT, DOCX, and ODT files
- Save multi-tab documents as LTEDOC files
- Export to PDF or print

## Build and Run

```sh
swift build
swift run "Lite Text Editor"
```

## Keyboard Shortcuts

- `Command+O`: Open a document
- `Command+S`: Save
- `Command+Shift+S`: Save as
- `Command+Shift+E`: Export to PDF
- `Command+B`, `Command+I`, `Command+U`: Bold, italic, or underline
- `Command+L`, `Command+R`, `Command+J`: Align left, right, or justified
- `Command+Shift+8`, `Command+Shift+7`: Bulleted or numbered list
- `Command+[`, `Command+]`: Decrease or increase indent
- `Command+Option+X`: Review spelling
- `Tab` or `Option+Right`: Accept an autocomplete word
- `Esc`: Dismiss the current suggestion
- `Command+P`: Print

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the source layout and dependency rules.
