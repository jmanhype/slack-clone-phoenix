# Authentication Guide

## Overview

The Slack Clone API uses JWT (JSON Web Token) based authentication with refresh token support. This guide covers the complete authentication flow, token management, and security best practices.

## Authentication Flow

### 1. User Login

```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "userpassword"
}
```

**Response (Success - 200 OK):**
```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "12345678-1234-5678-1234-123456789012",
      "email": "user@example.com"
    }
  }
}
```

**Response (Error - 401 Unauthorized):**
```json
{
  "error": {
    "message": "Invalid email or password"
  }
}
```

### 2. Token Usage

Include the access token in the `Authorization` header for all authenticated requests:

```http
GET /api/me
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 3. Token Refresh

Access tokens expire after 1 hour. Use the refresh token to get a new access token:

```http
POST /api/auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**
```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### 4. User Logout

```http
POST /api/auth/logout
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response:**
```json
{
  "data": {
    "message": "Logged out successfully"
  }
}
```

## Token Details

### Access Token
- **Type**: JWT
- **Expiration**: 1 hour
- **Usage**: API requests and WebSocket authentication
- **Claims**:
  ```json
  {
    "aud": "slack_clone",
    "exp": 1694976000,
    "iat": 1694972400,
    "iss": "slack_clone",
    "jti": "12345678-1234-5678-1234-123456789012",
    "nbf": 1694972400,
    "sub": "12345678-1234-5678-1234-123456789012",
    "typ": "access"
  }
  ```

### Refresh Token
- **Type**: JWT
- **Expiration**: 7 days
- **Usage**: Getting new access tokens
- **Claims**:
  ```json
  {
    "aud": "slack_clone",
    "exp": 1695577200,
    "iat": 1694972400,
    "iss": "slack_clone", 
    "jti": "12345678-1234-5678-1234-123456789012",
    "nbf": 1694972400,
    "sub": "12345678-1234-5678-1234-123456789012",
    "typ": "refresh"
  }
  ```

## Implementation Examples

### JavaScript/TypeScript

```javascript
class AuthService {
  constructor(baseURL = 'https://api.slackclone.com') {
    this.baseURL = baseURL;
    this.accessToken = localStorage.getItem('access_token');
    this.refreshToken = localStorage.getItem('refresh_token');
  }

  async login(email, password) {
    try {
      const response = await fetch(`${this.baseURL}/api/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password }),
      });

      if (!response.ok) {
        throw new Error('Login failed');
      }

      const data = await response.json();
      
      // Store tokens
      this.accessToken = data.data.access_token;
      this.refreshToken = data.data.refresh_token;
      
      localStorage.setItem('access_token', this.accessToken);
      localStorage.setItem('refresh_token', this.refreshToken);
      
      return data.data;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  }

  async refreshAccessToken() {
    try {
      if (!this.refreshToken) {
        throw new Error('No refresh token available');
      }

      const response = await fetch(`${this.baseURL}/api/auth/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ refresh_token: this.refreshToken }),
      });

      if (!response.ok) {
        // Refresh token is invalid, redirect to login
        this.logout();
        throw new Error('Token refresh failed');
      }

      const data = await response.json();
      
      // Update access token
      this.accessToken = data.data.access_token;
      localStorage.setItem('access_token', this.accessToken);
      
      return this.accessToken;
    } catch (error) {
      console.error('Token refresh error:', error);
      throw error;
    }
  }

  async makeAuthenticatedRequest(url, options = {}) {
    // Add authorization header
    const headers = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    if (this.accessToken) {
      headers.Authorization = `Bearer ${this.accessToken}`;
    }

    try {
      let response = await fetch(url, {
        ...options,
        headers,
      });

      // If token expired, try to refresh
      if (response.status === 401 && this.refreshToken) {
        await this.refreshAccessToken();
        
        // Retry with new token
        headers.Authorization = `Bearer ${this.accessToken}`;
        response = await fetch(url, {
          ...options,
          headers,
        });
      }

      return response;
    } catch (error) {
      console.error('API request error:', error);
      throw error;
    }
  }

  async getCurrentUser() {
    const response = await this.makeAuthenticatedRequest(`${this.baseURL}/api/me`);
    
    if (!response.ok) {
      throw new Error('Failed to get user info');
    }

    const data = await response.json();
    return data.data;
  }

  async logout() {
    try {
      if (this.accessToken) {
        await this.makeAuthenticatedRequest(`${this.baseURL}/api/auth/logout`, {
          method: 'POST',
        });
      }
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      // Clear tokens regardless of API call success
      this.accessToken = null;
      this.refreshToken = null;
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
    }
  }

  isAuthenticated() {
    return !!this.accessToken;
  }

  getAccessToken() {
    return this.accessToken;
  }
}

// Usage
const auth = new AuthService();

// Login
try {
  const userData = await auth.login('user@example.com', 'password');
  console.log('Logged in:', userData);
} catch (error) {
  console.error('Login failed:', error);
}

// Make authenticated API calls
try {
  const currentUser = await auth.getCurrentUser();
  console.log('Current user:', currentUser);
} catch (error) {
  console.error('Failed to get user:', error);
}
```

### React Hook Implementation

```javascript
import { createContext, useContext, useEffect, useState } from 'react';

const AuthContext = createContext();

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const authService = new AuthService();

  useEffect(() => {
    // Check if user is already logged in
    if (authService.isAuthenticated()) {
      authService.getCurrentUser()
        .then(setUser)
        .catch(() => {
          // Token is invalid, clear it
          authService.logout();
        })
        .finally(() => setLoading(false));
    } else {
      setLoading(false);
    }
  }, []);

  const login = async (email, password) => {
    try {
      const userData = await authService.login(email, password);
      setUser(userData.user);
      return userData;
    } catch (error) {
      throw error;
    }
  };

  const logout = async () => {
    await authService.logout();
    setUser(null);
  };

  const value = {
    user,
    login,
    logout,
    loading,
    isAuthenticated: authService.isAuthenticated(),
    makeAuthenticatedRequest: authService.makeAuthenticatedRequest.bind(authService),
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

// Usage in components
function LoginForm() {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      await login(email, password);
      // Redirect to dashboard or show success message
    } catch (error) {
      // Show error message
      console.error('Login failed:', error);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email"
        required
      />
      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="Password"
        required
      />
      <button type="submit">Login</button>
    </form>
  );
}
```

### Python Implementation

```python
import requests
import json
from datetime import datetime, timedelta
from typing import Optional, Dict, Any

class AuthService:
    def __init__(self, base_url: str = "https://api.slackclone.com"):
        self.base_url = base_url
        self.access_token: Optional[str] = None
        self.refresh_token: Optional[str] = None
    
    def login(self, email: str, password: str) -> Dict[str, Any]:
        """Login with email and password"""
        try:
            response = requests.post(
                f"{self.base_url}/api/auth/login",
                json={"email": email, "password": password},
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code != 200:
                raise Exception(f"Login failed: {response.status_code}")
            
            data = response.json()["data"]
            
            # Store tokens
            self.access_token = data["access_token"]
            self.refresh_token = data["refresh_token"]
            
            return data
            
        except requests.exceptions.RequestException as e:
            raise Exception(f"Login request failed: {str(e)}")
    
    def refresh_access_token(self) -> str:
        """Refresh the access token using refresh token"""
        if not self.refresh_token:
            raise Exception("No refresh token available")
        
        try:
            response = requests.post(
                f"{self.base_url}/api/auth/refresh",
                json={"refresh_token": self.refresh_token},
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code != 200:
                raise Exception(f"Token refresh failed: {response.status_code}")
            
            data = response.json()["data"]
            self.access_token = data["access_token"]
            
            return self.access_token
            
        except requests.exceptions.RequestException as e:
            raise Exception(f"Token refresh request failed: {str(e)}")
    
    def make_authenticated_request(self, method: str, url: str, **kwargs) -> requests.Response:
        """Make an authenticated request with automatic token refresh"""
        
        # Add authorization header
        headers = kwargs.get("headers", {})
        if self.access_token:
            headers["Authorization"] = f"Bearer {self.access_token}"
        
        kwargs["headers"] = headers
        
        try:
            response = requests.request(method, url, **kwargs)
            
            # If token expired, try to refresh
            if response.status_code == 401 and self.refresh_token:
                try:
                    self.refresh_access_token()
                    # Retry with new token
                    headers["Authorization"] = f"Bearer {self.access_token}"
                    kwargs["headers"] = headers
                    response = requests.request(method, url, **kwargs)
                except Exception:
                    # Refresh failed, clear tokens
                    self.access_token = None
                    self.refresh_token = None
                    raise Exception("Authentication failed - please login again")
            
            return response
            
        except requests.exceptions.RequestException as e:
            raise Exception(f"Request failed: {str(e)}")
    
    def get_current_user(self) -> Dict[str, Any]:
        """Get current user information"""
        response = self.make_authenticated_request("GET", f"{self.base_url}/api/me")
        
        if response.status_code != 200:
            raise Exception(f"Failed to get user info: {response.status_code}")
        
        return response.json()["data"]
    
    def logout(self) -> None:
        """Logout and clear tokens"""
        try:
            if self.access_token:
                self.make_authenticated_request("POST", f"{self.base_url}/api/auth/logout")
        except Exception as e:
            print(f"Logout request failed: {str(e)}")
        finally:
            # Clear tokens regardless of API call success
            self.access_token = None
            self.refresh_token = None
    
    def is_authenticated(self) -> bool:
        """Check if user is authenticated"""
        return self.access_token is not None

# Usage example
auth = AuthService()

try:
    # Login
    user_data = auth.login("user@example.com", "password")
    print(f"Logged in as: {user_data['user']['email']}")
    
    # Get current user
    current_user = auth.get_current_user()
    print(f"Current user: {current_user}")
    
    # Make other authenticated requests
    response = auth.make_authenticated_request(
        "GET", 
        "https://api.slackclone.com/api/workspaces"
    )
    
    if response.status_code == 200:
        workspaces = response.json()["data"]
        print(f"User has {len(workspaces)} workspaces")
    
except Exception as e:
    print(f"Error: {e}")
```

### WebSocket Authentication

```javascript
import { Socket } from "phoenix";

class AuthenticatedWebSocket {
  constructor(authService) {
    this.authService = authService;
    this.socket = null;
  }

  connect() {
    const token = this.authService.getAccessToken();
    if (!token) {
      throw new Error("No access token available");
    }

    this.socket = new Socket("ws://localhost:4000/socket/websocket", {
      params: { token },
      reconnectAfterMs: () => [1000, 5000, 10000]
    });

    // Handle authentication errors
    this.socket.onError((error) => {
      console.error("WebSocket error:", error);
      
      // If it's an authentication error, try to refresh token
      if (error.reason === "unauthorized") {
        this.handleAuthError();
      }
    });

    this.socket.connect();
    return this.socket;
  }

  async handleAuthError() {
    try {
      // Try to refresh the access token
      await this.authService.refreshAccessToken();
      
      // Reconnect with new token
      this.disconnect();
      this.connect();
    } catch (error) {
      // Refresh failed, redirect to login
      console.error("Token refresh failed:", error);
      this.authService.logout();
      // Redirect to login page
      window.location.href = "/login";
    }
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }
}

// Usage
const auth = new AuthService();
const wsClient = new AuthenticatedWebSocket(auth);

// After successful login
await auth.login("user@example.com", "password");
const socket = wsClient.connect();

// Join channels and set up event handlers
const channel = socket.channel("channel:12345678-1234-5678-1234-123456789012");
channel.join();
```

## Security Best Practices

### Token Storage

1. **Web Applications**:
   - Store access tokens in memory or secure HTTP-only cookies
   - Store refresh tokens in secure HTTP-only cookies
   - Never store tokens in localStorage for production apps (XSS vulnerability)

2. **Mobile Applications**:
   - Use secure storage mechanisms (iOS Keychain, Android Keystore)
   - Encrypt tokens before storing

3. **Server-side Applications**:
   - Store tokens in secure session storage or encrypted databases
   - Use environment variables for service account tokens

### Token Management

1. **Automatic Refresh**:
   - Implement automatic token refresh before expiration
   - Handle concurrent requests during token refresh
   - Use token refresh queuing to avoid multiple refresh requests

2. **Error Handling**:
   - Handle 401 responses gracefully
   - Implement exponential backoff for failed requests
   - Clear tokens on authentication failure

3. **Token Validation**:
   - Validate token structure and expiration on client-side
   - Implement proper JWT signature verification on server-side

### Network Security

1. **HTTPS Only**:
   - Always use HTTPS for API requests
   - Never send tokens over unsecured connections

2. **CORS Configuration**:
   - Configure proper CORS headers
   - Whitelist trusted domains only

3. **Rate Limiting**:
   - Implement rate limiting for authentication endpoints
   - Use exponential backoff for failed login attempts

## Error Handling

### Common Authentication Errors

| Status Code | Error Type | Description | Solution |
|-------------|------------|-------------|----------|
| 401 | `UNAUTHORIZED` | Missing or invalid token | Login again or refresh token |
| 401 | `INVALID_TOKEN` | Token expired or malformed | Refresh token or login again |
| 401 | `TOKEN_EXPIRED` | Access token expired | Use refresh token to get new access token |
| 403 | `FORBIDDEN` | Valid token but insufficient permissions | Check user permissions |
| 422 | `VALIDATION_ERROR` | Invalid login credentials | Check email/password format |
| 429 | `RATE_LIMIT_EXCEEDED` | Too many login attempts | Wait before retrying |

### Error Response Format

```json
{
  "error": {
    "message": "Human-readable error message",
    "code": "ERROR_CODE",
    "details": {
      "field": ["validation error message"]
    }
  }
}
```

### Handling Authentication Errors

```javascript
class ErrorHandler {
  static handleAuthError(error, authService) {
    switch (error.code) {
      case 'UNAUTHORIZED':
      case 'INVALID_TOKEN':
        // Clear tokens and redirect to login
        authService.logout();
        window.location.href = '/login';
        break;
        
      case 'TOKEN_EXPIRED':
        // Attempt token refresh
        return authService.refreshAccessToken();
        
      case 'FORBIDDEN':
        // Show access denied message
        console.error('Access denied:', error.message);
        break;
        
      case 'RATE_LIMIT_EXCEEDED':
        // Show rate limit message with retry time
        const retryAfter = error.details?.retry_after || 60;
        console.error(`Rate limited. Retry after ${retryAfter} seconds`);
        break;
        
      default:
        console.error('Authentication error:', error);
    }
  }
}
```

This authentication guide provides comprehensive coverage of implementing secure authentication with the Slack Clone API. Follow these patterns and best practices to build robust authentication flows in your applications.