# Development

Requires Bend and Bun on PATH. No runtime package installation is needed.

```sh
bun run check
bun run test
bun run build
bun run dev
```

The app runs at `http://localhost:4173/`. The library component review is at `http://localhost:4173/components/`.

## GitHub Pages

Pages publishes the committed `docs/` directory from `main`. It contains the compiled application and `.nojekyll`; source files, local data and library review artifacts are not included in the site output.

Before committing changes to the application, regenerate the site:

```sh
bun run pages
```

This runs the architecture checks, Bend proofs, regression tests and build before updating `docs/`. Commit source changes and the generated `docs/` files together. Pushing `main` then triggers the GitHub Pages deployment.

## Bend UI

Every visual component belongs to the real Bend UI library. Document missing needs there, implement and check them, then update the consumer with `bun scripts/sync-bend-ui.mjs /path/to/Bend-UI`.

The vendored files are checked against `SOURCE.lock.json`. Do not edit them directly or introduce application CSS. See `vendor/bend-ui/docs/BORZOI-NEEDS.md` for the component register, and `VALIDATION.md` for proof scope and validation results.

Diagram data lives in the browser's IndexedDB. Different site origins have separate storage. Use Download backup and Import backup to move projects, source and history between the local app and the published site.

## Documents and Why

A project holds diagrams and documents. A document is text in blocks (paragraphs, headings, lists, quotes) with the project's diagrams in it as figures, saved as standard Markdown. A Why entry is the idea behind a diagram and what it gives up, kept beside the diagram and never in its Mermaid.

- `src/editor/`: the block editor. `Editor.bend` is the model (blocks, steps with inverses, history, what each key means), `Markdown.bend` writes and reads the document, `editor.js` draws it and reads the keys. This folder is a local copy of the editor proposed to Bend-UI in https://github.com/isabellaherman/Bend-UI/pull/1. When the library ships it, sync Bend UI, import `bend-ui/editor` and remove the folder. Until then the document screen uses only classes the library already has, so a block's alignment is saved but not shown, and quotes, captions and the focus ring are drawn as the browser draws them.
- `src/workspace/Workspace.bend`: documents and Why entries, next to the diagrams. `src/workspace/Figures.bend`: a figure points to its diagram with a Mermaid comment in the first line of its source (`%% borzoi diagram 12`), shows the diagram as it is now, and keeps its own copy for when the diagram is deleted.
- Save format 2 only adds `why` to a diagram and `documents` to a project. A workspace that uses neither is still written as format 1, byte for byte. To check a real backup: `BORZOI_BACKUP=/path/to/backup.json bun run test` (never commit the backup).
- Compiled to JavaScript, Bend text is a browser string, and a def that walks it letter by letter with a call that is not its last act uses one stack frame per letter. The editor's defs are written as loops for that reason (see the note in `Editor.bend`).

