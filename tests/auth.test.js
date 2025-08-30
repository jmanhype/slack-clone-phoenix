// TDD: User Authentication with JWT
// Red Phase: Write failing tests first

const { generateToken, verifyToken, authenticateUser } = require('../src/auth');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

describe('User Authentication with JWT', () => {
  const testUser = {
    id: '123',
    username: 'testuser',
    email: 'test@example.com',
    password: 'SecurePassword123!'
  };

  describe('Password Hashing', () => {
    test('should hash password successfully', async () => {
      const hashedPassword = await bcrypt.hash(testUser.password, 10);
      expect(hashedPassword).not.toBe(testUser.password);
      expect(hashedPassword.length).toBeGreaterThan(0);
    });

    test('should verify correct password', async () => {
      const hashedPassword = await bcrypt.hash(testUser.password, 10);
      const isValid = await bcrypt.compare(testUser.password, hashedPassword);
      expect(isValid).toBe(true);
    });

    test('should reject incorrect password', async () => {
      const hashedPassword = await bcrypt.hash(testUser.password, 10);
      const isValid = await bcrypt.compare('WrongPassword', hashedPassword);
      expect(isValid).toBe(false);
    });
  });

  describe('JWT Token Generation', () => {
    test('should generate valid JWT token', () => {
      const token = generateToken(testUser);
      expect(token).toBeDefined();
      expect(typeof token).toBe('string');
      expect(token.split('.')).toHaveLength(3); // JWT has 3 parts
    });

    test('should include user data in token payload', () => {
      const token = generateToken(testUser);
      const decoded = jwt.decode(token);
      expect(decoded.id).toBe(testUser.id);
      expect(decoded.username).toBe(testUser.username);
      expect(decoded.email).toBe(testUser.email);
      expect(decoded.password).toBeUndefined(); // Never include password
    });

    test('should set token expiration', () => {
      const token = generateToken(testUser);
      const decoded = jwt.decode(token);
      expect(decoded.exp).toBeDefined();
      expect(decoded.iat).toBeDefined();
      expect(decoded.exp).toBeGreaterThan(decoded.iat);
    });
  });

  describe('JWT Token Verification', () => {
    test('should verify valid token', () => {
      const token = generateToken(testUser);
      const verified = verifyToken(token);
      expect(verified).toBeDefined();
      expect(verified.id).toBe(testUser.id);
    });

    test('should reject invalid token', () => {
      const invalidToken = 'invalid.token.here';
      expect(() => verifyToken(invalidToken)).toThrow();
    });

    test('should reject expired token', (done) => {
      // Create token that expires immediately
      const expiredToken = jwt.sign(
        { id: testUser.id },
        process.env.JWT_SECRET || 'your-secret-key-change-in-production',
        { expiresIn: '1ms' }
      );
      
      // Wait a moment to ensure expiration
      setTimeout(() => {
        try {
          expect(() => verifyToken(expiredToken)).toThrow();
          done();
        } catch (error) {
          done(error);
        }
      }, 100);
    });
  });

  describe('User Authentication Flow', () => {
    test('should authenticate user with correct credentials', async () => {
      const result = await authenticateUser(testUser.username, testUser.password);
      expect(result.success).toBe(true);
      expect(result.token).toBeDefined();
      expect(result.user).toBeDefined();
      expect(result.user.password).toBeUndefined();
    });

    test('should reject authentication with wrong password', async () => {
      const result = await authenticateUser(testUser.username, 'wrongPassword');
      expect(result.success).toBe(false);
      expect(result.error).toBe('Invalid credentials');
      expect(result.token).toBeUndefined();
    });

    test('should reject authentication with non-existent user', async () => {
      const result = await authenticateUser('nonexistent', 'password');
      expect(result.success).toBe(false);
      expect(result.error).toBe('User not found');
      expect(result.token).toBeUndefined();
    });
  });
});