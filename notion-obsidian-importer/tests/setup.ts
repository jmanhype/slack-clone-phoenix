import { jest } from '@jest/globals';

// Setup test environment
beforeAll(() => {
  // Set test environment variables
  process.env.NODE_ENV = 'test';
  process.env.LOG_LEVEL = 'error'; // Reduce log noise during tests
});

// Mock fetch globally for tests
global.fetch = jest.fn() as jest.MockedFunction<typeof fetch>;

// Mock file system operations that might interfere with tests
jest.mock('fs-extra', () => ({
  ...jest.requireActual('fs-extra'),
  ensureDir: jest.fn().mockResolvedValue(undefined),
  writeFile: jest.fn().mockResolvedValue(undefined),
  readFile: jest.fn().mockResolvedValue('{}'),
  pathExists: jest.fn().mockResolvedValue(true),
  stat: jest.fn().mockResolvedValue({ isDirectory: () => true, size: 1024 }),
  copy: jest.fn().mockResolvedValue(undefined)
}));

// Clean up after each test
afterEach(() => {
  jest.clearAllMocks();
});