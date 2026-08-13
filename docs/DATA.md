# Demonstration data contract

`sql/02_seed.sql` is deterministic, hand-authored fictional fixture data for local testing and technical inspection.

- It does not come from an external data provider.
- It contains no operational customers, athletes, minors, payments, or credentials.
- Email addresses use the reserved `.test` domain.
- Phone numbers use fictional 555 values.
- Names are synthetic demonstration identities; Riley Bennett is the overlapping Player/Coach example.
- Every demo login uses `demo123` and must never be reused outside this local reference application.

The seed exists to reproduce domain relationships, rejected mutations, analytics outputs, and concurrency tests. It must not be presented as real-world program data.

## Rights and license

The seed is repository-authored fictional material. Unless a file states otherwise, the top-level [MIT License](../LICENSE) applies to the code, repository-authored documentation, hand-authored fictional fixtures, Mermaid ERD source and generated SVG, deterministic query outputs, and screenshots generated from this fixture. Third-party dependencies retain their own licenses. No trademark or real-club affiliation rights are asserted or granted.
