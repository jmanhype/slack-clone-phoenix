/**
 * Playwright Configuration for Slack Clone Frontend Tests
 */

const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/frontend',
  timeout: 30 * 1000,
  expect: {
    timeout: 5000,
  },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { outputFolder: 'tests/frontend/playwright-report' }],
    ['json', { outputFile: 'tests/frontend/test-results.json' }],
    ['junit', { outputFile: 'tests/frontend/test-results.xml' }]
  ],
  use: {
    baseURL: 'http://localhost:4000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 0,
    navigationTimeout: 10000,
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] },
    },
    {
      name: 'Microsoft Edge',
      use: { ...devices['Desktop Edge'], channel: 'msedge' },
    },
  ],

  webServer: {
    command: 'mix phx.server',
    port: 4000,
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});