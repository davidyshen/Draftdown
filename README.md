# MDWriter

<p align="center">
  <strong>Modern Academic Markdown Editor & Publication Workbench</strong>
  <br />
  <em>Reimplemented from the ground up with Flutter and Dart</em>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#academic-features">Academic Capabilities</a> •
  <a href="#testing">Testing</a> •
  <a href="#license">License</a>
</p>

---

## Overview

**MDWriter** is a high-performance, distraction-free desktop Markdown editor designed specifically for researchers, academics, authors, and journalists. Originally conceived as an Electron application, MDWriter has been completely reimplemented in **Flutter** to deliver native desktop performance, instant startup times, lightweight memory utilisation, and seamless cross-platform support across Windows, macOS, and Linux.

MDWriter pairs real-time Markdown syntax highlighting with a paper-styled live preview, complete KaTeX mathematics, in-place academic citation formatting, robust image rendering, and a publication export pipeline powered by bundled Pandoc.

---

## Features

### ✍️ Distraction-Free Academic Editor
- **Rich Syntax Highlighting**: Custom syntax highlighter covering headers, bold/italic, strikethrough, inline and block code, LaTeX equations, footnotes, task lists, links, images, and Pandoc citation keys.
- **Line Numbers Gutter**: Synchronised editor gutter with accurate line counting and smooth scrolling.
- **Real-Time Document Metrics**: Live tracking of word count, character count, total lines, and estimated reading time.
- **Three Flexible View Modes**:
  - **Edit Mode**: Focused, distraction-free writing canvas.
  - **Split View**: Side-by-side synchronised editor and live rendering preview.
  - **Preview Mode**: Clean, floating word-processor document inspection.

### 📄 Live Document Preview
- **Paper Sheet Presentation**: Floating page layout with responsive margins, subtle borders, and elevation drop shadows.
- **KaTeX Formula Rendering**: Full rendering of inline math (`$...$` or `\(...\)`) and display/block math (`$$...$$` or `\[...\]`).
- **Image Rendering**:
  - **Local Files**: Resolves relative paths (against document directory or workspace) and absolute local paths on Windows, macOS, and Linux.
  - **Network Images**: Displays `http://` and `https://` URLs with graceful error handling and loading indicators.
  - **Data URIs**: Renders Base64 embedded images (`data:image/png;base64,...`).
  - **HTML `<img>` Support**: Converts and formats HTML image tags outside code blocks.
  - **Captions & Sizing**: Supports fragment dimensions (`image.png#300x200`), HTML attributes, hover tooltips, and italicised figure captions.
  - **Fault-Tolerant Placeholders**: Displays a clean, theme-aware error card if a referenced image is missing or corrupt.
- **In-Place Citations**: Automatic formatting of cited keys into readable author-year citations (`[@smith2020]` → `(Smith, 2020)`) with rich hover tooltips.
- **Auto-Generated Bibliography**: Appends a formatted References section automatically based on the detected citations in the text.

### 📚 Citations & Reference Management
- **BibTeX & CSL JSON**: Native parsers for BibTeX libraries (`.bib`) and CSL JSON files (`.json`).
- **Auto-Detection**: Automatically detects and loads adjacent `references.bib` or `.bib` files in the same directory as the opened document.
- **Zotero & Better BibTeX Integration**: Directly connects to Zotero's Better BibTeX local HTTP JSON-RPC endpoint to search and cite items from your personal library.
- **Quick Citation Dialog**: Searchable citation palette with keyboard navigation (arrow keys, space to select, enter to insert).

### 🚀 Publication Export Pipeline
- **Bundled Pandoc**: Ships with a pre-configured, self-contained Pandoc binary on Windows, requiring zero external dependencies.
- **Multi-Format Export**: Direct compilation to **PDF**, **Microsoft Word (DOCX)**, **LaTeX**, **HTML5**, **EPUB**, **OpenDocument (ODT)**, and **Rich Text (RTF)**.
- **Custom Page Layouts**: Select between international paper standards (**A4**, **US Letter**) and adjust page margins.

### 🎨 Typography & Theming
- **Dual Light and Dark Themes**: Fully customisable colour schemes tailored for daytime research and late-night drafting.
- **Typography Pairing**: Configure separate editor monospace fonts (Consolas, JetBrains Mono, Fira Code, Source Code Pro) and render typography pairings (e.g. Segoe UI with Georgia headers).

---

## Architecture

MDWriter follows a clean, reactive architecture with clear separation between state management, domain services, and presentation widgets:

```
lib/
├── controllers/
│   ├── editor_controller.dart              # Core application state & document workflow
│   └── markdown_syntax_controller.dart     # Custom syntax highlighter & TextSpan parser
├── models/
│   ├── citation_item.dart                  # Citation model, parser, and citation finder
│   ├── export_format.dart                  # Academic export formats & Pandoc arguments
│   └── history_entry.dart                  # Recent document history with relative timestamps
├── services/
│   ├── bibliography_service.dart           # BibTeX and CSL JSON parsing & caching
│   ├── direct_export_service.dart          # Direct HTML/PDF exporter with academic styling
│   ├── file_service.dart                   # File I/O and native file picker integrations
│   ├── history_service.dart                # Persistent file history via SharedPreferences
│   ├── pandoc_service.dart                 # Pandoc process orchestration & bundled binary
│   └── zotero_service.dart                 # Zotero Better BibTeX HTTP API client
└── ui/
    ├── screens/
    │   └── main_screen.dart                # Primary workbench window & keyboard shortcuts
    ├── theme/
    │   └── app_theme.dart                  # Academic colour palettes & typography settings
    └── widgets/
        ├── citation_dialog.dart            # Interactive citation search & insertion dialog
        ├── editor_view.dart                # CodeMirror-like editor with line gutters
        ├── export_dialog.dart              # Document export & format selection modal
        ├── markdown_preview.dart           # KaTeX, image, and citation preview widget
        ├── settings_dialog.dart            # Font & typography customisation preferences
        ├── sidebar.dart                    # Collapsible document history & quick files
        └── toolbar.dart                    # Workbench toolbar & action shortcuts
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`^3.13.7` or later)
- [Dart SDK](https://dart.dev/) (`^3.1.0` or later)
- Windows 10/11, macOS, or Linux desktop environment

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/dyshe/MDWriter.git
   cd MDWriter
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on your desktop platform:**
   - **Windows:**
     ```bash
     flutter run -d windows
     ```
   - **macOS:**
     ```bash
     flutter run -d macos
     ```
   - **Linux:**
     ```bash
     flutter run -d linux
     ```

---

## Testing

The project includes unit and widget tests covering syntax parsing, citation detection, KaTeX equations, image rendering, and document layouts:

```bash
# Run static analysis
flutter analyze

# Run all test suites
flutter test
```

### Running Specific Test Suites

```bash
# Preview, math, citations, and image rendering tests
flutter test test/preview_full_test.dart

# Markdown syntax highlighting tests
flutter test test/markdown_syntax_test.dart

# Unit tests (models, parsers, export arguments)
flutter test test/unit_test.dart

# Widget tests (dialogs, gutters, workspace layout)
flutter test test/widget_test.dart
```

---

## Building Executables

To build an optimised release executable for desktop deployment:

```bash
# Windows desktop executable
flutter build windows --release

# macOS desktop app bundle
flutter build macos --release

# Linux desktop bundle
flutter build linux --release
```

Release binaries will be generated inside the `build/` directory under your platform's target folder.

---

## Contributing

Contributions, bug reports, and suggestions are welcome! Please ensure:
1. All code adheres to the project's linting rules (`flutter analyze` reports zero issues).
2. Existing and newly created unit/widget tests pass cleanly (`flutter test`).
3. British English spelling is used in documentation and user-facing copy.

---

## License

MDWriter is free and open-source software licensed under the [GNU General Public License v3.0](LICENSE).
