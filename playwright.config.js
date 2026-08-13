const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/e2e',
  workers: 1,
  retries: 0,
  reporter: 'line',
  use: {
    baseURL: process.env.SPORTLFC_BASE_URL || 'http://127.0.0.1:18084',
    trace: 'retain-on-failure'
  }
});
