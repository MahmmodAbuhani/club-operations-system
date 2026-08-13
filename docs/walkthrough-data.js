export const repositoryUrl = 'https://github.com/MahmmodAbuhani/club-operations-system';

const source = (path) => `${repositoryUrl}/blob/main/${path}`;

export const scenarios = [
  {
    id: 'role-authorization',
    kicker: 'Application boundary',
    title: 'A route is available only to the intended role',
    rule:
      'The route map requires the named role, and every mutation also requires the intended method, ownership, and a valid cross-site request forgery token.',
    expected:
      'An unauthorized request returns 403 and leaves the fixture unchanged. A person with overlapping roles receives only the navigation and actions supported by those roles.',
    limitation:
      'This walkthrough does not authenticate or submit requests. The result comes from the executable HTTP suites and the captured local fixture state.',
    evidence: [
      { label: 'Route and method map', href: source('web/public/index.php') },
      { label: 'Session and role guards', href: source('web/src/bootstrap.php') },
      { label: 'Role denial tests', href: source('tests/http/roles.sh') },
      { label: 'CSRF and state-preservation tests', href: source('tests/http/security.sh') }
    ],
    visual: {
      src: 'screenshots/02-riley-dashboard.png',
      alt: 'Fictional Riley Bennett dashboard with Player and Coach navigation visible',
      caption:
        'Authenticated fictional fixture showing the navigation produced for a person who has both Player and Coach roles. It shows visible state, not the rejected-request proof.',
      sha256: 'dec403eb55738c50c85d0bf0cf8eb1fc303577b96827c7ee13d8a192bf4027eb'
    }
  },
  {
    id: 'roster-concurrency',
    kicker: 'Concurrent database writes',
    title: 'Two final-slot writes serialize to one valid winner',
    rule:
      'The roster trigger locks the team row and increments its protected counter only while occupancy remains below the sport capacity. The runtime database principal cannot edit that counter directly.',
    expected:
      'When two synchronized sessions compete for the final slot, exactly one insert succeeds, one is rejected, and the stored roster count remains equal to membership rows.',
    limitation:
      'The test covers a deterministic two-session race in local MySQL. It is an integrity check, not a throughput, latency, or distributed-load benchmark.',
    evidence: [
      { label: 'Capacity trigger and roster key', href: source('sql/01_schema.sql') },
      { label: 'Runtime grants', href: source('sql/04_app_grants.sh') },
      { label: 'Synchronized race test', href: source('tests/sql/concurrency.sh') },
      { label: 'Invariant matrix', href: source('docs/INVARIANTS.md') }
    ],
    visual: {
      src: 'erd.svg',
      alt: 'Entity relationship diagram for the fourteen-table fictional club operations schema',
      caption:
        'Generated ERD for the schema exercised by the race. Mermaid does not express the trigger lock itself, so the schema and concurrency test remain the executable evidence.',
      sha256: '76da6c50a354cbed0a101fe730a4ea1fcff5a9fba8f9a80bd9bc07dd7f0b0bf7'
    }
  },
  {
    id: 'equipment-fulfillment',
    kicker: 'History-preserving workflow',
    title: 'Order history accumulates toward fulfillment',
    rule:
      'Equipment orders remain separate history rows. A derived view sums them against each sport requirement and floors the outstanding quantity at zero.',
    expected:
      'Two one-unit orders complete a two-unit requirement. Additional orders preserve their rows, keep the status complete, and do not create a negative outstanding quantity.',
    limitation:
      'The workflow uses a deterministic fictional fixture. It does not model purchasing, payments, stock locations, delivery, or a production inventory service.',
    evidence: [
      { label: 'Order schema and fulfillment view', href: source('sql/01_schema.sql') },
      { label: 'Application query and write path', href: source('web/src/repository.php') },
      { label: 'HTTP fulfillment flow', href: source('tests/http/fulfillment.sh') },
      { label: 'SQL zero-to-over-complete checks', href: source('tests/sql/invariants.sh') }
    ],
    visual: {
      src: 'screenshots/03-equipment-fulfillment.png',
      alt: 'Fictional equipment fulfillment screen with required, ordered, outstanding, and status values',
      caption:
        'Authenticated fictional fixture showing cumulative fulfillment values from the derived view. The SQL and HTTP suites establish the transitions and preserved history.',
      sha256: '5b1962ec42d502ff202001b9abfedef432771ccbcbc8408f4f49c83dbfe08c6e'
    }
  },
  {
    id: 'invariant-handling',
    kicker: 'Declarative integrity',
    title: 'Invalid relationships fail without changing valid state',
    rule:
      'Composite foreign keys, checks, unique indexes, and triggers reject unregistered roster membership, ineligible staffing, duplicate team uniform numbers, invalid equipment orders, and capacity reductions below occupancy.',
    expected:
      'Each negative mutation fails on the named database rule. Follow-up assertions confirm that protected membership, order history, counters, and valid rows remain unchanged.',
    limitation:
      'The administrative root account can rebuild fixtures and change schema. The documented guarantees apply to ordinary writes through the limited runtime principal.',
    evidence: [
      { label: 'Relational constraints and triggers', href: source('sql/01_schema.sql') },
      { label: 'Negative mutation suite', href: source('tests/sql/invariants.sh') },
      { label: 'Rule-by-rule boundary', href: source('docs/INVARIANTS.md') },
      { label: 'Generated relational model', href: source('docs/erd.svg') }
    ],
    visual: {
      src: 'screenshots/04-admin-analytics.png',
      alt: 'Fictional admin analytics screen generated from the validated local relational fixture',
      caption:
        'Authenticated fixture analytics derived from valid rows after schema checks. A screen cannot show rejected writes, so the negative SQL assertions provide that evidence.',
      sha256: '66fb8ad4ae8cb79a79fe48fa1e9705312a8ca67eff33b239e77166a582169e94'
    }
  }
];
