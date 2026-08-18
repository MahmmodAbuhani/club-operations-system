# Interactive Python demo

Interactive Python demo — fixture-backed; not the PHP/MySQL runtime.

This companion gives visitors a read-only, browser-based view of the same fictional club operations data. It loads [`demo/fixture_snapshot.json`](../demo/fixture_snapshot.json), applies pure Python transformations from [`demo/streamlit_data.py`](../demo/streamlit_data.py), and renders roster capacity, equipment fulfillment, staffing, and fee summaries.

Open the [live interactive Python demo](https://club-operations-demo.streamlit.app/) to inspect the fixture-backed view in a browser without local setup.

The snapshot is exported from [`sql/01_schema.sql`](../sql/01_schema.sql) and [`sql/02_seed.sql`](../sql/02_seed.sql). It contains display names and operational values only; credentials, phone numbers, guardian names, and birth dates are not included. The companion does not connect to MySQL, submit mutations, or represent the PHP application as a hosted service.

## Run locally

From the repository root:

```bash
python3 -m venv .streamlit-venv
.streamlit-venv/bin/python -m pip install -r demo/requirements.txt
.streamlit-venv/bin/streamlit run demo/streamlit_app.py
```

Open the local URL printed by Streamlit. Use the sport filter to recalculate the tables and charts. The reproducible checks are:

```bash
make fixture-snapshot
make verify-streamlit
```

The Python tests cover the snapshot contract and pure transformations. The Playwright smoke test checks the boundary label, KPI surface, filter interaction, and rendered data-grid surface.

## Source boundary

The [GitHub Pages walkthrough](https://mahmmodabuhani.github.io/club-operations-system/) remains the static evidence layer. The [live Streamlit companion](https://club-operations-demo.streamlit.app/) is the interactive Python view. The PHP/MySQL system remains available through the local Docker workflow described in [`README.md`](../README.md).
