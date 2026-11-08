# Borzoi

A small, local-first diagram workspace built with Bend and Bend-UI 1.0.3.

## First release

- Projects containing multiple named diagrams.
- View mode and text editing with a live preview.
- A Mermaid-compatible flowchart subset, parsed by our own Bend code.
- Automatic local draft saving in IndexedDB.
- Version checkpoints, including automatic checkpoints when leaving the editor.
- Restoration that keeps the current draft and previous versions.
- JSON backups of all projects, source, and history; additive imports with fresh IDs.
- `.mmd` source export.
- Responsive navigation and an editor usable on a phone.

Data stays in this browser on this device. Opening the deployed site elsewhere does not synchronize projects. Download a backup and import it on the other device. Clearing browser data can remove local work; backups are separate files under your control.

## Supported syntax

```text
flowchart TD
  A[Question] --> B[Evidence]
  B -->|supports| C[Conclusion]
  A --> C
  D["A label with punctuation [and brackets]"]
  %% Comments are supported
```

`graph TD`, `flowchart TB`, semicolons, chained arrows, repeated node IDs, and Unicode labels are supported. IDs contain letters, digits, or underscores. The renderer supports top-to-bottom acyclic flows, rectangular nodes, up to 60 nodes and 120 connections, and source up to 20,000 characters. Other directions, shapes, return loops, subgraphs, styling directives, HTML labels, and other diagram families are outside this release. Unsupported or incomplete source is retained, and the last valid preview is shown when available.

## Run and verify

Requires Bend and Bun on PATH. There are no runtime package downloads.

```sh
bun run check
bun run test
bun run build
bun run dev
```

The preview is at `http://localhost:4173`. `dist/` is the self-contained static deployment output. `vendor/bend-ui/` is an unmodified snapshot of the user's existing library so source and deployment remain reproducible; `SOURCE.txt` records its origin. No changes were made to the upstream library.

## Architecture

- `src/Parser.bend`: bounded lexical scanner and parser; no Mermaid.js dependency.
- `src/Graph.bend`: resource limits and cycle detection before the library layout.
- `src/Domain.bend`: projects, selection, draft edits, checkpoints, restore, and additive imports.
- `src/LAWS.bend` / `src/PROOF.bend`: declared properties and checked proofs.
- `src/codec.js`: JSON boundary validation and serialization.
- `src/storage.js`: IndexedDB transactions with revision checks to prevent stale tabs from overwriting newer data.
- `src/main.js`: browser events, storage I/O, and DOM rendering.
- `src/app.css`: composition using the library's tokens and components.

## What the laws guarantee

Nine universally quantified laws cover exact source retention during editing, history preservation during editing and renaming, unchanged unselected documents and projects, missing-version restoration, empty-history lookup, and preservation of projects when changing mode.

Six finite regression laws check restoration of a working draft, duplicate checkpoint prevention, arrow direction, Unicode labels, rejection of an incomplete arrow, and preservation of explicit labels across bare node references. These are specific examples, not universal parser-correctness proofs.

The Bend checker passes all 15 product laws and the unchanged Bend-UI laws. The independent `bend src/PROOF.bend --verdict` audit requires Lean v4.34.0; it could not run in this environment because Lean is absent. Browser persistence, file APIs, styling, and compiler/runtime behavior are not covered by the mathematical laws; they have separate tests and browser checks. No claim of absolute absence of bugs is made.

## Backups and failure behavior

Backups have `format: "borzoi"` and `version: 1`. Imports are validated in full before changing state, preserve all existing projects, and assign fresh IDs. Backups up to 20 MB are accepted. Saving reports completion only after the IndexedDB transaction completes. Failed saves remain visible and allow downloading the in-memory workspace. Conflicting tabs stop editing and offer a backup before reloading. Stored data that fails validation is not overwritten; its original payload can be downloaded for recovery.

## Deployment

`.openai/hosting.json` identifies the private Sites deployment and serves `dist/`. The repository contains application source and sample diagrams only, never the browser's personal project data or backup files.
