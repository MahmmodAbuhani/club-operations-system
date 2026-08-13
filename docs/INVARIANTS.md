# Club Operations System invariant matrix

| Rule | Database guarantee | Application UX | Verification |
|---|---|---|---|
| Registered player joins matching sport | Composite FK from `PlaysOn(PersonID,SportID)` to `Registers` | Coach receives a registration requirement message | Direct-SQL rejection and coach negative HTTP mutation |
| Eligible coach staffs matching sport | Composite FK from `CoachesFor(PersonID,SportID)` to `CanCoach` | Admin sees an eligibility message | Direct-SQL rejection and admin flow |
| Team roster does not exceed capacity | `PlaysOn` trigger atomically increments `Team.CurrentRosterSize` only below `Sport.MaxRosterSize`; the runtime principal cannot update the counter | Coach sees open slots and a cap message | Runtime counter-tamper rejection, direct SQL, counter reconciliation, and synchronized two-session final-slot contention |
| Capacity cannot drop below occupancy | `Sport` update trigger signals before an invalid reduction | No current UI mutation | Direct-SQL rejection |
| Uniform number is unique within a team when non-null | Unique index `(TeamID,UniformNumber)`; MySQL permits multiple nulls | No current uniform-management UI | Direct SQL and two-session uniform race |
| At most one head coach | Generated `HeadCoachTeamID` plus unique index | Admin receives an existing-head message | Direct SQL, admin negative HTTP mutation, and two-session race |
| Demo team has exactly one head coach | Release-seed quality assertion | Not a general team-creation restriction | `sql/03_data_quality_checks.sql` |
| Order belongs to roster member | Composite FK from order to `PlaysOn` | Player only sees their team requirements | Direct SQL and tampered HTTP mutation |
| Order item is required for the sport | Composite FK from order to `Requires` | Invalid submissions receive a safe message | Direct SQL and tampered HTTP mutation |
| Roster removal cannot erase related order history | Restrictive order-to-membership FK rejects deletion while related order rows exist | Player receives a retained-history explanation | Direct SQL and state-asserted HTTP deletion rejection |
| Equipment fulfillment is cumulative | `EquipmentFulfillment` view sums order history and floors outstanding at zero | Player sees required, ordered, outstanding, and status | Zero, partial, complete, and over-complete SQL tests plus HTTP flow |
| HTTP mutations require intended role and CSRF | No database constraint represents an HTTP role, session, or CSRF token; least-privilege grants narrow writes and table rules still validate accepted rows | Method route map, role checks, ownership checks, and CSRF on every POST | Player/Coach/Admin 403s, invalid-token tests, and unchanged database assertions |

Application checks improve feedback and reject requests before a write. Database guarantees apply to ordinary data manipulation through the least-privilege `sportlfc` runtime principal. The administrative root account used to rebuild isolated test fixtures remains capable of schema administration.

The ERD lists all attributes from the 14 base tables. Composite uniqueness rules that cannot be represented accurately as single-column Mermaid markers are `(SportID, TeamName)` and `(TeamID, SportID)` on `Team`, `(TeamID, UniformNumber)` on `PlaysOn`, and the primary/composite keys shown in `sql/01_schema.sql`. `FeesOwed` and `EquipmentFulfillment` are derived views, not additional base tables.
