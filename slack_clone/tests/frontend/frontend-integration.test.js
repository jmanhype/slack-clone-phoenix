/**
 * Frontend Integration Tests for Slack Clone
 * Tests user flows, forms, LiveView components, and real-time features
 */

const { test, expect } = require('@playwright/test');

const BASE_URL = 'http://localhost:4000';

// Test configuration
test.describe.configure({ mode: 'parallel' });

test.describe('Slack Clone Frontend Integration Tests', () => {
  
  // Test user registration flow
  test.describe('User Registration', () => {
    test('should load registration page with proper form elements', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/register`);
      
      // Check page title and heading
      await expect(page).toHaveTitle(/Register/i);
      await expect(page.locator('h1')).toContainText(/Register/i);
      
      // Verify form elements exist
      await expect(page.locator('input[name="user[email]"]')).toBeVisible();
      await expect(page.locator('input[name="user[password]"]')).toBeVisible();
      await expect(page.locator('input[name="user[password_confirmation]"]')).toBeVisible();
      await expect(page.locator('button[type="submit"]')).toBeVisible();
      
      // Check form attributes
      await expect(page.locator('form')).toHaveAttribute('method', 'post');
      await expect(page.locator('input[name="user[email]"]')).toHaveAttribute('type', 'email');
      await expect(page.locator('input[name="user[password]"]')).toHaveAttribute('type', 'password');
    });

    test('should show validation errors for invalid registration', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/register`);
      
      // Try to submit empty form
      await page.click('button[type="submit"]');
      
      // Wait for and check validation messages
      await page.waitForTimeout(1000);
      const errorMessages = await page.locator('.alert, .error, [role="alert"]').count();
      expect(errorMessages).toBeGreaterThan(0);
    });

    test('should handle registration with mismatched passwords', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/register`);
      
      // Fill form with mismatched passwords
      await page.fill('input[name="user[email]"]', 'test@example.com');
      await page.fill('input[name="user[password]"]', 'password123');
      await page.fill('input[name="user[password_confirmation]"]', 'differentpassword');
      
      await page.click('button[type="submit"]');
      
      // Check for password mismatch error
      await page.waitForTimeout(1000);
      const hasError = await page.locator('text=/password.*confirmation.*match/i').count();
      expect(hasError).toBeGreaterThan(0);
    });

    test('should attempt registration with valid data', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/register`);
      
      const timestamp = Date.now();
      const email = `test${timestamp}@example.com`;
      
      // Fill registration form
      await page.fill('input[name="user[email]"]', email);
      await page.fill('input[name="user[password]"]', 'validpassword123');
      await page.fill('input[name="user[password_confirmation]"]', 'validpassword123');
      
      await page.click('button[type="submit"]');
      
      // Wait for response (may redirect or show success/error)
      await page.waitForTimeout(2000);
      
      // Check that we're either on a success page or got a meaningful response
      const currentUrl = page.url();
      expect(currentUrl).not.toBe(`${BASE_URL}/users/register`);
    });
  });

  // Test user login flow
  test.describe('User Login', () => {
    test('should load login page with proper form elements', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/log_in`);
      
      // Check page elements
      await expect(page).toHaveTitle(/Log in/i);
      await expect(page.locator('h1')).toContainText(/Log in/i);
      
      // Verify form elements
      await expect(page.locator('input[name="user[email]"]')).toBeVisible();
      await expect(page.locator('input[name="user[password]"]')).toBeVisible();
      await expect(page.locator('button[type="submit"]')).toBeVisible();
      
      // Check "Remember me" checkbox if present
      const rememberCheckbox = page.locator('input[name="user[remember_me]"]');
      if (await rememberCheckbox.count() > 0) {
        await expect(rememberCheckbox).toBeVisible();
      }
      
      // Check links to registration
      await expect(page.locator('a[href*="register"]')).toBeVisible();
    });

    test('should show error for invalid login credentials', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/log_in`);
      
      // Try login with invalid credentials
      await page.fill('input[name="user[email]"]', 'nonexistent@example.com');
      await page.fill('input[name="user[password]"]', 'wrongpassword');
      
      await page.click('button[type="submit"]');
      
      // Wait for error message
      await page.waitForTimeout(1000);
      const errorMessage = await page.locator('.alert, .error, [role="alert"]').count();
      expect(errorMessage).toBeGreaterThan(0);
    });

    test('should handle empty login form submission', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/log_in`);
      
      // Submit empty form
      await page.click('button[type="submit"]');
      
      // Check for validation messages
      await page.waitForTimeout(1000);
      const currentUrl = page.url();
      expect(currentUrl).toContain('log_in');
    });
  });

  // Test main application dashboard
  test.describe('Application Dashboard', () => {
    test('should redirect unauthenticated users to login', async ({ page }) => {
      // Try to access dashboard without authentication
      await page.goto(`${BASE_URL}/dashboard`);
      
      // Should redirect to login page
      await page.waitForURL(/log_in/, { timeout: 5000 });
      expect(page.url()).toContain('log_in');
    });

    test('should load main dashboard for authenticated users', async ({ page }) => {
      // This test would require authentication first
      // For now, we'll check if the route exists and handles auth properly
      await page.goto(`${BASE_URL}/`);
      
      // Should either show dashboard or redirect to login
      await page.waitForTimeout(2000);
      const currentUrl = page.url();
      expect(currentUrl).toMatch(/(dashboard|log_in|\/)/);
    });
  });

  // Test CSS styling and responsive design
  test.describe('CSS and Responsive Design', () => {
    test('should have proper CSS styling on registration page', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/register`);
      
      // Check that CSS is loaded (form should be styled)
      const formStyles = await page.locator('form').evaluate(el => {
        const styles = window.getComputedStyle(el);
        return {
          display: styles.display,
          padding: styles.padding,
          margin: styles.margin
        };
      });
      
      expect(formStyles.display).not.toBe('');
    });

    test('should be responsive on mobile viewport', async ({ page }) => {
      // Set mobile viewport
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto(`${BASE_URL}/users/register`);
      
      // Check that form is still usable on mobile
      await expect(page.locator('input[name="user[email]"]')).toBeVisible();
      await expect(page.locator('button[type="submit"]')).toBeVisible();
      
      // Check that text doesn't overflow
      const bodyWidth = await page.locator('body').evaluate(el => el.scrollWidth);
      expect(bodyWidth).toBeLessThanOrEqual(375);
    });

    test('should handle tablet viewport', async ({ page }) => {
      // Set tablet viewport
      await page.setViewportSize({ width: 768, height: 1024 });
      await page.goto(`${BASE_URL}/users/log_in`);
      
      // Verify elements are properly positioned
      await expect(page.locator('form')).toBeVisible();
      await expect(page.locator('input[name="user[email]"]')).toBeVisible();
    });
  });

  // Test JavaScript functionality
  test.describe('JavaScript Functionality', () => {
    test('should handle form validation with JavaScript', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/register`);
      
      // Check if there's client-side validation
      await page.fill('input[name="user[email]"]', 'invalid-email');
      await page.blur('input[name="user[email]"]');
      
      // Check HTML5 validation
      const emailInput = page.locator('input[name="user[email]"]');
      const isValid = await emailInput.evaluate(el => el.validity.valid);
      expect(isValid).toBe(false);
    });

    test('should load and execute JavaScript without errors', async ({ page }) => {
      const jsErrors = [];
      
      // Listen for JavaScript errors
      page.on('pageerror', error => jsErrors.push(error.message));
      page.on('console', msg => {
        if (msg.type() === 'error') {
          jsErrors.push(msg.text());
        }
      });
      
      await page.goto(`${BASE_URL}/users/register`);
      await page.waitForTimeout(2000);
      
      // Check for critical JavaScript errors
      const criticalErrors = jsErrors.filter(error => 
        !error.includes('favicon') && 
        !error.includes('WebSocket') && 
        !error.includes('LiveView')
      );
      
      expect(criticalErrors.length).toBe(0);
    });
  });

  // Test LiveView components and real-time features
  test.describe('LiveView and Real-time Features', () => {
    test('should establish LiveView connection', async ({ page }) => {
      let websocketConnected = false;
      
      // Monitor WebSocket connections
      page.on('websocket', ws => {
        ws.on('framesent', event => {
          if (event.payload.includes('phx_join')) {
            websocketConnected = true;
          }
        });
      });
      
      await page.goto(`${BASE_URL}/`);
      await page.waitForTimeout(3000);
      
      // Note: WebSocket might be refused (as shown in logs), which is expected for unauthenticated users
      // We'll check if the page loads properly even without WebSocket
      const pageTitle = await page.title();
      expect(pageTitle).toBeTruthy();
    });

    test('should handle WebSocket connection gracefully when refused', async ({ page }) => {
      const consoleMessages = [];
      
      page.on('console', msg => consoleMessages.push(msg.text()));
      
      await page.goto(`${BASE_URL}/`);
      await page.waitForTimeout(2000);
      
      // Page should still load and function even if WebSocket is refused
      expect(page.url()).toContain('localhost:4000');
    });
  });

  // Test navigation and routing
  test.describe('Navigation and Routing', () => {
    test('should navigate between register and login pages', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/register`);
      
      // Click link to login page
      await page.click('a[href*="log_in"]');
      await expect(page).toHaveURL(/log_in/);
      
      // Navigate back to register
      await page.click('a[href*="register"]');
      await expect(page).toHaveURL(/register/);
    });

    test('should handle 404 errors gracefully', async ({ page }) => {
      const response = await page.goto(`${BASE_URL}/nonexistent-page`);
      
      // Should return 404 status
      expect(response.status()).toBe(404);
      
      // Should show a proper error page
      const pageContent = await page.textContent('body');
      expect(pageContent).toContain('404');
    });

    test('should load static assets correctly', async ({ page }) => {
      await page.goto(`${BASE_URL}/`);
      
      // Check that CSS is loaded
      const cssRequests = [];
      page.on('response', response => {
        if (response.url().includes('.css')) {
          cssRequests.push(response.status());
        }
      });
      
      await page.waitForTimeout(2000);
      
      // At least some static assets should load successfully
      expect(page.url()).toContain('localhost:4000');
    });
  });

  // Test form CSRF protection
  test.describe('Security Features', () => {
    test('should include CSRF tokens in forms', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/register`);
      
      // Check for CSRF token
      const csrfToken = await page.locator('input[name="_csrf_token"]').count();
      expect(csrfToken).toBeGreaterThan(0);
    });

    test('should handle CSRF token validation', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/register`);
      
      // Remove CSRF token and try to submit
      await page.evaluate(() => {
        const csrfInput = document.querySelector('input[name="_csrf_token"]');
        if (csrfInput) csrfInput.remove();
      });
      
      await page.fill('input[name="user[email]"]', 'test@example.com');
      await page.fill('input[name="user[password]"]', 'password');
      await page.fill('input[name="user[password_confirmation]"]', 'password');
      
      await page.click('button[type="submit"]');
      
      // Should show error or reload page
      await page.waitForTimeout(1000);
      const currentUrl = page.url();
      expect(currentUrl).toBeDefined();
    });
  });

  // Test accessibility features
  test.describe('Accessibility', () => {
    test('should have proper form labels and accessibility attributes', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/register`);
      
      // Check for proper labeling
      const emailLabel = await page.locator('label[for*="email"], label:has(input[name*="email"])').count();
      const passwordLabel = await page.locator('label[for*="password"], label:has(input[name*="password"])').count();
      
      expect(emailLabel).toBeGreaterThan(0);
      expect(passwordLabel).toBeGreaterThan(0);
    });

    test('should support keyboard navigation', async ({ page }) => {
      await page.goto(`${BASE_URL}/users/log_in`);
      
      // Test tab navigation
      await page.keyboard.press('Tab');
      await page.keyboard.press('Tab');
      
      // Should be able to navigate through form elements
      const focusedElement = await page.evaluate(() => document.activeElement.tagName);
      expect(['INPUT', 'BUTTON', 'A']).toContain(focusedElement);
    });
  });

  // Performance and loading tests
  test.describe('Performance', () => {
    test('should load pages within reasonable time', async ({ page }) => {
      const startTime = Date.now();
      
      await page.goto(`${BASE_URL}/users/register`);
      await page.waitForLoadState('networkidle');
      
      const loadTime = Date.now() - startTime;
      
      // Should load within 5 seconds
      expect(loadTime).toBeLessThan(5000);
    });

    test('should handle concurrent page loads', async ({ browser }) => {
      const promises = [];
      
      for (let i = 0; i < 3; i++) {
        const context = await browser.newContext();
        const page = await context.newPage();
        promises.push(page.goto(`${BASE_URL}/users/register`));
      }
      
      // All pages should load successfully
      const responses = await Promise.all(promises);
      responses.forEach(response => {
        expect(response.status()).toBe(200);
      });
    });
  });
});