// Import all hooks
import KeyboardShortcuts from './keyboard_shortcuts.js'

// Safe no-op stubs for undeclared hooks to avoid runtime errors
const AutoFocus = { mounted() { if (this.el && this.el.focus) this.el.focus() } }
const ClickOutside = {
  mounted() {
    this._handler = (e) => { if (this.el && !this.el.contains(e.target)) this.pushEvent?.('click_outside') }
    document.addEventListener('mousedown', this._handler)
  },
  destroyed() { document.removeEventListener('mousedown', this._handler) }
}
const TextSelection = {}
const EmojiReactions = {}
const FileUploadPreview = {}

// Message Input Hook (textarea-based)
const MessageInput = {
  mounted() {
    this.el.addEventListener('input', () => {
      this.autoResize()
      this.pushEvent('typing')
    })

    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault()
        const content = this.el.value.trim()
        if (content.length > 0) {
          this.pushEvent('send_message', { content })
        }
      }
    })
  },

  autoResize() {
    this.el.style.height = 'auto'
    this.el.style.height = Math.min(this.el.scrollHeight, 200) + 'px'
  }
}

// Scroll to Bottom Hook
const ScrollToBottom = {
  mounted() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => {
      this.scrollToBottom()
    })
    this.observer.observe(this.el, { childList: true, subtree: true })
  },
  
  destroyed() {
    if (this.observer) {
      this.observer.disconnect()
    }
  },
  
  updated() {
    this.scrollToBottom()
  },
  
  scrollToBottom() {
    requestAnimationFrame(() => {
      this.el.scrollTop = this.el.scrollHeight
    })
  }
}

// Image Viewer Hook
const ImageViewer = {
  mounted() {
    this.handleEvent('open_image', ({ url }) => {
      this.openImageModal(url)
    })
  },
  
  openImageModal(url) {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50'
    modal.innerHTML = `
      <div class="max-w-full max-h-full p-4">
        <img src="${url}" class="max-w-full max-h-full object-contain" />
        <button class="absolute top-4 right-4 text-white hover:text-gray-300 text-2xl">×</button>
      </div>
    `
    
    modal.addEventListener('click', (e) => {
      if (e.target === modal || e.target.tagName === 'BUTTON') {
        document.body.removeChild(modal)
      }
    })
    
    document.body.appendChild(modal)
  }
}

// Drag and Drop Hook
const DragDrop = {
  mounted() {
    this.el.addEventListener('dragover', (e) => {
      e.preventDefault()
      this.el.classList.add('drag-over')
    })
    
    this.el.addEventListener('dragleave', (e) => {
      e.preventDefault()
      this.el.classList.remove('drag-over')
    })
    
    this.el.addEventListener('drop', (e) => {
      e.preventDefault()
      this.el.classList.remove('drag-over')
      
      const files = Array.from(e.dataTransfer.files)
      if (files.length > 0) {
        this.pushEvent('files_dropped', { files: files.map(f => ({
          name: f.name,
          size: f.size,
          type: f.type
        }))})
      }
    })
  }
}

// Infinite Scroll Hook
const InfiniteScroll = {
  mounted() {
    this.pending = this.el.dataset.pending
    this.observer = new IntersectionObserver(entries => {
      const target = entries[0]
      if (target.isIntersecting && this.pending === 'false') {
        this.pushEvent('load_more')
      }
    }, { threshold: 1.0 })
    
    this.observer.observe(this.el)
  },
  
  destroyed() {
    this.observer.unobserve(this.el)
  },
  
  updated() {
    this.pending = this.el.dataset.pending
  }
}

// Auto Focus Hook
const AutoFocus = {
  mounted() {
    this.el.focus()
  }
}

// Click Outside Hook
const ClickOutside = {
  mounted() {
    this.handleClickOutside = (e) => {
      if (!this.el.contains(e.target)) {
        this.pushEvent('click_outside')
      }
    }
    
    document.addEventListener('click', this.handleClickOutside)
  },
  
  destroyed() {
    document.removeEventListener('click', this.handleClickOutside)
  }
}

// Text Selection Hook
const TextSelection = {
  mounted() {
    this.el.addEventListener('mouseup', () => {
      const selection = window.getSelection().toString()
      if (selection) {
        this.pushEvent('text_selected', { text: selection })
      }
    })
  }
}

// Emoji Reactions Hook
const EmojiReactions = {
  mounted() {
    this.handleEvent('add_reaction', ({ messageId, emoji }) => {
      this.pushEvent('toggle_reaction', { messageId, emoji })
    })
  }
}

// File Upload Preview Hook
const FileUploadPreview = {
  mounted() {
    this.el.addEventListener('change', (e) => {
      const files = Array.from(e.target.files)
      const previews = []
      
      files.forEach(file => {
        if (file.type.startsWith('image/')) {
          const reader = new FileReader()
          reader.onload = (e) => {
            previews.push({
              name: file.name,
              size: file.size,
              type: file.type,
              preview: e.target.result
            })
            
            if (previews.length === files.length) {
              this.pushEvent('files_selected', { files: previews })
            }
          }
          reader.readAsDataURL(file)
        } else {
          previews.push({
            name: file.name,
            size: file.size,
            type: file.type,
            preview: null
          })
          
          if (previews.length === files.length) {
            this.pushEvent('files_selected', { files: previews })
          }
        }
      })
    })
  }
}

// Notification Hook
const NotificationHook = {
  mounted() {
    if (window.Notification && window.Notification.permission === 'default') {
      window.Notification.requestPermission()
    }
    
    this.handleEvent('show_notification', ({ title, body, icon }) => {
      if (window.Notification && window.Notification.permission === 'granted') {
        new window.Notification(title, {
          body,
          icon: icon || '/images/slack-icon.png'
        })
      }
    })
  }
}

// Voice Recognition Hook (for voice messages)
const VoiceRecognition = {
  mounted() {
    if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
      this.recognition = new SpeechRecognition()
      this.recognition.continuous = false
      this.recognition.interimResults = false
      
      this.recognition.onresult = (event) => {
        const transcript = event.results[0][0].transcript
        this.pushEvent('voice_input', { text: transcript })
      }
      
      this.recognition.onerror = (event) => {
        this.pushEvent('voice_error', { error: event.error })
      }
    }
    
    this.handleEvent('start_voice_recognition', () => {
      if (this.recognition) {
        this.recognition.start()
      }
    })
    
    this.handleEvent('stop_voice_recognition', () => {
      if (this.recognition) {
        this.recognition.stop()
      }
    })
  }
}

// Copy to Clipboard Hook
const CopyToClipboard = {
  mounted() {
    this.el.addEventListener('click', () => {
      const text = this.el.dataset.text || this.el.textContent
      navigator.clipboard.writeText(text).then(() => {
        this.pushEvent('copied_to_clipboard', { text })
      })
    })
  }
}

// Dark Mode Hook
const DarkMode = {
  mounted() {
    // Initialize theme
    const savedTheme = localStorage.getItem('slack-theme')
    const systemDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    
    if (savedTheme) {
      this.setTheme(savedTheme)
    } else {
      this.setTheme(systemDark ? 'dark' : 'light')
    }
    
    // Listen for theme changes
    this.handleEvent('toggle_theme', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme')
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark'
      this.setTheme(newTheme)
    })
  },
  
  setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme)
    localStorage.setItem('slack-theme', theme)
    
    // Update meta theme-color for mobile
    const metaThemeColor = document.querySelector('meta[name="theme-color"]')
    if (metaThemeColor) {
      metaThemeColor.setAttribute('content', theme === 'dark' ? '#1A0B1E' : '#4A154B')
    }
  }
}

// Export all hooks
export default {
  KeyboardShortcuts,
  MessageInput,
  ScrollToBottom,
  ImageViewer,
  DragDrop,
  InfiniteScroll,
  AutoFocus,
  ClickOutside,
  TextSelection,
  EmojiReactions,
  FileUploadPreview,
  NotificationHook,
  VoiceRecognition,
  CopyToClipboard,
  DarkMode
}
