# Changelog

All notable changes to this project are documented here.
This project follows [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-31

### Added

- `SKILL.md`: a three-gate interactive workflow — clarify ambiguous requests,
  pick a research-oriented palette/style/page width, then choose export formats
  from a multi-select prompt — before the diagram is generated.
- `scripts/Export-Drawio.ps1`: offline wrapper around the draw.io Desktop CLI.
  Resolves `draw.io.exe` (parameter → `DRAWIO_EXE` → `PATH` → install roots →
  uninstall registry), waits for the GUI-subsystem process, supports several
  output formats in one call, creates parent directories, and verifies that
  every output file exists and is non-empty.
- `references/style-presets.md`: print-safe grey, Okabe–Ito, journal blue-grey
  and high-contrast palettes with ready-to-paste Mermaid `classDef` and draw.io
  `style` strings, plus page-width and DPI guidance and a pre-delivery checklist.
- `references/cli-reference.md`: the full draw.io Desktop CLI option table taken
  from the shipped `src/main/args.js` of version 32.6.1.
- `examples/`: minimal Mermaid and draw.io sources, a paper-style CNN-style
  flow, and rendered previews.

### Known limitations

- draw.io Desktop is an Electron app and cannot start inside a sandboxed shell
  that blocks named pipes (Chromium mojo IPC); it exits with `0x80000003`.
  Run the export from a normal terminal or outside the sandbox.
- Mermaid support comes from draw.io's built-in parser and does not cover every
  upstream Mermaid feature; complex figures are better authored as draw.io XML.
