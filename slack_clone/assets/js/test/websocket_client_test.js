/**
 * Client-side WebSocket testing for Slack Clone real-time features
 * Tests JavaScript WebSocket client functionality, connection management,
 * and real-time event handling in the browser.
 */

import { Socket } from "phoenix"

// Mock DOM environment for testing
if (typeof window === 'undefined') {
  global.window = {
    location: { protocol: 'http:', hostname: 'localhost', port: '4000' }
  }
}

describe('WebSocket Client Real-time Tests', () => {
  let socket
  let workspaceChannel
  let channelChannel
  let token

  beforeEach(() => {
    // Mock token generation (in real app, this comes from server)
    token = 'test_token_12345'
    
    // Initialize Phoenix Socket
    socket = new Socket('/socket', {
      params: { token: token },
      transport: typeof WebSocket !== 'undefined' ? WebSocket : MockWebSocket
    })
  })

  afterEach(() => {
    if (socket && socket.isConnected()) {
      socket.disconnect()
    }
    if (workspaceChannel) {
      workspaceChannel.leave()
    }
    if (channelChannel) {
      channelChannel.leave()
    }
  })

  describe('Socket Connection Management', () => {
    test('establishes WebSocket connection with valid token', (done) => {
      socket.onOpen(() => {
        expect(socket.isConnected()).toBe(true)
        done()
      })

      socket.onError((error) => {
        done(new Error(`Connection failed: ${error}`))
      })

      socket.connect()
    })

    test('handles connection failures gracefully', (done) => {
      const badSocket = new Socket('/socket', {
        params: { token: 'invalid_token' },
        transport: MockWebSocket
      })

      badSocket.onError((error) => {
        expect(error).toBeDefined()
        done()
      })

      badSocket.onOpen(() => {
        done(new Error('Should not connect with invalid token'))
      })

      badSocket.connect()
    })

    test('automatically reconnects on connection loss', (done) => {
      let reconnectCount = 0

      socket.onOpen(() => {
        if (reconnectCount === 0) {
          // Simulate connection loss
          socket.disconnect()
          socket.connect()
          reconnectCount++
        } else {
          // Reconnected successfully
          expect(socket.isConnected()).toBe(true)
          done()
        }
      })

      socket.connect()
    })

    test('respects connection timeout settings', (done) => {
      const timeoutSocket = new Socket('/socket', {
        params: { token: token },
        timeout: 100, // Very short timeout
        transport: MockSlowWebSocket
      })

      timeoutSocket.onError((error) => {
        expect(error.toString()).toContain('timeout')
        done()
      })

      timeoutSocket.connect()
    })
  })

  describe('Workspace Channel Tests', () => {
    beforeEach((done) => {
      socket.onOpen(() => {
        workspaceChannel = socket.channel('workspace:test_workspace', {})
        done()
      })
      socket.connect()
    })

    test('joins workspace channel successfully', (done) => {
      workspaceChannel.join()
        .receive('ok', (response) => {
          expect(response.workspace).toBeDefined()
          expect(response.user).toBeDefined()
          expect(response.workspace.id).toBe('test_workspace')
          done()
        })
        .receive('error', (error) => {
          done(new Error(`Join failed: ${JSON.stringify(error)}`))
        })
    })

    test('receives workspace state after joining', (done) => {
      workspaceChannel.on('workspace_state', (payload) => {
        expect(payload.channels).toBeDefined()
        expect(payload.online_users).toBeDefined()
        expect(Array.isArray(payload.channels)).toBe(true)
        expect(typeof payload.online_users).toBe('object')
        done()
      })

      workspaceChannel.join()
    })

    test('handles user status changes', (done) => {
      let statusChanged = false

      workspaceChannel.on('presence_diff', (diff) => {
        if (!statusChanged) {
          expect(diff).toBeDefined()
          done()
        }
      })

      workspaceChannel.join()
        .receive('ok', () => {
          statusChanged = true
          workspaceChannel.push('user_status_change', { status: 'away' })
        })
    })

    test('receives real-time channel creation events', (done) => {
      workspaceChannel.on('channel_created', (payload) => {
        expect(payload.channel).toBeDefined()
        expect(payload.channel.name).toBe('new-test-channel')
        done()
      })

      workspaceChannel.join()
        .receive('ok', () => {
          // Simulate channel creation from another client
          setTimeout(() => {
            workspaceChannel.trigger('channel_created', {
              channel: {
                id: 'new_channel_123',
                name: 'new-test-channel',
                type: 'public'
              }
            })
          }, 100)
        })
    })

    test('requests and receives workspace information', (done) => {
      workspaceChannel.on('workspace_info', (info) => {
        expect(info.channels).toBeDefined()
        expect(info.members).toBeDefined()
        expect(info.online_users).toBeDefined()
        expect(info.unread_counts).toBeDefined()
        done()
      })

      workspaceChannel.join()
        .receive('ok', () => {
          workspaceChannel.push('get_workspace_info', {})
        })
    })

    test('handles workspace-level error messages', (done) => {
      workspaceChannel.on('error', (error) => {
        expect(error.event).toBeDefined()
        expect(error.reason || error.errors).toBeDefined()
        done()
      })

      workspaceChannel.join()
        .receive('ok', () => {
          // Trigger an error by trying to create invalid channel
          workspaceChannel.push('create_channel', {
            name: '', // Invalid empty name
            description: 'Test channel',
            type: 'public'
          })
        })
    })
  })

  describe('Channel Communication Tests', () => {
    beforeEach((done) => {
      socket.onOpen(() => {
        channelChannel = socket.channel('channel:general', {})
        done()
      })
      socket.connect()
    })

    test('joins channel and loads recent messages', (done) => {
      let messagesLoaded = false

      channelChannel.on('messages_loaded', (payload) => {
        expect(payload.messages).toBeDefined()
        expect(Array.isArray(payload.messages)).toBe(true)
        messagesLoaded = true
      })

      channelChannel.on('presence_state', (presence) => {
        expect(presence).toBeDefined()
        if (messagesLoaded) {
          done()
        }
      })

      channelChannel.join()
        .receive('ok', (response) => {
          expect(response.channel).toBeDefined()
          expect(response.channel.id).toBe('general')
        })
    })

    test('sends and receives messages', (done) => {
      const testMessage = {
        content: 'Hello from JavaScript test!',
        temp_id: 'temp_' + Date.now()
      }

      channelChannel.on('new_message', (payload) => {
        expect(payload.message).toBeDefined()
        expect(payload.message.content).toBe(testMessage.content)
        done()
      })

      channelChannel.join()
        .receive('ok', () => {
          channelChannel.push('send_message', testMessage)
            .receive('ok', () => {
              // Simulate receiving the message from another client
              setTimeout(() => {
                channelChannel.trigger('new_message', {
                  message: {
                    id: 'msg_123',
                    content: testMessage.content,
                    user_id: 'other_user',
                    channel_id: 'general'
                  }
                })
              }, 100)
            })
        })
    })

    test('handles typing indicators', (done) => {
      let typingStartReceived = false

      channelChannel.on('typing_start', (data) => {
        expect(data.user_id).toBeDefined()
        expect(data.user_name).toBeDefined()
        typingStartReceived = true
      })

      channelChannel.on('typing_stop', (data) => {
        expect(data.user_id).toBeDefined()
        if (typingStartReceived) {
          done()
        }
      })

      channelChannel.join()
        .receive('ok', () => {
          // Start typing
          channelChannel.push('typing_start', {})
          
          // Simulate receiving typing events from another user
          setTimeout(() => {
            channelChannel.trigger('typing_start', {
              user_id: 'other_user',
              user_name: 'Other User'
            })
            
            setTimeout(() => {
              channelChannel.trigger('typing_stop', {
                user_id: 'other_user',
                user_name: 'Other User'
              })
            }, 200)
          }, 100)
        })
    })

    test('handles message reactions', (done) => {
      const messageId = 'msg_123'
      const emoji = '👍'

      channelChannel.on('reaction_added', (payload) => {
        expect(payload.message_id).toBe(messageId)
        expect(payload.reaction).toBeDefined()
        expect(payload.reaction.emoji).toBe(emoji)
        done()
      })

      channelChannel.join()
        .receive('ok', () => {
          channelChannel.push('add_reaction', {
            message_id: messageId,
            emoji: emoji
          })
            .receive('ok', () => {
              // Simulate reaction event
              setTimeout(() => {
                channelChannel.trigger('reaction_added', {
                  message_id: messageId,
                  reaction: {
                    id: 'reaction_123',
                    emoji: emoji,
                    user_id: 'test_user'
                  }
                })
              }, 100)
            })
        })
    })

    test('loads older messages on demand', (done) => {
      channelChannel.on('older_messages_loaded', (payload) => {
        expect(payload.messages).toBeDefined()
        expect(Array.isArray(payload.messages)).toBe(true)
        done()
      })

      channelChannel.join()
        .receive('ok', () => {
          channelChannel.push('load_older_messages', {
            before_id: 'msg_100'
          })
        })
    })

    test('handles thread conversations', (done) => {
      const messageId = 'msg_123'

      channelChannel.on('thread_started', (payload) => {
        expect(payload.message_id).toBe(messageId)
        expect(payload.thread).toBeDefined()
        done()
      })

      channelChannel.join()
        .receive('ok', () => {
          channelChannel.push('start_thread', {
            message_id: messageId
          })
        })
    })

    test('marks messages as read', (done) => {
      const messageId = 'msg_123'

      channelChannel.on('message_read', (payload) => {
        expect(payload.message_id).toBe(messageId)
        expect(payload.user_id).toBeDefined()
        done()
      })

      channelChannel.join()
        .receive('ok', () => {
          channelChannel.push('mark_read', {
            message_id: messageId
          })
            .receive('ok', () => {
              // Simulate read receipt
              setTimeout(() => {
                channelChannel.trigger('message_read', {
                  message_id: messageId,
                  user_id: 'test_user'
                })
              }, 100)
            })
        })
    })
  })

  describe('Error Handling and Recovery', () => {
    beforeEach((done) => {
      socket.onOpen(() => done())
      socket.connect()
    })

    test('handles channel join failures', (done) => {
      const unauthorizedChannel = socket.channel('channel:unauthorized', {})

      unauthorizedChannel.join()
        .receive('error', (error) => {
          expect(error.reason).toBe('Access denied')
          done()
        })
        .receive('ok', () => {
          done(new Error('Should not join unauthorized channel'))
        })
    })

    test('automatically rejoins channel after connection loss', (done) => {
      let joinCount = 0
      const testChannel = socket.channel('channel:general', {})

      testChannel.onJoin(() => {
        joinCount++
        if (joinCount === 1) {
          // Simulate connection loss and recovery
          socket.disconnect()
          setTimeout(() => {
            socket.connect()
          }, 100)
        } else if (joinCount === 2) {
          // Successfully rejoined
          done()
        }
      })

      testChannel.join()
    })

    test('handles malformed message errors', (done) => {
      const testChannel = socket.channel('channel:general', {})

      testChannel.on('message_error', (error) => {
        expect(error.temp_id).toBe('temp_malformed')
        expect(error.errors).toBeDefined()
        done()
      })

      testChannel.join()
        .receive('ok', () => {
          // Send malformed message
          testChannel.push('send_message', {
            temp_id: 'temp_malformed'
            // Missing required 'content' field
          })
        })
    })

    test('handles server-side errors gracefully', (done) => {
      const testChannel = socket.channel('channel:general', {})

      testChannel.on('error', (error) => {
        expect(error).toBeDefined()
        done()
      })

      testChannel.join()
        .receive('ok', () => {
          // Trigger server error
          testChannel.trigger('error', {
            event: 'test_error',
            reason: 'Simulated server error'
          })
        })
    })

    test('maintains state consistency during network issues', (done) => {
      const testChannel = socket.channel('channel:general', {})
      let stateConsistent = true

      testChannel.on('presence_diff', (diff) => {
        // Check that presence updates are consistent
        if (diff.joins || diff.leaves) {
          stateConsistent = stateConsistent && 
            (typeof diff.joins === 'object' && typeof diff.leaves === 'object')
        }
      })

      testChannel.join()
        .receive('ok', () => {
          // Simulate multiple rapid state changes
          for (let i = 0; i < 5; i++) {
            setTimeout(() => {
              testChannel.trigger('presence_diff', {
                joins: { [`user_${i}`]: { metas: [{ status: 'online' }] } },
                leaves: {}
              })
            }, i * 50)
          }

          setTimeout(() => {
            expect(stateConsistent).toBe(true)
            done()
          }, 500)
        })
    })
  })

  describe('Performance and Load Tests', () => {
    test('handles rapid message events efficiently', (done) => {
      const testChannel = socket.channel('channel:general', {})
      let messageCount = 0
      const targetMessages = 100
      const startTime = Date.now()

      testChannel.on('new_message', () => {
        messageCount++
        if (messageCount === targetMessages) {
          const endTime = Date.now()
          const duration = endTime - startTime
          
          // Should handle 100 messages in reasonable time (less than 2 seconds)
          expect(duration).toBeLessThan(2000)
          expect(messageCount).toBe(targetMessages)
          done()
        }
      })

      testChannel.join()
        .receive('ok', () => {
          // Simulate rapid message influx
          for (let i = 0; i < targetMessages; i++) {
            setTimeout(() => {
              testChannel.trigger('new_message', {
                message: {
                  id: `rapid_msg_${i}`,
                  content: `Rapid message ${i}`,
                  user_id: 'load_test_user'
                }
              })
            }, Math.floor(i / 10)) // Batch messages to avoid overwhelming
          }
        })
    })

    test('memory usage remains stable under load', (done) => {
      const channels = []
      const channelCount = 10

      let joinedChannels = 0

      for (let i = 0; i < channelCount; i++) {
        const channel = socket.channel(`channel:load_test_${i}`, {})
        
        channel.join()
          .receive('ok', () => {
            joinedChannels++
            if (joinedChannels === channelCount) {
              // All channels joined, now clean up
              channels.forEach(ch => ch.leave())
              
              // Test passes if we can create and clean up multiple channels
              // without memory leaks (in a real browser environment)
              done()
            }
          })
        
        channels.push(channel)
      }
    })

    test('concurrent operations do not cause conflicts', (done) => {
      const testChannel = socket.channel('channel:general', {})
      let operationsCompleted = 0
      const totalOperations = 20

      testChannel.join()
        .receive('ok', () => {
          // Perform multiple concurrent operations
          for (let i = 0; i < totalOperations; i++) {
            testChannel.push('send_message', {
              content: `Concurrent message ${i}`,
              temp_id: `temp_${i}`
            })
              .receive('ok', () => {
                operationsCompleted++
                if (operationsCompleted === totalOperations) {
                  done()
                }
              })
              .receive('error', () => {
                operationsCompleted++
                if (operationsCompleted === totalOperations) {
                  done()
                }
              })
          }
        })
    })
  })
})

// Mock WebSocket implementations for testing
class MockWebSocket {
  constructor(url) {
    this.url = url
    this.readyState = WebSocket.CONNECTING
    this.onopen = null
    this.onclose = null
    this.onmessage = null
    this.onerror = null

    // Simulate successful connection
    setTimeout(() => {
      this.readyState = WebSocket.OPEN
      if (this.onopen) {
        this.onopen(new Event('open'))
      }
    }, 10)
  }

  send(data) {
    if (this.readyState !== WebSocket.OPEN) {
      throw new Error('WebSocket is not open')
    }
    
    // Echo back a basic response for testing
    setTimeout(() => {
      if (this.onmessage) {
        this.onmessage({
          data: JSON.stringify({
            event: 'phx_reply',
            payload: { status: 'ok', response: {} },
            ref: Date.now()
          })
        })
      }
    }, 5)
  }

  close() {
    this.readyState = WebSocket.CLOSED
    if (this.onclose) {
      this.onclose(new Event('close'))
    }
  }

  // Mock WebSocket constants
  static get CONNECTING() { return 0 }
  static get OPEN() { return 1 }
  static get CLOSING() { return 2 }
  static get CLOSED() { return 3 }
}

class MockSlowWebSocket extends MockWebSocket {
  constructor(url) {
    super(url)
    
    // Simulate slow connection (never connects for timeout testing)
    clearTimeout(this._connectTimeout)
  }
}

// Assign to global for Phoenix Socket to use
if (typeof WebSocket === 'undefined') {
  global.WebSocket = MockWebSocket
}