# Tasmanian Chronicle: High-Precision Editorial Engine

> A specialized desktop tool for automated newspaper layout, featuring a custom 4-column geometric rendering engine.

Built with **Flutter & Dart** for Linux and Windows desktop targets.

---

## What it does

The Tasmanian Chronicle Editor lets a newsroom team compose articles in a structured form, watch the final newspaper layout render in real time, and export a print-ready A5 PDF in one click — no manual design software required.

The core of the project is a bespoke PDF rendering engine (`pdf_generator_service.dart`) that does not rely on any layout abstraction layer. Instead, it implements a **greedy column-balance algorithm** driven by geometric typographic estimation: character-width ratios, line-height coefficients and image footprint calculations all produce values in PDF points, allowing the engine to distribute content across four strict columns with mathematical precision.

---

## Stack

| Layer | Technology |
|---|---|
| UI framework | Flutter 3.41 (Material 3) |
| Language | Dart 3.11 |
| PDF engine | `pdf` 3.11 + `printing` 5.13 |
| Typography | Libre Baskerville (Google Fonts, embedded) |
| State | `ValueNotifier` + `ValueListenableBuilder` |
| File I/O | `path_provider`, `file_picker` |
| Build target | Linux native (GTK), Windows native |

---

## Architecture

```
lib/
├── main.dart                       # Two-panel UI: structured form (left) + live PDF preview (right)
├── models/
│   └── article_model.dart          # Article, Graphic, VerticalPosition
└── services/
    └── pdf_generator_service.dart  # Layout engine: masthead, 4-col balancer, footer
```

The UI and the engine are intentionally decoupled. `main.dart` builds a `List<Article>` from form state and hands it to `PdfGeneratorService.generateA5Newspaper()`. The service knows nothing about Flutter widgets; the UI knows nothing about PDF primitives.

---

## Layout engine highlights

- **4-column grid** with 15pt gutters and 0.3pt column rules on A5 format
- **Greedy balancer**: assigns each paragraph to the shortest column at insertion time, producing visually balanced spreads without multi-pass measurement
- **Geometric height estimator**: replaces opaque magic constants with `charsPerLine = colWidth / (fontSize × charWidthRatio)` and `lineHeight = fontSize × 1.6`
- **Masthead**: publication title at 30pt with flanking 3pt rules, date bar, and edition info
- **Footer**: "Página X de N" in 6.5pt italic, pre-computed before the page loop to work around `pw.Page`'s lack of a reliable `pagesCount` in build callbacks
- **Byline**: dynamic — renders "POR [AUTHOR NAME]" if supplied, falls back to "POR LA REDACCIÓN"

---

## Running locally

### Prerequisites

- Flutter 3.41+ with Linux desktop enabled (`flutter config --enable-linux-desktop`)
- On WSL/Ubuntu: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `lld`

```bash
flutter pub get
flutter run -d linux
```

### Release build

```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

---

## Design decisions

**Why not `pw.MultiPage`?** The masthead and footer require precise placement relative to page boundaries, and `MultiPage`'s automatic flow breaks that contract. `pw.Page` with a manual loop gives full control over what appears on each page and where.

**Why embed fonts?** Base14 PDF fonts (Times, Helvetica) are not guaranteed to render identically across all PDF readers. Embedding Libre Baskerville ensures the newspaper aesthetic is preserved regardless of the viewer.

**Why VBScript launcher?** The native binary runs under WSL. A `.vbs` script invoking `wsl.exe` with window style `0` launches the GTK window without showing any terminal — the end-user experience is identical to a natively installed Windows application.

---

*Developed for the Hobart independent press client.*
