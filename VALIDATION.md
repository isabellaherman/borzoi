# Initial release validation (before the UI repair)

- Bend: all 15 product laws pass; unchanged Bend-UI laws pass.
- Automated tests: 15 pass, 120 assertions. Includes cross-project isolation, invalid source retention, restoration without loss, duplicate checkpoint prevention, backup round trips, additive imports with unique IDs, malformed backup rejection, supported syntax, Unicode, cycle rejection, and size bounds.
- Browser: created a project; edited a branching diagram with Unicode and an edge label; saved and restored versions; reloaded and retained source/history.
- Downloaded a JSON backup containing two projects and five historical versions. Re-imported that actual file; the workspace gained the two projects without replacing either existing project.
- Concurrent tabs: after one tab saved, the stale tab's attempted write was rejected and its editor disabled with recovery guidance.
- Responsive check at 390 × 844: editor, preview, and navigation work; the diagram and footer do not overlap; document width remains 390 px. Desktop composition checked at 1280 × 900.
- Production bundle is static and has no Mermaid.js dependency or remote runtime imports.

The additional independent kernel audit (`bend src/PROOF.bend --verdict`) was attempted. It requires Lean v4.34.0, which is not installed here, so it did not run. The successful standard Bend checks are reported separately from that unavailable audit.


## UI library boundary repair — 2026-11-08

- The application stylesheet and component overrides were removed. No invented brand mark, positional node coloring, node minimum-width override or input-border override remains.
- The real Bend UI working tree owns the new components. The consumer snapshot is hash-locked to that source. Original `ui.css`, `LAWS.bend` and `SPEC.bend` remain unchanged.
- Standard Bend checks cover the 15 product laws, original library laws and 15 new workspace laws. Existing law statements were not weakened.
- The new source guard rejects the former override pattern, inline/injected styles, unknown literal classes, missing/tampered vendor files and extra unregistered snapshot files. It runs before build output is replaced.
- Adapter regression tests cover the actual JavaScript-to-compiled-Bend boolean boundary. Browser verification caught and corrected an initial adapter mismatch; formal Bend proofs alone could not catch it.
- The separate library component artifact is built at `/components/` alongside the app. No remote runtime imports are required.
- No commit, tag or production deployment was performed for this repair. Visual additions remain a proposal for owner review.

- Final automated result: 21 tests passed, 146 assertions, zero failures; app and component artifact builds succeeded.
- Browser checks after repair: desktop editor/preview sit side by side; at 390 × 844 they stack and document width stays 390 px. Input border remains the library's 1 px border. Rename/cancel and history dialogs fit the narrow viewport. Opening and closing the mobile sidebar works; closed offscreen controls become inert. The source and existing history remain present after reload.


## Empty production editor — 0.1.0

- First launch has no projects, diagrams, source text or synthetic history, and opens in edit mode. The first user input creates the document; explicit new projects and diagrams start blank.
- Blank drafts show an empty preview, including after clearing a previously valid diagram. No old diagram is shown for deliberately empty source.
- The startup migration removes only the complete, untouched seed from the first deployment. Any edit, rename, added document/project or changed history preserves the existing workspace.
- Empty workspace backups round-trip correctly. Importing into an empty workspace selects an imported document and survives reload.
- Four additional product laws cover empty startup, blank new documents, no synthetic blank checkpoint and no project creation on an empty input event. Existing laws remain intact.
- The UI version reads package.json and displays 0.1.0. The tab title and description use generic diagram wording; the footer uses the existing Bend UI link component for `Made with Bend-UI`.
- Standard checks, 29 tests (188 assertions) and the Pages build pass. No application stylesheet or library style override was added.
