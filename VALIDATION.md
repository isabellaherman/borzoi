# Release 0.1 validation

- Bend: all 15 product laws pass; unchanged Bend-UI laws pass.
- Automated tests: 15 pass, 120 assertions. Includes cross-project isolation, invalid source retention, restoration without loss, duplicate checkpoint prevention, backup round trips, additive imports with unique IDs, malformed backup rejection, supported syntax, Unicode, cycle rejection, and size bounds.
- Browser: created a project; edited a branching diagram with Unicode and an edge label; saved and restored versions; reloaded and retained source/history.
- Downloaded a JSON backup containing two projects and five historical versions. Re-imported that actual file; the workspace gained the two projects without replacing either existing project.
- Concurrent tabs: after one tab saved, the stale tab's attempted write was rejected and its editor disabled with recovery guidance.
- Responsive check at 390 × 844: editor, preview, and navigation work; the diagram and footer do not overlap; document width remains 390 px. Desktop composition checked at 1280 × 900.
- Production bundle is static and has no Mermaid.js dependency or remote runtime imports.

The additional independent kernel audit (`bend src/PROOF.bend --verdict`) was attempted. It requires Lean v4.34.0, which is not installed here, so it did not run. The successful standard Bend checks are reported separately from that unavailable audit.
