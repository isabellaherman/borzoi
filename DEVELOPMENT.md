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
