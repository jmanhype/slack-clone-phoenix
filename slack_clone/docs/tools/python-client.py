"""
Slack Clone Python SDK

A comprehensive Python client library for interacting with the Slack Clone API.
Includes REST API client and WebSocket support with full type safety.

Version: 1.0.0
Author: Slack Clone API Team

Usage:
    from slack_clone_sdk import SlackCloneClient
    
    client = SlackCloneClient(base_url="https://api.slackclone.com")
    
    # Login
    tokens = await client.auth.login("user@example.com", "password")
    
    # Get workspaces
    workspaces = await client.get_workspaces()
    
    # WebSocket connection
    ws = await client.connect_websocket()
    await ws.join_channel("channel-id")
"""

import asyncio
import json
import logging
import time
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Union, Callable, Awaitable
from dataclasses import dataclass, asdict
from enum import Enum
import aiohttp
import websockets
from websockets.exceptions import ConnectionClosed, WebSocketException

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Custom exceptions
class SlackCloneError(Exception):
    """Base exception for Slack Clone SDK"""
    def __init__(self, message: str, code: Optional[str] = None, status: Optional[int] = None, 
                 details: Optional[Dict[str, List[str]]] = None):
        super().__init__(message)
        self.code = code
        self.status = status
        self.details = details

class AuthenticationError(SlackCloneError):
    """Authentication failed"""
    def __init__(self, message: str = "Authentication failed"):
        super().__init__(message, "AUTHENTICATION_ERROR", 401)

class TokenExpiredError(SlackCloneError):
    """Token has expired"""
    def __init__(self, message: str = "Token has expired"):
        super().__init__(message, "TOKEN_EXPIRED", 401)

class RateLimitError(SlackCloneError):
    """Rate limit exceeded"""
    def __init__(self, message: str = "Rate limit exceeded", retry_after: int = 60):
        super().__init__(message, "RATE_LIMIT_EXCEEDED", 429)
        self.retry_after = retry_after

class ValidationError(SlackCloneError):
    """Request validation failed"""
    def __init__(self, message: str = "Validation failed", details: Optional[Dict[str, List[str]]] = None):
        super().__init__(message, "VALIDATION_ERROR", 422, details)

# Enums
class ChannelType(Enum):
    PUBLIC = "public"
    PRIVATE = "private" 
    DIRECT = "direct"

class UserRole(Enum):
    OWNER = "owner"
    ADMIN = "admin"
    MEMBER = "member"

# Data classes
@dataclass
class User:
    id: str
    email: str

@dataclass
class UserProfile(User):
    name: Optional[str] = None
    avatar_url: Optional[str] = None
    inserted_at: Optional[str] = None
    updated_at: Optional[str] = None

@dataclass
class Workspace:
    id: str
    name: str
    description: Optional[str] = None
    is_public: bool = False
    owner_id: Optional[str] = None
    member_count: int = 0
    inserted_at: Optional[str] = None
    updated_at: Optional[str] = None

@dataclass
class WorkspaceMember:
    id: str
    user: UserProfile
    role: str
    joined_at: str

@dataclass
class Channel:
    id: str
    name: str
    type: str
    workspace_id: str
    created_by: str
    member_count: int = 0
    unread_count: int = 0
    description: Optional[str] = None
    topic: Optional[str] = None
    last_message_at: Optional[str] = None
    inserted_at: Optional[str] = None
    updated_at: Optional[str] = None

@dataclass
class ChannelMember:
    id: str
    user: UserProfile
    role: str
    joined_at: str

@dataclass
class Attachment:
    id: str
    filename: str
    content_type: str
    size: int
    url: str
    thumbnail_url: Optional[str] = None

@dataclass
class Reaction:
    id: str
    emoji: str
    message_id: str
    user_id: str
    user: UserProfile
    inserted_at: str

@dataclass
class ReactionSummary:
    emoji: str
    count: int
    users: List[UserProfile]
    user_reacted: bool

@dataclass
class Message:
    id: str
    content: str
    channel_id: str
    user_id: str
    user: UserProfile
    reply_count: int = 0
    is_edited: bool = False
    thread_id: Optional[str] = None
    parent_message_id: Optional[str] = None
    attachments: List[Attachment] = None
    reactions: List[ReactionSummary] = None
    mentions: List[str] = None
    edited_at: Optional[str] = None
    inserted_at: Optional[str] = None
    updated_at: Optional[str] = None

    def __post_init__(self):
        if self.attachments is None:
            self.attachments = []
        if self.reactions is None:
            self.reactions = []
        if self.mentions is None:
            self.mentions = []

@dataclass
class Pagination:
    page: int
    per_page: int
    total_pages: int
    total_count: int

@dataclass
class PaginatedResponse:
    data: List[Any]
    pagination: Pagination

@dataclass
class AuthTokens:
    access_token: str
    refresh_token: str
    user: User

# HTTP Client
class HTTPClient:
    def __init__(self, base_url: str = "https://api.slackclone.com", 
                 timeout: int = 30, retry_attempts: int = 3, retry_delay: float = 1.0):
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.retry_attempts = retry_attempts
        self.retry_delay = retry_delay
        self.session: Optional[aiohttp.ClientSession] = None

    async def __aenter__(self):
        await self.start_session()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close_session()

    async def start_session(self):
        if not self.session or self.session.closed:
            timeout = aiohttp.ClientTimeout(total=self.timeout)
            self.session = aiohttp.ClientSession(timeout=timeout)

    async def close_session(self):
        if self.session and not self.session.closed:
            await self.session.close()

    async def request(self, method: str, endpoint: str, data: Optional[Dict] = None, 
                     headers: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
        await self.start_session()
        
        url = f"{self.base_url}{endpoint}"
        request_headers = {"Content-Type": "application/json"}
        if headers:
            request_headers.update(headers)

        last_error = None
        
        for attempt in range(self.retry_attempts + 1):
            try:
                kwargs = {
                    "method": method,
                    "url": url,
                    "headers": request_headers
                }
                
                if data and method.upper() in ["POST", "PUT", "PATCH"]:
                    kwargs["json"] = data
                elif method.upper() == "GET" and data:
                    kwargs["params"] = data

                async with self.session.request(**kwargs) as response:
                    if response.status >= 400:
                        await self._handle_error_response(response)
                    
                    try:
                        return await response.json()
                    except aiohttp.ContentTypeError:
                        return {}

            except Exception as error:
                last_error = error
                
                if attempt < self.retry_attempts and self._should_retry(error):
                    await asyncio.sleep(self.retry_delay * (2 ** attempt))
                    continue
                
                raise error

        raise last_error

    async def _handle_error_response(self, response: aiohttp.ClientResponse):
        try:
            error_data = await response.json()
            error_info = error_data.get("error", {})
            message = error_info.get("message", f"HTTP {response.status}")
            code = error_info.get("code")
            details = error_info.get("details")
        except (aiohttp.ContentTypeError, ValueError):
            message = f"HTTP {response.status}: {response.reason}"
            code = str(response.status)
            details = None

        if response.status == 401:
            if code == "TOKEN_EXPIRED":
                raise TokenExpiredError(message)
            raise AuthenticationError(message)
        elif response.status == 403:
            raise SlackCloneError(message, code, response.status, details)
        elif response.status == 422:
            raise ValidationError(message, details)
        elif response.status == 429:
            retry_after = int(response.headers.get("Retry-After", "60"))
            raise RateLimitError(message, retry_after)
        else:
            raise SlackCloneError(message, code, response.status, details)

    def _should_retry(self, error: Exception) -> bool:
        return (
            isinstance(error, aiohttp.ClientError) or
            isinstance(error, asyncio.TimeoutError) or
            (isinstance(error, SlackCloneError) and error.status and error.status >= 500)
        )

# Authentication Service
class AuthService:
    def __init__(self, http_client: HTTPClient):
        self.http_client = http_client
        self.access_token: Optional[str] = None
        self.refresh_token: Optional[str] = None

    async def login(self, email: str, password: str) -> AuthTokens:
        response = await self.http_client.request(
            "POST", 
            "/api/auth/login",
            {"email": email, "password": password}
        )
        
        tokens_data = response["data"]
        tokens = AuthTokens(
            access_token=tokens_data["access_token"],
            refresh_token=tokens_data["refresh_token"],
            user=User(
                id=tokens_data["user"]["id"],
                email=tokens_data["user"]["email"]
            )
        )
        
        self.access_token = tokens.access_token
        self.refresh_token = tokens.refresh_token
        
        return tokens

    async def refresh_access_token(self) -> str:
        if not self.refresh_token:
            raise AuthenticationError("No refresh token available")

        response = await self.http_client.request(
            "POST",
            "/api/auth/refresh", 
            {"refresh_token": self.refresh_token}
        )
        
        self.access_token = response["data"]["access_token"]
        return self.access_token

    async def logout(self):
        if self.access_token:
            try:
                await self.http_client.request(
                    "POST",
                    "/api/auth/logout",
                    headers={"Authorization": f"Bearer {self.access_token}"}
                )
            except Exception as e:
                logger.warning(f"Logout request failed: {e}")

        self.access_token = None
        self.refresh_token = None

    def get_access_token(self) -> Optional[str]:
        return self.access_token

    def set_tokens(self, access_token: str, refresh_token: str):
        self.access_token = access_token
        self.refresh_token = refresh_token

    def is_authenticated(self) -> bool:
        return self.access_token is not None

    async def make_authenticated_request(self, method: str, endpoint: str, 
                                       data: Optional[Dict] = None) -> Dict[str, Any]:
        headers = {}
        if self.access_token:
            headers["Authorization"] = f"Bearer {self.access_token}"

        try:
            return await self.http_client.request(method, endpoint, data, headers)
        except TokenExpiredError:
            if self.refresh_token:
                try:
                    await self.refresh_access_token()
                    headers["Authorization"] = f"Bearer {self.access_token}"
                    return await self.http_client.request(method, endpoint, data, headers)
                except Exception:
                    self.access_token = None
                    self.refresh_token = None
                    raise AuthenticationError("Token refresh failed")
            raise

# WebSocket Client
class WebSocketClient:
    def __init__(self, url: str = "ws://localhost:4000/socket/websocket"):
        self.url = url
        self.websocket: Optional[websockets.WebSocketServerProtocol] = None
        self.channels: Dict[str, Dict] = {}
        self.event_handlers: Dict[str, List[Callable]] = {}
        self.connected = False
        self._listen_task: Optional[asyncio.Task] = None

    async def connect(self, token: str):
        try:
            # Connect to WebSocket with token
            uri = f"{self.url}?token={token}"
            self.websocket = await websockets.connect(uri)
            self.connected = True
            
            # Start listening for messages
            self._listen_task = asyncio.create_task(self._listen_for_messages())
            
            logger.info("WebSocket connected successfully")
        except Exception as e:
            logger.error(f"WebSocket connection failed: {e}")
            raise SlackCloneError(f"WebSocket connection failed: {e}")

    async def disconnect(self):
        self.connected = False
        
        if self._listen_task:
            self._listen_task.cancel()
            try:
                await self._listen_task
            except asyncio.CancelledError:
                pass

        if self.websocket:
            await self.websocket.close()
            self.websocket = None

        self.channels.clear()
        logger.info("WebSocket disconnected")

    async def join_channel(self, channel_id: str, callbacks: Optional[Dict[str, Callable]] = None):
        if not self.websocket or not self.connected:
            raise SlackCloneError("WebSocket not connected")

        # Phoenix channel format
        topic = f"channel:{channel_id}"
        ref = f"ref_{int(time.time() * 1000)}"
        
        # Send join message
        join_message = {
            "topic": topic,
            "event": "phx_join",
            "payload": {},
            "ref": ref
        }
        
        await self.websocket.send(json.dumps(join_message))
        
        # Store channel info
        self.channels[channel_id] = {
            "topic": topic,
            "callbacks": callbacks or {}
        }
        
        logger.info(f"Joined channel: {channel_id}")

    async def leave_channel(self, channel_id: str):
        if channel_id not in self.channels:
            return

        if self.websocket and self.connected:
            topic = self.channels[channel_id]["topic"]
            ref = f"ref_{int(time.time() * 1000)}"
            
            leave_message = {
                "topic": topic,
                "event": "phx_leave",
                "payload": {},
                "ref": ref
            }
            
            await self.websocket.send(json.dumps(leave_message))

        del self.channels[channel_id]
        logger.info(f"Left channel: {channel_id}")

    async def send_message(self, channel_id: str, content: str, temp_id: Optional[str] = None):
        await self._send_channel_event(channel_id, "send_message", {
            "content": content,
            "temp_id": temp_id or str(int(time.time() * 1000))
        })

    async def edit_message(self, channel_id: str, message_id: str, content: str):
        await self._send_channel_event(channel_id, "edit_message", {
            "message_id": message_id,
            "content": content
        })

    async def delete_message(self, channel_id: str, message_id: str):
        await self._send_channel_event(channel_id, "delete_message", {
            "message_id": message_id
        })

    async def start_typing(self, channel_id: str):
        await self._send_channel_event(channel_id, "typing_start", {})

    async def stop_typing(self, channel_id: str):
        await self._send_channel_event(channel_id, "typing_stop", {})

    async def add_reaction(self, channel_id: str, message_id: str, emoji: str):
        await self._send_channel_event(channel_id, "add_reaction", {
            "message_id": message_id,
            "emoji": emoji
        })

    async def remove_reaction(self, channel_id: str, reaction_id: str):
        await self._send_channel_event(channel_id, "remove_reaction", {
            "reaction_id": reaction_id
        })

    async def mark_as_read(self, channel_id: str, message_id: str):
        await self._send_channel_event(channel_id, "mark_read", {
            "message_id": message_id
        })

    async def load_older_messages(self, channel_id: str, before_id: str) -> List[Message]:
        # This would typically return a promise-like result
        await self._send_channel_event(channel_id, "load_older_messages", {
            "before_id": before_id
        })

    async def _send_channel_event(self, channel_id: str, event: str, payload: Dict):
        if not self.websocket or not self.connected:
            raise SlackCloneError("WebSocket not connected")

        if channel_id not in self.channels:
            raise SlackCloneError(f"Not joined to channel: {channel_id}")

        topic = self.channels[channel_id]["topic"]
        ref = f"ref_{int(time.time() * 1000)}"
        
        message = {
            "topic": topic,
            "event": event,
            "payload": payload,
            "ref": ref
        }
        
        await self.websocket.send(json.dumps(message))

    async def _listen_for_messages(self):
        while self.connected and self.websocket:
            try:
                message = await self.websocket.recv()
                await self._handle_message(json.loads(message))
            except ConnectionClosed:
                logger.info("WebSocket connection closed")
                self.connected = False
                break
            except WebSocketException as e:
                logger.error(f"WebSocket error: {e}")
                self.connected = False
                break
            except Exception as e:
                logger.error(f"Error handling message: {e}")

    async def _handle_message(self, message: Dict):
        topic = message.get("topic", "")
        event = message.get("event", "")
        payload = message.get("payload", {})

        # Find channel by topic
        channel_id = None
        for cid, channel_info in self.channels.items():
            if channel_info["topic"] == topic:
                channel_id = cid
                break

        if channel_id:
            callbacks = self.channels[channel_id]["callbacks"]
            if event in callbacks:
                try:
                    await callbacks[event](payload)
                except Exception as e:
                    logger.error(f"Error in callback for {event}: {e}")

        # Global event handlers
        if event in self.event_handlers:
            for handler in self.event_handlers[event]:
                try:
                    await handler(payload)
                except Exception as e:
                    logger.error(f"Error in global handler for {event}: {e}")

    def on(self, event: str, handler: Callable):
        """Register global event handler"""
        if event not in self.event_handlers:
            self.event_handlers[event] = []
        self.event_handlers[event].append(handler)

# Main SDK Client
class SlackCloneClient:
    def __init__(self, base_url: str = "https://api.slackclone.com", 
                 ws_url: str = "ws://localhost:4000/socket/websocket"):
        self.http_client = HTTPClient(base_url)
        self.auth = AuthService(self.http_client)
        self.ws_client = WebSocketClient(ws_url)

    async def __aenter__(self):
        await self.http_client.start_session()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()

    async def close(self):
        await self.http_client.close_session()
        if self.ws_client.connected:
            await self.ws_client.disconnect()

    # WebSocket methods
    async def connect_websocket(self) -> WebSocketClient:
        token = self.auth.get_access_token()
        if not token:
            raise AuthenticationError("No access token available for WebSocket")
        
        await self.ws_client.connect(token)
        return self.ws_client

    # User API methods
    async def get_current_user(self) -> UserProfile:
        response = await self.auth.make_authenticated_request("GET", "/api/me")
        data = response["data"]
        return UserProfile(**data)

    async def update_current_user(self, **updates) -> UserProfile:
        response = await self.auth.make_authenticated_request(
            "PUT", "/api/me", {"user": updates}
        )
        data = response["data"]
        return UserProfile(**data)

    # Workspace API methods
    async def get_workspaces(self, page: int = 1, limit: int = 20) -> PaginatedResponse:
        response = await self.auth.make_authenticated_request(
            "GET", f"/api/workspaces?page={page}&limit={limit}"
        )
        
        workspaces = [Workspace(**ws) for ws in response["data"]]
        pagination = Pagination(**response["pagination"])
        
        return PaginatedResponse(data=workspaces, pagination=pagination)

    async def get_workspace(self, workspace_id: str) -> Workspace:
        response = await self.auth.make_authenticated_request(
            "GET", f"/api/workspaces/{workspace_id}"
        )
        return Workspace(**response["data"])

    async def create_workspace(self, name: str, description: Optional[str] = None, 
                             is_public: bool = False) -> Workspace:
        data = {"name": name, "is_public": is_public}
        if description:
            data["description"] = description

        response = await self.auth.make_authenticated_request(
            "POST", "/api/workspaces", data
        )
        return Workspace(**response["data"])

    async def update_workspace(self, workspace_id: str, **updates) -> Workspace:
        response = await self.auth.make_authenticated_request(
            "PUT", f"/api/workspaces/{workspace_id}", updates
        )
        return Workspace(**response["data"])

    async def delete_workspace(self, workspace_id: str):
        await self.auth.make_authenticated_request(
            "DELETE", f"/api/workspaces/{workspace_id}"
        )

    # Channel API methods  
    async def get_channels(self, workspace_id: str, channel_type: Optional[str] = None,
                          member: Optional[bool] = None) -> List[Channel]:
        params = {}
        if channel_type:
            params["type"] = channel_type
        if member is not None:
            params["member"] = str(member).lower()

        response = await self.auth.make_authenticated_request(
            "GET", f"/api/workspaces/{workspace_id}/channels", params
        )
        return [Channel(**ch) for ch in response["data"]]

    async def get_channel(self, workspace_id: str, channel_id: str) -> Channel:
        response = await self.auth.make_authenticated_request(
            "GET", f"/api/workspaces/{workspace_id}/channels/{channel_id}"
        )
        return Channel(**response["data"])

    async def create_channel(self, workspace_id: str, name: str, channel_type: str,
                           description: Optional[str] = None, topic: Optional[str] = None) -> Channel:
        data = {"name": name, "type": channel_type}
        if description:
            data["description"] = description
        if topic:
            data["topic"] = topic

        response = await self.auth.make_authenticated_request(
            "POST", f"/api/workspaces/{workspace_id}/channels", data
        )
        return Channel(**response["data"])

    async def update_channel(self, workspace_id: str, channel_id: str, **updates) -> Channel:
        response = await self.auth.make_authenticated_request(
            "PUT", f"/api/workspaces/{workspace_id}/channels/{channel_id}", updates
        )
        return Channel(**response["data"])

    async def delete_channel(self, workspace_id: str, channel_id: str):
        await self.auth.make_authenticated_request(
            "DELETE", f"/api/workspaces/{workspace_id}/channels/{channel_id}"
        )

    # Message API methods
    async def get_messages(self, workspace_id: str, channel_id: str, 
                          before: Optional[str] = None, after: Optional[str] = None,
                          limit: int = 50, include_threads: bool = False) -> Dict[str, Any]:
        params = {"limit": limit, "include_threads": include_threads}
        if before:
            params["before"] = before
        if after:
            params["after"] = after

        response = await self.auth.make_authenticated_request(
            "GET", f"/api/workspaces/{workspace_id}/channels/{channel_id}/messages", params
        )
        
        messages = [Message(**msg) for msg in response["data"]]
        return {
            "data": messages,
            "has_more": response.get("has_more", False),
            "cursor": response.get("cursor")
        }

    async def send_message(self, workspace_id: str, channel_id: str, content: str,
                          thread_id: Optional[str] = None, attachments: Optional[List[Attachment]] = None) -> Message:
        data = {"content": content}
        if thread_id:
            data["thread_id"] = thread_id
        if attachments:
            data["attachments"] = [asdict(att) for att in attachments]

        response = await self.auth.make_authenticated_request(
            "POST", f"/api/workspaces/{workspace_id}/channels/{channel_id}/messages", data
        )
        return Message(**response["data"])

    async def edit_message(self, message_id: str, content: str) -> Message:
        response = await self.auth.make_authenticated_request(
            "PUT", f"/api/messages/{message_id}", {"content": content}
        )
        return Message(**response["data"])

    async def delete_message(self, message_id: str):
        await self.auth.make_authenticated_request(
            "DELETE", f"/api/messages/{message_id}"
        )

    async def add_reaction(self, message_id: str, emoji: str) -> Reaction:
        response = await self.auth.make_authenticated_request(
            "POST", f"/api/messages/{message_id}/reactions", {"emoji": emoji}
        )
        return Reaction(**response["data"])

    async def remove_reaction(self, message_id: str, reaction_id: str):
        await self.auth.make_authenticated_request(
            "DELETE", f"/api/messages/{message_id}/reactions/{reaction_id}"
        )

# Usage example
async def main():
    async with SlackCloneClient(base_url="https://api.slackclone.com") as client:
        try:
            # Login
            tokens = await client.auth.login("user@example.com", "password")
            print(f"Logged in as: {tokens.user.email}")

            # Get current user
            user = await client.get_current_user()
            print(f"Current user: {user.name} ({user.email})")

            # Get workspaces
            workspaces_response = await client.get_workspaces()
            workspaces = workspaces_response.data
            print(f"Found {len(workspaces)} workspaces")

            if workspaces:
                # Get channels from first workspace
                workspace = workspaces[0]
                channels = await client.get_channels(workspace.id)
                print(f"Workspace '{workspace.name}' has {len(channels)} channels")

                if channels:
                    # Connect to WebSocket and join first channel
                    ws = await client.connect_websocket()
                    
                    channel = channels[0]
                    
                    # Set up event handlers
                    async def on_new_message(message_data):
                        print(f"New message in {channel.name}: {message_data.get('content', '')}")
                    
                    async def on_typing_start(data):
                        print(f"{data.get('user_name', 'Someone')} started typing...")
                    
                    # Join channel with callbacks
                    await ws.join_channel(channel.id, {
                        "new_message": on_new_message,
                        "typing_start": on_typing_start
                    })

                    # Send a message
                    await ws.send_message(channel.id, "Hello from Python SDK!")

                    # Keep connection alive for a bit
                    await asyncio.sleep(5)

        except SlackCloneError as e:
            print(f"API Error: {e}")
            if e.details:
                print(f"Details: {e.details}")
        except Exception as e:
            print(f"Unexpected error: {e}")

if __name__ == "__main__":
    asyncio.run(main())