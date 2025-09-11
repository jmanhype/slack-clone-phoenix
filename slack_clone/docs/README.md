# Slack Clone API Documentation

Welcome to the comprehensive API documentation for the Slack Clone application. This documentation provides everything you need to integrate with our REST API and WebSocket services.

## 📚 Documentation Overview

### Core API Documentation
- **[OpenAPI Specification](./api/openapi.yaml)** - Complete REST API specification with schemas, endpoints, and examples
- **[WebSocket API Guide](./websocket/websocket-api.md)** - Phoenix Channels protocol, events, and real-time messaging
- **[Authentication Guide](./guides/authentication-guide.md)** - JWT authentication flow, token management, and security best practices

### Developer Tools & SDKs
- **[TypeScript SDK](./tools/typescript-sdk.ts)** - Type-safe client library with WebSocket support
- **[Python Client](./tools/python-client.py)** - Async Python client with comprehensive API coverage
- **[Postman Collection](./tools/postman-collection.json)** - Ready-to-use API testing collection

### Interactive Testing
- **[Swagger UI](./interactive/swagger-ui.html)** - Interactive API explorer with authentication helper
- **[WebSocket Tester](./interactive/websocket-tester.html)** - Real-time WebSocket API testing tool

## 🚀 Quick Start

### 1. Explore the API
Start with the interactive Swagger UI to explore available endpoints:
```bash
# Serve the documentation locally
python -m http.server 8080
# Open http://localhost:8080/docs/interactive/swagger-ui.html
```

### 2. Test Authentication
Use the authentication helper in Swagger UI or test manually:
```bash
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password123"}'
```

### 3. Try WebSocket Connection
Use the WebSocket tester to explore real-time features:
- Open `docs/interactive/websocket-tester.html`
- Connect to your WebSocket endpoint
- Join channels and send test messages

### 4. Import Postman Collection
For advanced API testing:
1. Download `docs/tools/postman-collection.json`
2. Import into Postman
3. Set up environment variables
4. Start testing all endpoints

## 📖 API Documentation Structure

### REST API Endpoints

#### Authentication
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User authentication
- `POST /api/auth/refresh` - Token refresh
- `POST /api/auth/logout` - User logout

#### Workspaces
- `GET /api/workspaces` - List user workspaces
- `POST /api/workspaces` - Create new workspace
- `GET /api/workspaces/{id}` - Get workspace details
- `PUT /api/workspaces/{id}` - Update workspace
- `DELETE /api/workspaces/{id}` - Delete workspace

#### Channels
- `GET /api/workspaces/{id}/channels` - List workspace channels
- `POST /api/workspaces/{id}/channels` - Create channel
- `GET /api/channels/{id}` - Get channel details
- `PUT /api/channels/{id}` - Update channel
- `DELETE /api/channels/{id}` - Delete channel
- `POST /api/channels/{id}/join` - Join channel
- `POST /api/channels/{id}/leave` - Leave channel

#### Messages
- `GET /api/channels/{id}/messages` - List channel messages
- `POST /api/channels/{id}/messages` - Send message
- `GET /api/messages/{id}` - Get message details
- `PUT /api/messages/{id}` - Update message
- `DELETE /api/messages/{id}` - Delete message

#### Reactions
- `GET /api/messages/{id}/reactions` - List message reactions
- `POST /api/messages/{id}/reactions` - Add reaction
- `DELETE /api/messages/{id}/reactions/{emoji}` - Remove reaction

### WebSocket API Events

#### Channel Events
- `phx_join` - Join a channel
- `phx_leave` - Leave a channel
- `new_message` - Send a new message
- `edit_message` - Edit existing message
- `delete_message` - Delete a message
- `typing_start` - Start typing indicator
- `typing_stop` - Stop typing indicator

#### Presence Events
- `presence_state` - Current user presence
- `presence_diff` - Presence changes
- `user_joined` - User joined channel
- `user_left` - User left channel

#### Message Events
- `message_created` - New message notification
- `message_updated` - Message edit notification
- `message_deleted` - Message deletion notification
- `reaction_added` - Reaction added to message
- `reaction_removed` - Reaction removed from message

## 🛠 Development Setup

### Prerequisites
- Elixir 1.14+
- Phoenix Framework 1.7+
- PostgreSQL 13+
- Node.js 16+ (for frontend assets)

### Running the API Server
```bash
# Clone the repository
git clone <repository-url>
cd slack_clone

# Install dependencies
mix deps.get
npm install --prefix assets

# Setup database
mix ecto.create
mix ecto.migrate

# Start the server
mix phx.server
```

The API will be available at `http://localhost:4000`

### Environment Variables
Create a `.env` file with:
```bash
DATABASE_URL=postgresql://user:pass@localhost/slack_clone_dev
SECRET_KEY_BASE=your-secret-key-base
JWT_SECRET=your-jwt-secret
GUARDIAN_SECRET_KEY=your-guardian-secret
```

## 🔧 Client SDK Usage

### TypeScript SDK
```typescript
import { SlackCloneAPI } from './docs/tools/typescript-sdk';

const api = new SlackCloneAPI('http://localhost:4000');

// Authenticate
await api.auth.login('user@example.com', 'password');

// Send message
const message = await api.messages.create('channel-id', {
  content: 'Hello, world!'
});

// WebSocket connection
const ws = api.createWebSocketClient();
await ws.connect();
await ws.joinChannel('general');
```

### Python Client
```python
import asyncio
from docs.tools.python_client import SlackCloneClient

async def main():
    client = SlackCloneClient('http://localhost:4000')
    
    # Authenticate
    await client.login('user@example.com', 'password')
    
    # Send message
    message = await client.send_message('channel-id', 'Hello from Python!')
    
    # WebSocket connection
    await client.connect_websocket()
    await client.join_channel('general')

asyncio.run(main())
```

## 📝 API Reference

### Authentication
All API requests (except authentication endpoints) require a valid JWT token in the Authorization header:
```
Authorization: Bearer <your-jwt-token>
```

Tokens expire after 1 hour and can be refreshed using the refresh token endpoint.

### Rate Limiting
- **Authentication endpoints**: 5 requests per minute per IP
- **API endpoints**: 100 requests per minute per user
- **WebSocket connections**: 10 new connections per minute per user

### Error Handling
All errors follow a consistent format:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request parameters",
    "details": {
      "field": "email",
      "reason": "must be a valid email address"
    }
  }
}
```

### Pagination
List endpoints support pagination:
```
GET /api/channels/{id}/messages?limit=20&before=2023-12-01T10:00:00Z
```

Response includes pagination metadata:
```json
{
  "data": [...],
  "pagination": {
    "has_more": true,
    "next_cursor": "cursor_string"
  }
}
```

## 🧪 Testing

### Using Swagger UI
1. Open `docs/interactive/swagger-ui.html` in your browser
2. Use the authentication helper to log in
3. Explore and test API endpoints interactively

### Using WebSocket Tester
1. Open `docs/interactive/websocket-tester.html` in your browser
2. Connect to your WebSocket endpoint
3. Join channels and test real-time messaging

### Using Postman
1. Import `docs/tools/postman-collection.json`
2. Set up environment variables:
   - `base_url`: http://localhost:4000
   - `access_token`: (will be set automatically after login)
3. Run the authentication flow
4. Test other endpoints with automatic token handling

## 🔍 Advanced Features

### Message Threading
Messages can be organized into threads:
```json
{
  "content": "Reply to thread",
  "thread_id": "original-message-id"
}
```

### File Attachments
Upload files with messages:
```bash
curl -X POST http://localhost:4000/api/files/upload \
  -H "Authorization: Bearer <token>" \
  -F "file=@document.pdf" \
  -F "channel_id=channel-123" \
  -F "message=File attachment"
```

### Message Reactions
Add emoji reactions to messages:
```json
{
  "emoji": "👍"
}
```

### User Presence
Track user online/offline status:
- `online` - Active and available
- `away` - Inactive but available
- `busy` - Active but busy
- `offline` - Not available

### Search
Search across messages, users, and channels:
```
GET /api/search?query=hello&type=messages&workspace_id=ws-123
```

## 🔐 Security Considerations

### Authentication
- JWT tokens with 1-hour expiration
- Refresh tokens for seamless re-authentication
- Secure token storage recommendations

### WebSocket Security
- Token-based WebSocket authentication
- Channel-level authorization
- Rate limiting on WebSocket events

### Data Protection
- Input validation on all endpoints
- XSS protection for message content
- CSRF protection for state-changing operations

## 📊 Monitoring & Debugging

### Health Check
```
GET /api/health
```

Returns server health status and version information.

### WebSocket Debugging
Use the WebSocket tester's logging feature to debug connection issues and message flow.

### API Logs
Enable detailed logging in development:
```bash
export LOG_LEVEL=debug
mix phx.server
```

## 🤝 Contributing

We welcome contributions to improve the API documentation:

1. Fork the repository
2. Make your changes
3. Test with the provided tools
4. Submit a pull request

### Documentation Updates
When updating the API:
1. Update OpenAPI specification
2. Update WebSocket documentation
3. Update SDK code
4. Test with interactive tools

## 📞 Support

- **Issues**: Report bugs and request features in our GitHub repository
- **Documentation**: Refer to this comprehensive documentation
- **Community**: Join our developer community for discussions

## 📜 License

This API documentation is part of the Slack Clone project. Please refer to the main project license for usage terms.

---

**Happy coding! 🚀**

For the latest updates and announcements, please check our GitHub repository and documentation.