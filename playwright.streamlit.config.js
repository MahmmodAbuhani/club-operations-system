const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/e2e',
  testMatch: 'streamlit.spec.js',
  workers: 1,
  retries: 0,
  reporter: 'line',
  webServer: {
    command: 'streamlit run demo/streamlit_app.py --server.headless true --server.port 8512 --browser.gatherUsageStats false',
    url: 'http://127.0.0.1:8512',
    reuseExistingServer: true,
    timeout: 120000
  },
  use: {
    baseURL: 'http://127.0.0.1:8512',
    trace: 'retain-on-failure'
  }
});
