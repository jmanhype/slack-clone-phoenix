import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');
const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';

export const options = {
  stages: [
    { duration: '2m', target: 20 }, // Ramp up to 20 users
    { duration: '5m', target: 20 }, // Stay at 20 users
    { duration: '2m', target: 50 }, // Ramp up to 50 users  
    { duration: '5m', target: 50 }, // Stay at 50 users
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '5m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    http_req_failed: ['rate<0.01'],   // Error rate must be below 1%
    http_reqs: ['rate>100'],          // Must handle more than 100 requests/second
  },
};

export function setup() {
  // Setup test data if needed
  const response = http.get(`${BASE_URL}/health`);
  check(response, {
    'setup - health check passed': (r) => r.status === 200,
  });
  
  return { baseUrl: BASE_URL };
}

export default function(data) {
  // Test homepage
  const homeResponse = http.get(`${data.baseUrl}/`);
  check(homeResponse, {
    'homepage status is 200': (r) => r.status === 200,
    'homepage response time < 200ms': (r) => r.timings.duration < 200,
  }) || errorRate.add(1);

  sleep(1);

  // Test WebSocket connection endpoint
  const wsResponse = http.get(`${data.baseUrl}/socket/websocket`);
  check(wsResponse, {
    'websocket endpoint accessible': (r) => r.status === 101 || r.status === 400, // 400 is expected for HTTP request to WebSocket
  }) || errorRate.add(1);

  sleep(1);

  // Test API endpoint
  const apiResponse = http.get(`${data.baseUrl}/api/health`);
  check(apiResponse, {
    'api health status is 200': (r) => r.status === 200,
    'api response time < 100ms': (r) => r.timings.duration < 100,
  }) || errorRate.add(1);

  sleep(1);

  // Test login page
  const loginResponse = http.get(`${data.baseUrl}/login`);
  check(loginResponse, {
    'login page status is 200': (r) => r.status === 200,
    'login page response time < 300ms': (r) => r.timings.duration < 300,
  }) || errorRate.add(1);

  // Random sleep between 1-3 seconds to simulate real user behavior
  sleep(Math.random() * 2 + 1);
}

export function teardown(data) {
  // Cleanup if needed
  console.log('Load test completed');
}

// Custom scenarios for different load patterns
export const scenarios = {
  // Constant load
  constant_load: {
    executor: 'constant-vus',
    vus: 10,
    duration: '5m',
  },
  
  // Spike test
  spike_test: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '10s', target: 10 },
      { duration: '1m', target: 10 },
      { duration: '10s', target: 100 }, // Spike
      { duration: '1m', target: 100 },
      { duration: '10s', target: 10 },
      { duration: '1m', target: 10 },
      { duration: '10s', target: 0 },
    ],
  },
  
  // Stress test
  stress_test: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '2m', target: 50 },
      { duration: '5m', target: 50 },
      { duration: '2m', target: 100 },
      { duration: '5m', target: 100 },
      { duration: '2m', target: 200 },
      { duration: '5m', target: 200 },
      { duration: '5m', target: 0 },
    ],
  }
};