// Slack Clone Keyboard Shortcuts Hook
export const KeyboardShortcuts = {
  mounted() {
    this.shortcuts = new Map([
      // Navigation shortcuts
      ['cmd+k', () => this.pushEvent('show_search')],
      ['ctrl+k', () => this.pushEvent('show_search')],
      ['cmd+shift+k', () => this.pushEvent('show_quick_switch')],
      ['ctrl+shift+k', () => this.pushEvent('show_quick_switch')],
      
      // Message shortcuts
      ['cmd+enter', () => this.pushEvent('send_message')],
      ['ctrl+enter', () => this.pushEvent('send_message')],
      ['cmd+z', () => this.pushEvent('undo_message')],
      ['ctrl+z', () => this.pushEvent('undo_message')],
      ['escape', () => this.pushEvent('escape_action')],
      
      // Formatting shortcuts
      ['cmd+b', (e) => this.formatText(e, 'bold')],
      ['ctrl+b', (e) => this.formatText(e, 'bold')],
      ['cmd+i', (e) => this.formatText(e, 'italic')],
      ['ctrl+i', (e) => this.formatText(e, 'italic')],
      ['cmd+shift+x', (e) => this.formatText(e, 'strikethrough')],
      ['ctrl+shift+x', (e) => this.formatText(e, 'strikethrough')],
      ['cmd+shift+c', (e) => this.formatText(e, 'code')],
      ['ctrl+shift+c', (e) => this.formatText(e, 'code')],
      ['cmd+shift+>', (e) => this.formatText(e, 'quote')],
      ['ctrl+shift+>', (e) => this.formatText(e, 'quote')],
      
      // Navigation within channels
      ['alt+up', () => this.pushEvent('previous_channel')],
      ['alt+down', () => this.pushEvent('next_channel')],
      ['cmd+[', () => this.pushEvent('back')],
      ['ctrl+[', () => this.pushEvent('back')],
      ['cmd+]', () => this.pushEvent('forward')],
      ['ctrl+]', () => this.pushEvent('forward')],
      
      // Thread shortcuts
      ['t', () => this.pushEvent('reply_to_thread')],
      ['r', () => this.pushEvent('reply_to_message')],
      ['e', () => this.pushEvent('edit_message')],
      ['a', () => this.pushEvent('add_reaction')],
      
      // View shortcuts
      ['cmd+shift+d', () => this.pushEvent('toggle_dark_mode')],
      ['ctrl+shift+d', () => this.pushEvent('toggle_dark_mode')],
      ['cmd+/', () => this.pushEvent('show_keyboard_shortcuts')],
      ['ctrl+/', () => this.pushEvent('show_keyboard_shortcuts')],
      ['f6', () => this.pushEvent('focus_message_input')],
      
      // Mark shortcuts
      ['shift+escape', () => this.pushEvent('mark_all_read')],
      ['cmd+shift+a', () => this.pushEvent('toggle_all_unreads')],
      ['ctrl+shift+a', () => this.pushEvent('toggle_all_unreads')],
      
      // Mention shortcuts
      ['cmd+shift+m', () => this.pushEvent('show_mentions')],
      ['ctrl+shift+m', () => this.pushEvent('show_mentions')],
    ]);

    this.handleKeyDown = this.handleKeyDown.bind(this);
    document.addEventListener('keydown', this.handleKeyDown);

    // Initialize theme
    this.initializeTheme();
  },

  destroyed() {
    document.removeEventListener('keydown', this.handleKeyDown);
  },

  handleKeyDown(event) {
    // Don't trigger shortcuts when typing in inputs (except for specific ones)
    const activeElement = document.activeElement;
    const isInputFocused = activeElement && (
      activeElement.tagName === 'INPUT' || 
      activeElement.tagName === 'TEXTAREA' || 
      activeElement.contentEditable === 'true'
    );

    const shortcutKey = this.getShortcutKey(event);
    const shortcutHandler = this.shortcuts.get(shortcutKey);

    if (shortcutHandler) {
      // Some shortcuts work in inputs, some don't
      const inputAllowedShortcuts = [
        'cmd+k', 'ctrl+k', 'cmd+enter', 'ctrl+enter', 'cmd+z', 'ctrl+z',
        'escape', 'cmd+b', 'ctrl+b', 'cmd+i', 'ctrl+i', 'cmd+shift+x',
        'ctrl+shift+x', 'cmd+shift+c', 'ctrl+shift+c', 'cmd+shift+>',
        'ctrl+shift+>', 'cmd+/', 'ctrl+/', 'cmd+shift+d', 'ctrl+shift+d'
      ];

      if (!isInputFocused || inputAllowedShortcuts.includes(shortcutKey)) {
        event.preventDefault();
        shortcutHandler(event);
      }
    }

    // Special handling for single-key shortcuts (only when not in input)
    if (!isInputFocused && !event.metaKey && !event.ctrlKey && !event.altKey && !event.shiftKey) {
      const singleKeyHandler = this.shortcuts.get(event.key.toLowerCase());
      if (singleKeyHandler) {
        event.preventDefault();
        singleKeyHandler(event);
      }
    }
  },

  getShortcutKey(event) {
    let parts = [];
    
    if (event.metaKey) parts.push('cmd');
    if (event.ctrlKey) parts.push('ctrl');
    if (event.altKey) parts.push('alt');
    if (event.shiftKey) parts.push('shift');
    
    parts.push(event.key.toLowerCase());
    
    return parts.join('+');
  },

  formatText(event, type) {
    event.preventDefault();
    
    const activeElement = document.activeElement;
    if (!activeElement || (activeElement.tagName !== 'TEXTAREA' && activeElement.contentEditable !== 'true')) {
      return;
    }

    const selection = window.getSelection();
    const selectedText = selection.toString();

    if (activeElement.contentEditable === 'true') {
      // For contenteditable elements
      this.formatContentEditable(activeElement, selection, selectedText, type);
    } else {
      // For textarea elements  
      this.formatTextarea(activeElement, selectedText, type);
    }
  },

  formatContentEditable(element, selection, selectedText, type) {
    if (selectedText) {
      const range = selection.getRangeAt(0);
      range.deleteContents();

      let formattedText;
      switch (type) {
        case 'bold':
          formattedText = `**${selectedText}**`;
          break;
        case 'italic':
          formattedText = `*${selectedText}*`;
          break;
        case 'strikethrough':
          formattedText = `~${selectedText}~`;
          break;
        case 'code':
          formattedText = `\`${selectedText}\``;
          break;
        case 'quote':
          formattedText = `> ${selectedText}`;
          break;
        default:
          formattedText = selectedText;
      }

      const textNode = document.createTextNode(formattedText);
      range.insertNode(textNode);

      // Move cursor to end of inserted text
      const newRange = document.createRange();
      newRange.setStartAfter(textNode);
      newRange.setEndAfter(textNode);
      selection.removeAllRanges();
      selection.addRange(newRange);
    } else {
      // Insert formatting markers at cursor
      let markers;
      switch (type) {
        case 'bold':
          markers = '****';
          break;
        case 'italic':
          markers = '**';
          break;
        case 'strikethrough':
          markers = '~~';
          break;
        case 'code':
          markers = '``';
          break;
        case 'quote':
          markers = '> ';
          break;
        default:
          return;
      }

      document.execCommand('insertText', false, markers);
      
      if (type !== 'quote') {
        // Move cursor to middle of markers
        const selection = window.getSelection();
        const range = selection.getRangeAt(0);
        range.setStart(range.startContainer, range.startOffset - markers.length / 2);
        range.setEnd(range.startContainer, range.startOffset);
        selection.removeAllRanges();
        selection.addRange(range);
      }
    }

    // Trigger input event to notify LiveView
    element.dispatchEvent(new Event('input', { bubbles: true }));
  },

  formatTextarea(element, selectedText, type) {
    const start = element.selectionStart;
    const end = element.selectionEnd;
    const text = element.value;

    if (selectedText) {
      let formattedText;
      switch (type) {
        case 'bold':
          formattedText = `**${selectedText}**`;
          break;
        case 'italic':
          formattedText = `*${selectedText}*`;
          break;
        case 'strikethrough':
          formattedText = `~${selectedText}~`;
          break;
        case 'code':
          formattedText = `\`${selectedText}\``;
          break;
        case 'quote':
          formattedText = `> ${selectedText}`;
          break;
        default:
          formattedText = selectedText;
      }

      element.value = text.substring(0, start) + formattedText + text.substring(end);
      element.selectionStart = start + formattedText.length;
      element.selectionEnd = start + formattedText.length;
    } else {
      // Insert formatting markers at cursor
      let markers;
      let cursorOffset;
      
      switch (type) {
        case 'bold':
          markers = '****';
          cursorOffset = 2;
          break;
        case 'italic':
          markers = '**';
          cursorOffset = 1;
          break;
        case 'strikethrough':
          markers = '~~';
          cursorOffset = 1;
          break;
        case 'code':
          markers = '``';
          cursorOffset = 1;
          break;
        case 'quote':
          markers = '> ';
          cursorOffset = 2;
          break;
        default:
          return;
      }

      element.value = text.substring(0, start) + markers + text.substring(start);
      element.selectionStart = start + cursorOffset;
      element.selectionEnd = start + cursorOffset;
    }

    // Trigger input event
    element.dispatchEvent(new Event('input', { bubbles: true }));
    element.focus();
  },

  initializeTheme() {
    // Check for saved theme preference or default to system preference
    const savedTheme = localStorage.getItem('slack-theme');
    const systemDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    
    if (savedTheme) {
      this.setTheme(savedTheme);
    } else {
      this.setTheme(systemDark ? 'dark' : 'light');
    }

    // Listen for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem('slack-theme')) {
        this.setTheme(e.matches ? 'dark' : 'light');
      }
    });
  },

  setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('slack-theme', theme);
    
    // Update meta theme-color for mobile browsers
    const metaThemeColor = document.querySelector('meta[name="theme-color"]');
    if (metaThemeColor) {
      metaThemeColor.setAttribute('content', theme === 'dark' ? '#1A0B1E' : '#4A154B');
    }
  },

  toggleTheme() {
    const currentTheme = document.documentElement.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    this.setTheme(newTheme);
    
    // Notify server of theme change
    this.pushEvent('theme_changed', { theme: newTheme });
  },

  // Handle events from server
  handleEvent(event, payload) {
    switch (event) {
      case 'toggle_dark_mode':
        this.toggleTheme();
        break;
      case 'show_keyboard_shortcuts':
        this.showKeyboardShortcuts();
        break;
      case 'focus_message_input':
        this.focusMessageInput();
        break;
    }
  },

  showKeyboardShortcuts() {
    // This would typically open a modal with keyboard shortcuts
    this.pushEvent('show_shortcuts_modal');
  },

  focusMessageInput() {
    const messageInput = document.querySelector('[data-message-input]') || 
                       document.querySelector('textarea[placeholder*="Message"]') ||
                       document.querySelector('[contenteditable="true"]');
    
    if (messageInput) {
      messageInput.focus();
      
      // If it's a contenteditable, move cursor to end
      if (messageInput.contentEditable === 'true') {
        const range = document.createRange();
        const selection = window.getSelection();
        range.selectNodeContents(messageInput);
        range.collapse(false);
        selection.removeAllRanges();
        selection.addRange(range);
      }
    }
  }
};

// Export for use in app.js
export default KeyboardShortcuts;