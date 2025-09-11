// Performance optimization hooks for LiveView components
// Virtual scrolling, lazy loading, and optimized DOM manipulation

export const VirtualScroll = {
  mounted() {
    this.container = this.el.querySelector('#messages-viewport');
    this.spacerTop = this.el.querySelector('#spacer-top');
    this.spacerBottom = this.el.querySelector('#spacer-bottom');
    this.messagesContainer = this.el.querySelector('#messages-container');
    
    this.itemHeight = 80; // Estimated message height
    this.visibleCount = Math.ceil(this.container.clientHeight / this.itemHeight) + 5;
    
    // Throttled scroll handler
    this.scrollHandler = this.throttle(this.handleScroll.bind(this), 16); // 60fps
    this.container.addEventListener('scroll', this.scrollHandler);
    
    // Intersection observer for lazy loading
    this.setupIntersectionObserver();
  },

  destroyed() {
    if (this.container) {
      this.container.removeEventListener('scroll', this.scrollHandler);
    }
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect();
    }
  },

  handleScroll() {
    if (!this.container) return;
    
    const scrollTop = this.container.scrollTop;
    const containerHeight = this.container.clientHeight;
    
    // Calculate visible range
    const startIndex = Math.max(0, Math.floor(scrollTop / this.itemHeight) - 2);
    const endIndex = Math.min(
      this.getTotalItems(),
      startIndex + this.visibleCount
    );
    
    // Update spacer heights
    if (this.spacerTop) {
      this.spacerTop.style.height = `${startIndex * this.itemHeight}px`;
    }
    
    if (this.spacerBottom) {
      const remainingItems = Math.max(0, this.getTotalItems() - endIndex);
      this.spacerBottom.style.height = `${remainingItems * this.itemHeight}px`;
    }
    
    // Notify LiveView of scroll position changes
    this.pushEvent('scroll_update', {
      scrollTop: scrollTop,
      clientHeight: containerHeight,
      scrollHeight: this.container.scrollHeight,
      visibleStart: startIndex,
      visibleEnd: endIndex
    });
  },

  setupIntersectionObserver() {
    if (!window.IntersectionObserver) return;
    
    const options = {
      root: this.container,
      rootMargin: '100px 0px',
      threshold: 0.1
    };
    
    this.intersectionObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.loadVisibleContent(entry.target);
        }
      });
    }, options);
    
    // Observe message items
    this.observeMessages();
  },

  observeMessages() {
    const messages = this.messagesContainer?.querySelectorAll('.message-item');
    if (messages) {
      messages.forEach(message => {
        this.intersectionObserver.observe(message);
      });
    }
  },

  loadVisibleContent(element) {
    // Lazy load message content when it becomes visible
    const messageId = element.dataset.messageId;
    if (messageId && element.dataset.loaded !== 'true') {
      this.pushEvent('load_message_content', { messageId });
      element.dataset.loaded = 'true';
    }
  },

  getTotalItems() {
    return parseInt(this.el.dataset.totalMessages || '0');
  },

  throttle(func, limit) {
    let inThrottle;
    return function() {
      const args = arguments;
      const context = this;
      if (!inThrottle) {
        func.apply(context, args);
        inThrottle = true;
        setTimeout(() => inThrottle = false, limit);
      }
    }
  }
};

export const MessageViewport = {
  mounted() {
    this.setupAutoScroll();
    this.setupLoadMoreTrigger();
  },

  setupAutoScroll() {
    // Auto-scroll to bottom for new messages
    const observer = new MutationObserver(() => {
      if (this.shouldAutoScroll()) {
        this.scrollToBottom();
      }
    });

    observer.observe(this.el, {
      childList: true,
      subtree: true
    });

    this.mutationObserver = observer;
  },

  setupLoadMoreTrigger() {
    // Trigger load more when scrolling to top
    this.el.addEventListener('scroll', this.debounce(() => {
      if (this.el.scrollTop < 100 && this.canLoadMore()) {
        const offset = this.getCurrentOffset();
        this.pushEvent('load_more_messages', { offset: offset.toString() });
      }
    }, 300));
  },

  shouldAutoScroll() {
    const threshold = 100; // pixels from bottom
    const scrollBottom = this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight;
    return scrollBottom < threshold;
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight - this.el.clientHeight;
  },

  canLoadMore() {
    return this.el.dataset.hasMore === 'true';
  },

  getCurrentOffset() {
    return this.el.querySelectorAll('.message-item').length;
  },

  destroyed() {
    if (this.mutationObserver) {
      this.mutationObserver.disconnect();
    }
  },

  debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }
};

export const AutoResize = {
  mounted() {
    this.el.style.resize = 'none';
    this.el.style.overflow = 'hidden';
    this.adjustHeight();
    
    this.el.addEventListener('input', () => this.adjustHeight());
    this.el.addEventListener('keydown', (e) => this.handleKeydown(e));
  },

  adjustHeight() {
    // Reset height to auto to get the correct scrollHeight
    this.el.style.height = 'auto';
    const newHeight = Math.min(this.el.scrollHeight, 120); // Max height of 120px
    this.el.style.height = newHeight + 'px';
  },

  handleKeydown(e) {
    // Handle Enter key for sending messages
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      const form = this.el.closest('form');
      if (form) {
        // Trigger form submission
        form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
      }
    }
  }
};

// Performance chart hooks using Chart.js
export const ResponseTimesChart = {
  mounted() {
    this.initChart();
    this.handleEvent('update_chart_data', (data) => {
      this.updateChart(data);
    });
  },

  initChart() {
    if (typeof Chart === 'undefined') {
      console.warn('Chart.js not loaded');
      return;
    }

    const ctx = this.el.getContext('2d');
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: [],
        datasets: [{
          label: 'Average Response Time (ms)',
          data: [],
          borderColor: 'rgb(59, 130, 246)',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          tension: 0.1,
          fill: true
        }, {
          label: 'P95 Response Time (ms)',
          data: [],
          borderColor: 'rgb(245, 101, 101)',
          backgroundColor: 'rgba(245, 101, 101, 0.1)',
          tension: 0.1,
          fill: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false
        },
        scales: {
          x: {
            display: true,
            title: {
              display: true,
              text: 'Time'
            }
          },
          y: {
            display: true,
            title: {
              display: true,
              text: 'Response Time (ms)'
            },
            min: 0
          }
        },
        plugins: {
          legend: {
            position: 'top'
          },
          tooltip: {
            mode: 'index',
            intersect: false
          }
        }
      }
    });
  },

  updateChart(data) {
    if (!this.chart) return;

    this.chart.data.labels = data.labels;
    this.chart.data.datasets[0].data = data.avgTimes;
    this.chart.data.datasets[1].data = data.p95Times;
    this.chart.update('none'); // No animation for performance
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

export const SystemResourcesChart = {
  mounted() {
    this.initChart();
    this.handleEvent('update_system_data', (data) => {
      this.updateChart(data);
    });
  },

  initChart() {
    if (typeof Chart === 'undefined') return;

    const ctx = this.el.getContext('2d');
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: [],
        datasets: [{
          label: 'CPU Usage (%)',
          data: [],
          borderColor: 'rgb(34, 197, 94)',
          backgroundColor: 'rgba(34, 197, 94, 0.1)',
          yAxisID: 'y'
        }, {
          label: 'Memory Usage (MB)',
          data: [],
          borderColor: 'rgb(168, 85, 247)',
          backgroundColor: 'rgba(168, 85, 247, 0.1)',
          yAxisID: 'y1'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        scales: {
          x: {
            display: true,
            title: {
              display: true,
              text: 'Time'
            }
          },
          y: {
            type: 'linear',
            display: true,
            position: 'left',
            title: {
              display: true,
              text: 'CPU Usage (%)'
            },
            min: 0,
            max: 100
          },
          y1: {
            type: 'linear',
            display: true,
            position: 'right',
            title: {
              display: true,
              text: 'Memory Usage (MB)'
            },
            min: 0,
            grid: {
              drawOnChartArea: false
            }
          }
        }
      }
    });
  },

  updateChart(data) {
    if (!this.chart) return;

    this.chart.data.labels = data.labels;
    this.chart.data.datasets[0].data = data.cpuUsage;
    this.chart.data.datasets[1].data = data.memoryUsage;
    this.chart.update('none');
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

export const CacheChart = {
  mounted() {
    this.initChart();
    this.handleEvent('update_cache_data', (data) => {
      this.updateChart(data);
    });
  },

  initChart() {
    if (typeof Chart === 'undefined') return;

    const ctx = this.el.getContext('2d');
    this.chart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['Cache Hits', 'Cache Misses'],
        datasets: [{
          data: [70, 30],
          backgroundColor: [
            'rgb(34, 197, 94)',
            'rgb(239, 68, 68)'
          ],
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom'
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = ((context.parsed / total) * 100).toFixed(1);
                return `${context.label}: ${percentage}%`;
              }
            }
          }
        }
      }
    });
  },

  updateChart(data) {
    if (!this.chart) return;

    this.chart.data.datasets[0].data = [data.hits, data.misses];
    this.chart.update('none');
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

export const DatabaseChart = {
  mounted() {
    this.initChart();
    this.handleEvent('update_database_data', (data) => {
      this.updateChart(data);
    });
  },

  initChart() {
    if (typeof Chart === 'undefined') return;

    const ctx = this.el.getContext('2d');
    this.chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: ['Active Connections', 'Query Queue', 'Slow Queries'],
        datasets: [{
          label: 'Count',
          data: [0, 0, 0],
          backgroundColor: [
            'rgba(59, 130, 246, 0.8)',
            'rgba(245, 158, 11, 0.8)',
            'rgba(239, 68, 68, 0.8)'
          ]
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true
          }
        },
        plugins: {
          legend: {
            display: false
          }
        }
      }
    });
  },

  updateChart(data) {
    if (!this.chart) return;

    this.chart.data.datasets[0].data = [
      data.activeConnections || 0,
      data.queryQueue || 0,
      data.slowQueries || 0
    ];
    this.chart.update('none');
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

// Utility function to load Chart.js if not already loaded
export const loadChartJS = () => {
  if (typeof Chart !== 'undefined') return Promise.resolve();

  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/chart.js';
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
};

// Initialize charts when the page loads
document.addEventListener('DOMContentLoaded', () => {
  loadChartJS().catch(console.error);
});