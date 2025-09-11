/**
 * WebSocket client for real-time communication with Phoenix Channels
 * Handles workspace and channel subscriptions, message sending, and presence tracking
 */

import { Socket } from "phoenix"

// Create and configure the socket
const isDev = (typeof window !== 'undefined') && /^(localhost|127\.0\.0\.1)$/.test(window.location.hostname)

const socket = new Socket("/socket", {
  params: () => {
    // Get user token from meta tag or localStorage
    const token = document.querySelector("meta[name='user-token']")?.getAttribute("content") ||
                  localStorage.getItem("user_token")
    return { token }
  },
  logger: (kind, msg, data) => {
    if (isDev) {
      console.log(`${kind}: ${msg}`, data)
    }
  }
})

// Socket connection handlers
socket.onOpen(() => {
  console.log("Socket connected")
  updateConnectionStatus('connected')
})

socket.onError((error) => {
  console.error("Socket error:", error)
  updateConnectionStatus('error')
})

socket.onClose(() => {
  console.log("Socket disconnected")
  updateConnectionStatus('disconnected')
})

// Connection management
let reconnectTimer
const maxReconnectAttempts = 5
let reconnectAttempts = 0

socket.onError(() => {
  reconnectAttempts++
  if (reconnectAttempts <= maxReconnectAttempts) {
    reconnectTimer = setTimeout(() => {
      console.log(`Reconnection attempt ${reconnectAttempts}`)
      socket.connect()
    }, Math.pow(2, reconnectAttempts) * 1000) // Exponential backoff
  }
})

socket.onOpen(() => {
  reconnectAttempts = 0
  if (reconnectTimer) {
    clearTimeout(reconnectTimer)
  }
})

// Global channel management
const channels = new Map()

// Workspace channel management
export const WorkspaceChannel = {
  join(workspaceId) {
    const topic = `workspace:${workspaceId}`
    
    if (channels.has(topic)) {
      return channels.get(topic)
    }

    const channel = socket.channel(topic)
    
    // Set up channel event handlers
    channel.on("workspace_state", (payload) => {
      console.log("Workspace state:", payload)
      // Dispatch custom event for LiveView to handle
      window.dispatchEvent(new CustomEvent('workspace:state', { detail: payload }))
    })

    channel.on("channel_created", (payload) => {
      console.log("Channel created:", payload)
      window.dispatchEvent(new CustomEvent('workspace:channel_created', { detail: payload }))
    })

    channel.on("channel_updated", (payload) => {
      console.log("Channel updated:", payload)
      window.dispatchEvent(new CustomEvent('workspace:channel_updated', { detail: payload }))
    })

    channel.on("user_status_change", (payload) => {
      console.log("User status changed:", payload)
      window.dispatchEvent(new CustomEvent('workspace:user_status_change', { detail: payload }))
    })

    channel.on("presence_diff", (payload) => {
      console.log("Presence diff:", payload)
      window.dispatchEvent(new CustomEvent('workspace:presence_diff', { detail: payload }))
    })

    channel.on("new_message_notification", (payload) => {
      // Handle unread count updates
      window.dispatchEvent(new CustomEvent('workspace:message_notification', { detail: payload }))
    })

    channel.on("error", (payload) => {
      console.error("Workspace channel error:", payload)
      showError(payload.reason || "Workspace error occurred")
    })

    // Join the channel
    channel.join()
      .receive("ok", (resp) => {
        console.log("Joined workspace channel:", workspaceId, resp)
      })
      .receive("error", (resp) => {
        console.error("Failed to join workspace channel:", resp)
        showError("Failed to connect to workspace")
      })

    channels.set(topic, channel)
    return channel
  },

  leave(workspaceId) {
    const topic = `workspace:${workspaceId}`
    const channel = channels.get(topic)
    
    if (channel) {
      channel.leave()
      channels.delete(topic)
    }
  },

  createChannel(workspaceId, { name, description, type }) {
    const channel = channels.get(`workspace:${workspaceId}`)
    if (channel) {
      return channel.push("create_channel", { name, description, type })
    }
  },

  joinChannel(workspaceId, channelId) {
    const channel = channels.get(`workspace:${workspaceId}`)
    if (channel) {
      return channel.push("join_channel", { channel_id: channelId })
    }
  },

  leaveChannel(workspaceId, channelId) {
    const channel = channels.get(`workspace:${workspaceId}`)
    if (channel) {
      return channel.push("leave_channel", { channel_id: channelId })
    }
  },

  updateUserStatus(workspaceId, status) {
    const channel = channels.get(`workspace:${workspaceId}`)
    if (channel) {
      return channel.push("user_status_change", { status })
    }
  }
}

// Channel-specific communication
export const ChannelChannel = {
  join(channelId) {
    const topic = `channel:${channelId}`
    
    if (channels.has(topic)) {
      return channels.get(topic)
    }

    const channel = socket.channel(topic)
    
    // Message events
    channel.on("messages_loaded", (payload) => {
      console.log("Messages loaded:", payload)
      window.dispatchEvent(new CustomEvent('channel:messages_loaded', { detail: payload }))
    })

    channel.on("new_message", (payload) => {
      console.log("New message:", payload)
      window.dispatchEvent(new CustomEvent('channel:new_message', { detail: payload }))
    })

    channel.on("message_updated", (payload) => {
      console.log("Message updated:", payload)
      window.dispatchEvent(new CustomEvent('channel:message_updated', { detail: payload }))
    })

    channel.on("message_deleted", (payload) => {
      console.log("Message deleted:", payload)
      window.dispatchEvent(new CustomEvent('channel:message_deleted', { detail: payload }))
    })

    // Typing indicators
    channel.on("typing_start", (payload) => {
      window.dispatchEvent(new CustomEvent('channel:typing_start', { detail: payload }))
    })

    channel.on("typing_stop", (payload) => {
      window.dispatchEvent(new CustomEvent('channel:typing_stop', { detail: payload }))
    })

    // Reactions
    channel.on("reaction_added", (payload) => {
      window.dispatchEvent(new CustomEvent('channel:reaction_added', { detail: payload }))
    })

    channel.on("reaction_removed", (payload) => {
      window.dispatchEvent(new CustomEvent('channel:reaction_removed', { detail: payload }))
    })

    // Read receipts
    channel.on("message_read", (payload) => {
      window.dispatchEvent(new CustomEvent('channel:message_read', { detail: payload }))
    })

    // Presence
    channel.on("presence_state", (payload) => {
      window.dispatchEvent(new CustomEvent('channel:presence_state', { detail: payload }))
    })

    channel.on("presence_diff", (payload) => {
      window.dispatchEvent(new CustomEvent('channel:presence_diff', { detail: payload }))
    })

    // Thread events
    channel.on("thread_reply", (payload) => {
      window.dispatchEvent(new CustomEvent('channel:thread_reply', { detail: payload }))
    })

    // Error handling
    channel.on("message_error", (payload) => {
      console.error("Message error:", payload)
      showError("Failed to send message")
    })

    channel.on("error", (payload) => {
      console.error("Channel error:", payload)
      showError(payload.reason || "Channel error occurred")
    })

    // Join the channel
    channel.join()
      .receive("ok", (resp) => {
        console.log("Joined channel:", channelId, resp)
      })
      .receive("error", (resp) => {
        console.error("Failed to join channel:", resp)
        showError("Failed to connect to channel")
      })

    channels.set(topic, channel)
    return channel
  },

  leave(channelId) {
    const topic = `channel:${channelId}`
    const channel = channels.get(topic)
    
    if (channel) {
      channel.leave()
      channels.delete(topic)
    }
  },

  sendMessage(channelId, content, options = {}) {
    const channel = channels.get(`channel:${channelId}`)
    if (channel) {
      const payload = {
        content,
        temp_id: generateTempId(),
        ...options
      }
      return channel.push("send_message", payload)
    }
  },

  editMessage(channelId, messageId, content) {
    const channel = channels.get(`channel:${channelId}`)
    if (channel) {
      return channel.push("edit_message", { message_id: messageId, content })
    }
  },

  deleteMessage(channelId, messageId) {
    const channel = channels.get(`channel:${channelId}`)
    if (channel) {
      return channel.push("delete_message", { message_id: messageId })
    }
  },

  addReaction(channelId, messageId, emoji) {
    const channel = channels.get(`channel:${channelId}`)
    if (channel) {
      return channel.push("add_reaction", { message_id: messageId, emoji })
    }
  },

  removeReaction(channelId, reactionId) {
    const channel = channels.get(`channel:${channelId}`)
    if (channel) {
      return channel.push("remove_reaction", { reaction_id: reactionId })
    }
  },

  markMessageRead(channelId, messageId) {
    const channel = channels.get(`channel:${channelId}`)
    if (channel) {
      return channel.push("mark_read", { message_id: messageId })
    }
  },

  startTyping(channelId) {
    const channel = channels.get(`channel:${channelId}`)
    if (channel) {
      return channel.push("typing_start", {})
    }
  },

  stopTyping(channelId) {
    const channel = channels.get(`channel:${channelId}`)
    if (channel) {
      return channel.push("typing_stop", {})
    }
  },

  loadOlderMessages(channelId, beforeId) {
    const channel = channels.get(`channel:${channelId}`)
    if (channel) {
      return channel.push("load_older_messages", { before_id: beforeId })
    }
  }
}

// Utility functions
function generateTempId() {
  return `temp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
}

function updateConnectionStatus(status) {
  const statusElement = document.getElementById('connection-status')
  if (statusElement) {
    statusElement.className = `connection-status ${status}`
    statusElement.textContent = getStatusText(status)
  }
}

function getStatusText(status) {
  switch (status) {
    case 'connected': return 'Connected'
    case 'connecting': return 'Connecting...'
    case 'disconnected': return 'Disconnected'
    case 'error': return 'Connection Error'
    default: return 'Unknown'
  }
}

function showError(message) {
  // Create a simple error notification
  const notification = document.createElement('div')
  notification.className = 'error-notification'
  notification.textContent = message
  notification.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    background: #ef4444;
    color: white;
    padding: 12px 16px;
    border-radius: 6px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    z-index: 1000;
    font-size: 14px;
  `
  
  document.body.appendChild(notification)
  
  // Remove after 5 seconds
  setTimeout(() => {
    if (notification.parentNode) {
      notification.parentNode.removeChild(notification)
    }
  }, 5000)
}

// Only connect the socket if user is authenticated
const userToken = document.querySelector("meta[name='user-token']")?.getAttribute("content") ||
                  localStorage.getItem("user_token")

if (userToken) {
  socket.connect()
} else {
  console.log("No user token found, socket connection skipped")
}

// Export for use in other modules
export { socket, channels }

// Make available globally for debugging
window.userSocket = socket
window.WorkspaceChannel = WorkspaceChannel
window.ChannelChannel = ChannelChannel
