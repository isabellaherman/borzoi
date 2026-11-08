# Borzoi working rules

- Learn the current language with `bend guide`; keep domain logic in Bend.
- Preserve the Mermaid syntax subset and document its boundaries.
- Run `bun run check`, `bun run test`, and `bun run build` before delivery.
- Never weaken or delete an existing product law to make an implementation pass.
- Keep universally quantified laws distinct from finite regression examples.
- Preserve source and historical versions across edits, imports, and restoration.
- Keep browser I/O in narrow adapters; report failed saves instead of claiming success.
- Use only Bend UI visual components. Application CSS, inline styles, custom visual classes, and component overrides are forbidden even if they use library tokens.
- Inspect and document each unmet visual need in the real Bend UI repository first. Extend its tokens, components, laws and review artifact; then synchronize with `bun scripts/sync-bend-ui.mjs`. Never patch the vendor copy directly.
- Do not change Bend UI's original `LAWS.bend` or `SPEC.bend`. Its own AGENTS.md applies to library changes.
- Keep `vendor/bend-ui/docs/BORZOI-NEEDS.md` and the `/components/` artifact current so the owner can review every library addition.
- The UI boundary guard runs before builds and checks. Do not bypass it, edit its allowlist to hide overrides, or regenerate the source lock from the consumer.
- Formal laws cover their declared properties; do not claim they prove browser rendering or guarantee zero bugs.
- The owner authorized the Borzoi commit, public GitHub push and GitHub Pages publication on 2026-11-08. Keep independent Bend UI releases/tags outside this repository task.
- Before committing app changes for Pages, run `bun run pages` and include the regenerated `docs/` output.
- Keep code, documentation, and product UI in English.
- Do not put personal browser data, backups, or credentials into the repository.

- Production starts with no projects, diagrams, source, or synthetic history; the empty editor is immediately usable. Keep fixtures in tests and opt-in documentation only.
- Read the displayed application version from package.json; show all three components (0.1.0).
- Keep product copy generic to diagrams. The browser tab title is `Borzoi — Diagrams`; never derive product branding from demo data.
- The standard footer credit is exactly `Made with Bend-UI`, linked to `https://github.com/isabellaherman/Bend-UI`, using the existing library link and detail components.
