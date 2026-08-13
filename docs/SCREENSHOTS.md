# Verified interface evidence

These screenshots are generated from a freshly seeded Docker Compose application by `scripts/capture_evidence.sh`. Each image is tied to a tested workflow.

## Login and local-demo boundary

![Club Operations System login form with fictional demo-account guidance](screenshots/01-login.png)

## Overlapping roles

Riley Bennett is the fictional fixture with both Player and Coach roles. The dashboard shows both navigation sets for that authenticated identity; the HTTP suites provide the authorization and denial evidence.

![Riley Bennett dashboard showing Player and Coach navigation](screenshots/02-riley-dashboard.png)

## Cumulative equipment fulfillment

The player view reports required, ordered, outstanding, and completion status. Each submitted application order adds a history row; no single row must satisfy the whole requirement.

![Equipment fulfillment cards showing cumulative status and order forms](screenshots/03-equipment-fulfillment.png)

## Administrator analytics

The reports page displays queries derived from the same constrained relational model used by the role workflows.

![Administrator analytics tables generated from the deterministic seed](screenshots/04-admin-analytics.png)

Screenshots record visible seeded states, not security or concurrency guarantees. Run `make verify` and inspect `tests/sql` and `tests/http` for executable rejection, state-preservation, and race evidence.

## Social preview

![Club Operations System social preview combining a local-system summary with the fictional equipment fulfillment capture](social-preview.png)

The social preview is composed from the equipment capture above. Its fixed build path and local-only boundary are documented in [`SOCIAL_PREVIEW.md`](SOCIAL_PREVIEW.md).

The checked-in visual hashes are recorded in [`VISUAL_HASHES.md`](VISUAL_HASHES.md).
