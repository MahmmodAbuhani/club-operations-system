# Validation record

This verification record began with an isolated local checkout on August 11, 2026 and was refreshed on August 19, 2026 after the public workflow, accessibility, evidence, and Streamlit surfaces were repaired and the complete native verification command was rerun. The [GitHub Actions history](https://github.com/MahmmodAbuhani/club-operations-system/actions/workflows/ci.yml) records hosted verification by commit, and the [static evidence walkthrough is hosted on GitHub Pages](https://mahmmodabuhani.github.io/club-operations-system/). The PHP/MySQL system remains local. Local checks and static hosting do not establish a production operating record. Later code changes require a new exact-revision verification before their results are described as current.

## Environment

| Component | Verified value |
|---|---|
| Docker | 29.5.3 |
| Docker Compose | v5.1.4 |
| Pinned MySQL image | MySQL 8.0.46 OCI index with `linux/amd64` and `linux/arm64/v8` manifests |
| Pinned PHP image | PHP 8.3.33 with Apache |
| Node.js / npm | 26.3.0 / 11.16.0 locally; CI targets Node 22 |
| Playwright / axe | 1.62.1 / 4.12.1 |
| Mermaid CLI | 11.16.0 from `package-lock.json` |
| Python / Streamlit | Python 3.13.7 / Streamlit 1.62.0 in the isolated companion QA environment |

The MySQL and PHP images were resolved by immutable digest. `make verify-image` inspected the MySQL registry index at its pinned digest and found both required platform manifests. The local Docker execution used the host's ARM64 image; registry inspection did not execute the AMD64 image. The dependency tree was installed from `package-lock.json`; the offline local npm audit, using locally cached advisory data, reported zero known vulnerabilities in the locked dependency tree.

## Complete command

```bash
make verify
```

On August 19, 2026 the command exited successfully with `Club Operations System complete verification passed.` It performs eight dependency-ordered stages:

1. Compose validation, PHP lint, all repository shell-script syntax checks, and public-surface assertions.
2. Lockfile install, exact Chromium availability, dependency audit, and the portable release-contract tests discovered from `tests/release/*.test.mjs`, including the static walkthrough release contracts.
3. Five walkthrough browser checks covering its static boundary, local-only runtime requests, desktop scenario discoverability, axe scan, scenario data, evidence provenance, keyboard tabs, and 320 CSS-pixel walkthrough reflow.
4. Fresh isolated MySQL direct-SQL invariant tests.
5. Fresh isolated MySQL two-session concurrency races.
6. Fresh Docker equipment-fulfillment HTTP flow.
7. Fresh Docker session, route, CSRF, authorization, and role-flow tests.
8. Fresh Docker Playwright, axe, keyboard-focus, and 320 CSS-pixel application reflow checks.

Every Docker test project removes its containers, network, and data volume on exit, so suites do not share database state.

## Streamlit companion verification

The [live Streamlit companion](https://club-operations-system-demo.streamlit.app/) runs the same fixture-backed read-only surface. The companion verification path exports the snapshot from the schema and seed SQL, checks collection counts and sensitive-field exclusions, runs pure Python transformation tests, and exercises the read-only browser surface. The Streamlit view uses progress tables and summaries instead of a chart renderer so the public surface stays readable on narrow screens without browser chart warnings. The Playwright check selects Soccer and confirms the resulting fixture rows are present in the rendered data-grid surface. Run `make fixture-snapshot` followed by `make verify-streamlit` from the repository root.

## Verified database contract

All 16 release-seed reconciliation checks passed, including exactly one head coach for every demo team, roster-counter agreement, and fulfillment view cardinality and aggregation.

Behavioral tests also passed for:

- zero, partial, complete, and over-complete cumulative fulfillment while preserving order history;
- duplicate non-null uniform-number rejection within a team;
- second-head-coach rejection;
- coach eligibility and player registration enforcement;
- required-item and roster-membership enforcement for equipment orders;
- rejection of capacity reductions below current occupancy;
- the Riley Bennett fictional overlapping-role fixture.

Three synchronized two-session races each produced exactly one valid winner: the final roster slot, the head-coach role, and one uniform number. Each worker wrote a ready marker, waited for the shared release marker, began a transaction, and delayed in-session before the competing insert.

## Verified HTTP and accessibility contract

- Riley's player flow displayed cumulative required, ordered, outstanding, and fulfillment state.
- Player, Coach, overlapping-role, and Admin workflows passed with cross-role and ownership denials.
- Tampered equipment and coaching mutations returned a denial and left database state unchanged.
- A named `roster_capacity_exceeded` trigger conflict returned the friendly roster-capacity message without a write, while an unrelated trigger failure retained the generic 500 response.
- Unknown routes returned 404, wrong methods returned 405, invalid CSRF returned 403, logout was POST-only, and the session cookie was cleared.
- Five static walkthrough browser checks confirmed the no-backend disclosure, no external runtime requests, all four scenario names and the primary evidence path in the 1440 by 900 opening, zero automated WCAG A or AA violations, Arrow key plus Home and End tab behavior, repository visual provenance, and 320 CSS-pixel reflow.
- Four Playwright pages received automated axe scans. The login test also checked visible keyboard focus, role navigation exposes the current page, report tables expose labeled keyboard-scroll regions, and a separate test checked 320 CSS-pixel reflow.

Automated accessibility checks do not replace manual assistive-technology testing. A screen-reader pass remains outside the completed checks.

## Manual browser and visual checks

The local application was regenerated and inspected on August 18, 2026 after a fresh Docker fixture started on a dedicated test port.

- Riley Bennett's dashboard exposed both Player and Coach navigation.
- The equipment view rendered 11 requirement cards, including 2 complete cards, with no page-level horizontal overflow at desktop width.
- Priya Nair's reports view rendered all 5 analytics tables with no page-level horizontal overflow at desktop width.
- The login, dashboard, equipment, and reports views had no page-level horizontal scrolling at 320 CSS pixels. At that width, three reports tables used their scoped horizontal wrappers for columns wider than the available space.
- Direct focus inspection on the login email control showed the documented 3-pixel amber outline with a 3-pixel offset.
- The browser console contained no warning or error entries during the inspected flows.
- All four regenerated application screenshots and the social preview were inspected at original resolution for clipping, legibility, real personal data, credentials, browser chrome, and misleading deployment language.

The static walkthrough was inspected separately in Chrome at 1440 by 900, 375 by 812, and 320 by 800 CSS pixels.

- The desktop first screen identified the artifact as a static evidence walkthrough, kept the no-backend boundary visible, and exposed all four scenario names plus the primary scenario-evidence link without scrolling.
- Activating the primary scenario-evidence link from the keyboard moved to `#scenarios`, where the selected Role authorization tab and evidence panel were visible.
- Changing from equipment fulfillment to invariant handling updated the rule, expected outcome, limitation, source links, authentic fixture visual, caption, and SHA-256 record.
- Arrow-key selection moved focus with a visible amber outline and updated the selected tab and panel relationship.
- At 375 and 320 CSS pixels, the document had no page-level horizontal overflow. At 320 CSS pixels, the scenario labels had no clipped text.
- The walkthrough console contained no warning or error entries during the inspected flow.

A full manual keyboard traversal, an actual 400 percent browser-zoom session, and a screen-reader session were not performed. The 320 CSS-pixel inspection is narrow-width reflow evidence, not a substitute for those checks. Automated axe results and the checks above do not establish assistive-technology compatibility.

Before describing accessibility as complete, perform and record these manual checks in a real browser:

- Traverse login, navigation, search, forms, tables, and sign-out with keyboard only. Confirm focus order, visible focus, skip-link behavior, and that every action is reachable without a pointer.
- Test browser zoom at 400 percent and confirm the application remains usable without clipped controls or page-level horizontal scrolling. Scoped table scrolling is acceptable when the table region is labeled and keyboard focusable.
- Test the login, dashboard, equipment, coach, and reports flows with VoiceOver or another screen reader. Confirm headings, navigation state, form labels, status/error announcements, table headers, and the static-demo boundary are understandable.

## Generated evidence

`scripts/capture_evidence.sh` rebuilt a fresh Docker application, authenticated seeded demo roles, and generated the four screenshots catalogued in [`SCREENSHOTS.md`](SCREENSHOTS.md). It then generated the 1280 by 640 [`social-preview.png`](social-preview.png) from the authentic equipment capture using [`scripts/build_social_preview.mjs`](../scripts/build_social_preview.mjs). The relational diagram in [`erd.svg`](erd.svg) was regenerated from the current schema-backed Mermaid source in [`erd.mmd`](erd.mmd). It contains native SVG text nodes, accessible title and description metadata, and the exact names and casing of all 14 base tables and 2 derived views.

The repository includes a top-level security policy that directs reports through GitHub's private **Report a vulnerability** form when that control is available. Source text does not enable or prove a remote security setting.

Passing local and fresh-clone checks apply only to the exact revision and stated local environment. GitHub Actions outcomes apply only to their recorded commit SHA. GitHub Pages hosts only the static evidence walkthrough. Branch rules, security settings, repository metadata, PHP/MySQL deployment, production operation, and release creation require separate evidence.
