// Green Phase: Minimal implementation to make tests pass
// User Authentication with JWT

const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

// In-memory user store for testing
const users = new Map([
  ['testuser', {
    id: '123',
    username: 'testuser',
    email: 'test@example.com',
    // Pre-hashed password for 'SecurePassword123!'
    hashedPassword: '$2b$10$YourHashedPasswordHere'
  }]
]);

// Initialize with test user's hashed password
(async () => {
  const testUser = users.get('testuser');
  if (testUser) {
    testUser.hashedPassword = await bcrypt.hash('SecurePassword123!', 10);
  }
})();

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const JWT_EXPIRATION = process.env.JWT_EXPIRATION || '24h';

/**
 * Generate JWT token for authenticated user
 * @param {Object} user - User object
 * @returns {string} JWT token
 */
function generateToken(user) {
  // Never include sensitive data like passwords in the token
  const payload = {
    id: user.id,
    username: user.username,
    email: user.email
  };

  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: JWT_EXPIRATION
  });
}

/**
 * Verify JWT token
 * @param {string} token - JWT token to verify
 * @returns {Object} Decoded token payload
 * @throws {Error} If token is invalid or expired
 */
function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    throw new Error(`Token verification failed: ${error.message}`);
  }
}

/**
 * Authenticate user with username and password
 * @param {string} username - User's username
 * @param {string} password - User's password
 * @returns {Promise<Object>} Authentication result
 */
async function authenticateUser(username, password) {
  try {
    // Find user by username
    const user = users.get(username);
    
    if (!user) {
      return {
        success: false,
        error: 'User not found'
      };
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.hashedPassword);
    
    if (!isValidPassword) {
      return {
        success: false,
        error: 'Invalid credentials'
      };
    }

    // Generate token
    const token = generateToken(user);

    // Return success with token and user data (without password)
    const { hashedPassword, ...userWithoutPassword } = user;
    
    return {
      success: true,
      token,
      user: userWithoutPassword
    };
  } catch (error) {
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Middleware to protect routes
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
function authMiddleware(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1]; // Bearer <token>

  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  try {
    const decoded = verifyToken(token);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

module.exports = {
  generateToken,
  verifyToken,
  authenticateUser,
  authMiddleware
};