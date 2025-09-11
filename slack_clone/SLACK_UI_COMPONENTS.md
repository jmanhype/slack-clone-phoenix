# Slack Clone UI Components

A comprehensive Slack-identical UI built with Phoenix LiveView and Tailwind CSS, featuring all the modern Slack interface components with full responsive design and dark mode support.

## 🎨 Design System

### Color Scheme
- **Slack Purple**: `#4A154B` (Primary brand color)
- **Slack Green**: `#2EB67D` (Success, active status)
- **Slack Blue**: `#1264A3` (Links, focus states)
- **Slack Red**: `#E01E5A` (Errors, notifications)
- **Custom CSS Variables**: Full theme system with dark mode support

### Typography
- **Font Family**: Lato, system fonts
- **Custom Text Sizes**: `slack-xs`, `slack-sm`, `slack-base`, `slack-lg`
- **Message Formatting**: Bold, italic, strikethrough, code, quotes

### Spacing & Layout
- **Sidebar Widths**: Workspace (64px), Channels (260px), Thread (320px)
- **Responsive Breakpoints**: Mobile-first design with `md:` prefix
- **Grid System**: Tailwind's flexbox and grid utilities

## 🏗️ Component Architecture

### 1. Main Layout (`SlackLayoutComponent`)
The master layout component that orchestrates the entire Slack interface:
- **Desktop Layout**: Workspace switcher + Channel list + Main area + Right sidebar
- **Mobile Layout**: Single-view navigation with slide transitions
- **Global Modals**: Search, quick switcher, keyboard shortcuts
- **Toast Notifications**: Success, error, warning messages
- **Connection Status**: Real-time connection indicator

### 2. Workspace Switcher (`WorkspaceSwitcherComponent`)
Left-most vertical sidebar with workspace management:
- **Current Workspace**: Highlighted with white background
- **Workspace List**: Circular icons with hover tooltips
- **Add Workspace**: Plus button with border styling
- **User Profile**: Avatar with presence indicator at bottom
- **Hover Effects**: Rounded corners transition, tooltips

### 3. Channel List (`ChannelListComponent`)
Main sidebar with channels, DMs, and navigation:
- **Workspace Header**: Name, user status, new message button
- **Search Bar**: Global search with keyboard shortcut
- **Collapsible Sections**: Channels, Direct Messages, Apps
- **Channel Items**: Icons (#, 🔒), unread badges, mention indicators
- **User Presence**: Green/yellow/gray dots for online status
- **Hover States**: Background color transitions

### 4. Message Area (`MessageAreaComponent`)
Central content area with messages and conversation:
- **Dynamic Header**: Channel name, description, member count, actions
- **Channel Intro**: Welcome message with quick actions
- **Message Stream**: Real-time message updates with Phoenix streams
- **Typing Indicators**: Animated dots with user names
- **Message Input**: Rich text editor with formatting toolbar

### 5. Message Component (`MessageComponent`)
Individual message rendering with rich features:
- **Avatar Column**: User photos, timestamp on hover for threaded messages
- **Message Header**: User name, bot badge, timestamp, edited indicator
- **Content Rendering**: Markdown-style formatting, mentions, channels
- **Attachments**: Images, files, link previews with proper styling
- **Reactions**: Emoji buttons with counts, hover effects
- **Thread Replies**: Participant avatars, reply count, last reply time
- **Action Menu**: Edit, copy, share, delete options on hover

### 6. Message Input (`MessageInputComponent`)
Advanced message composition with rich formatting:
- **Formatting Toolbar**: Bold, italic, strikethrough, code, lists, quotes
- **Rich Text Editor**: Contenteditable with keyboard shortcuts
- **File Attachments**: Drag & drop, preview thumbnails
- **Emoji Picker**: Categorized emoji selection with search
- **Mentions & Commands**: @ and / autocomplete with user/command search
- **Send Options**: Schedule message, thread reply checkbox
- **Character Count**: Visual feedback for long messages

### 7. Right Sidebar (`RightSidebarComponent`)
Context-sensitive sidebar with three modes:
- **Thread View**: Original message + replies with threading UI
- **Channel Details**: About, settings, members list, pinned messages
- **User Profile**: DM contact info, presence, call options
- **Slide Animation**: Smooth in/out transitions

### 8. Mobile Layout (`MobileLayoutComponent`)
Full mobile-responsive interface:
- **Mobile Header**: Back button, workspace menu, page title, actions
- **View States**: Channels list, conversation, thread, search, info
- **Touch Navigation**: Swipe gestures, tap interactions
- **Mobile Message Input**: Simplified toolbar, file upload
- **Responsive Grid**: Optimized layouts for small screens

### 9. Loading Skeletons (`LoadingSkeletonComponent`)
Sophisticated loading states:
- **Message List**: Avatar + content placeholders with animation
- **Channel List**: Hierarchical skeleton structure
- **Thread View**: Original message + replies structure
- **Sidebar Details**: User info, settings, members skeletons
- **Search Results**: Grid layout with metadata placeholders

### 10. Utility Components
- **Emoji Picker**: Categorized with search, frequently used
- **Keyboard Shortcuts**: Modal with organized shortcut reference
- **Search Modal**: Global search with filters and results
- **Quick Switcher**: Channel/user jump with fuzzy search
- **Notification Toast**: Success/error/warning with auto-dismiss

## 🎯 Key Features

### Visual Design
- **Pixel-Perfect Slack Recreation**: Exact colors, spacing, typography
- **Hover Effects**: Subtle background changes, button states
- **Focus States**: Blue outline for accessibility
- **Animations**: Smooth transitions, loading states, slide effects
- **Icons**: Heroicons integration with proper sizing

### User Experience
- **Keyboard Shortcuts**: Full Slack keyboard navigation support
- **Real-time Updates**: LiveView streams for instant message updates
- **Typing Indicators**: Live user typing status with animations
- **Presence Dots**: Online/away/offline status throughout UI
- **Unread Badges**: Red notification counts and mention indicators

### Responsive Design
- **Mobile-First**: Touch-friendly interface with swipe navigation
- **Breakpoint System**: `mobile-hidden` classes for desktop-only elements
- **Flexible Layout**: Adapts to different screen sizes gracefully
- **Touch Gestures**: Mobile-optimized interactions

### Accessibility
- **ARIA Labels**: Proper screen reader support
- **Keyboard Navigation**: Tab order and focus management
- **High Contrast**: Proper color contrast ratios
- **Focus Indicators**: Visible focus states for all interactive elements

### Dark Mode Support
- **CSS Variables**: Complete theme system with automatic switching
- **System Preference**: Respects user's OS dark mode setting
- **Persistent Storage**: Saves theme preference in localStorage
- **Smooth Transitions**: Theme changes without flashing

## 🚀 Technical Implementation

### CSS Architecture
```css
/* Custom CSS Variables for theming */
:root {
  --slack-purple: #4A154B;
  --slack-green: #2EB67D;
  --slack-bg-primary: #FFFFFF;
  /* ... more variables */
}

[data-theme="dark"] {
  --slack-bg-primary: #1A1D29;
  /* ... dark theme overrides */
}
```

### Component Structure
```elixir
defmodule SlackCloneWeb.ComponentName do
  use SlackCloneWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <!-- Component JSX-like template -->
    """
  end
  
  @impl true
  def update(assigns, socket) do
    # State management logic
  end
  
  @impl true
  def handle_event(event, params, socket) do
    # Event handling
  end
end
```

### JavaScript Hooks
```javascript
const HookName = {
  mounted() {
    // Component initialization
  },
  updated() {
    // DOM update handling
  },
  destroyed() {
    // Cleanup
  }
}
```

### LiveView Integration
- **Phoenix Streams**: Real-time message updates
- **Component Communication**: Parent-child event passing
- **State Management**: Assign-based state with update cycles
- **Event Handling**: phx-click, phx-keydown, custom events

## 📱 Mobile Responsiveness

### Mobile Navigation
- **Header Navigation**: Context-aware back buttons and actions
- **View Switching**: Smooth transitions between list/detail views
- **Touch Targets**: Properly sized buttons (44px minimum)
- **Gesture Support**: Swipe gestures for navigation

### Mobile Layouts
- **Single Column**: Stacked layout for mobile screens
- **Full Width**: Mobile-specific spacing and sizing
- **Touch Interactions**: Tap states, long press menus
- **Keyboard Handling**: Mobile keyboard awareness

## 🎨 Animation & Interactions

### CSS Animations
```css
@keyframes slack-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

@keyframes slack-fade-in {
  from { opacity: 0; transform: translateY(4px); }
  to { opacity: 1; transform: translateY(0); }
}
```

### Interaction States
- **Hover Effects**: Background color changes, border highlights
- **Active States**: Button press feedback, selection states
- **Loading States**: Skeleton animations, spinner overlays
- **Transition Effects**: Smooth property changes with CSS transitions

## 🔧 Customization

### Theme Variables
Easily customize colors by modifying CSS variables:
```css
:root {
  --slack-purple: #your-color;
  --slack-green: #your-color;
  /* ... other variables */
}
```

### Component Props
All components accept customizable props for:
- **Data**: Users, channels, messages
- **State**: Active states, loading states, visibility
- **Configuration**: Display modes, feature flags
- **Callbacks**: Event handlers, navigation functions

### Responsive Utilities
```html
<div class="hidden md:flex">Desktop only</div>
<div class="md:hidden">Mobile only</div>
<div class="mobile-full">Full width on mobile</div>
```

## 🎯 Usage Examples

### Basic Channel View
```heex
<.live_component 
  module={SlackCloneWeb.MessageAreaComponent}
  id="message-area"
  channel={@current_channel}
  channel_id={@current_channel.id}
  current_user={@current_user}
  streams={@streams}
/>
```

### Mobile Layout
```heex
<.live_component 
  module={SlackCloneWeb.MobileLayoutComponent}
  id="mobile-layout"
  mobile_view={@mobile_view}
  channels={@channels}
  current_user={@current_user}
/>
```

### Loading States
```heex
<.live_component 
  module={SlackCloneWeb.LoadingSkeletonComponent}
  id="loading"
  type="message_list"
  count={5}
/>
```

This comprehensive UI component library provides everything needed to build a modern, Slack-identical interface with Phoenix LiveView and Tailwind CSS. All components are production-ready with proper error handling, accessibility support, and mobile responsiveness.