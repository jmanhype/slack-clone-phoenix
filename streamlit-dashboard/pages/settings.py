"""
Settings and Configuration Page
User preferences and application customization
"""

import streamlit as st
import json
import sys
from pathlib import Path

# Add project root to path for imports
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

from utils.config import AppConfig
from utils.theme_manager import ThemeManager

def render_page():
    """Render the settings page"""
    config = AppConfig()
    theme_manager = ThemeManager()
    
    st.title("⚙️ Settings & Configuration")
    st.markdown("Customize your dashboard experience and preferences")
    
    # Settings tabs
    tab1, tab2, tab3, tab4 = st.tabs([
        "🎨 Appearance", 
        "📊 Dashboard", 
        "📁 Data", 
        "🔧 Advanced"
    ])
    
    with tab1:
        render_appearance_settings(config, theme_manager)
    
    with tab2:
        render_dashboard_settings(config)
    
    with tab3:
        render_data_settings(config)
    
    with tab4:
        render_advanced_settings(config)

def render_appearance_settings(config: AppConfig, theme_manager: ThemeManager):
    """Render appearance and theme settings"""
    st.subheader("🎨 Appearance Settings")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Theme Configuration**")
        
        # Theme selection
        current_theme = st.session_state.get('theme', 'light')
        new_theme = st.radio(
            "Color Theme",
            ["light", "dark"],
            index=0 if current_theme == "light" else 1,
            help="Choose between light and dark themes"
        )
        
        if new_theme != current_theme:
            st.session_state.theme = new_theme
            if st.button("Apply Theme"):
                st.experimental_rerun()
        
        # Custom colors
        st.write("**Custom Colors**")
        
        primary_color = st.color_picker(
            "Primary Color",
            value="#FF6B6B",
            help="Main accent color for the application"
        )
        
        secondary_color = st.color_picker(
            "Secondary Color", 
            value="#4ECDC4",
            help="Secondary accent color for charts and highlights"
        )
        
        # Font settings
        st.write("**Typography**")
        
        font_size = st.selectbox(
            "Font Size",
            ["Small", "Medium", "Large"],
            index=1,
            help="Base font size for the application"
        )
        
        font_family = st.selectbox(
            "Font Family",
            ["Default", "Arial", "Helvetica", "Georgia", "Times New Roman"],
            help="Choose the font family for text display"
        )
    
    with col2:
        st.write("**Layout Options**")
        
        # Sidebar settings
        sidebar_state = st.radio(
            "Sidebar Default State",
            ["expanded", "collapsed"],
            index=0,
            help="Default state of the navigation sidebar"
        )
        
        # Page layout
        page_layout = st.radio(
            "Page Layout",
            ["wide", "centered"],
            index=0,
            help="Default layout for page content"
        )
        
        # Chart settings
        st.write("**Chart Preferences**")
        
        default_chart_height = st.slider(
            "Default Chart Height",
            300, 800, 500,
            help="Default height for charts in pixels"
        )
        
        chart_color_palette = st.selectbox(
            "Chart Color Palette",
            [
                "Plotly",
                "Viridis", 
                "Plasma",
                "Set1",
                "Set3",
                "Pastel",
                "Custom"
            ],
            help="Default color palette for charts"
        )
        
        # Animation settings
        enable_animations = st.checkbox(
            "Enable Chart Animations",
            value=True,
            help="Enable smooth animations for chart transitions"
        )
    
    # Save appearance settings
    if st.button("💾 Save Appearance Settings", type="primary"):
        appearance_settings = {
            'theme': new_theme,
            'primary_color': primary_color,
            'secondary_color': secondary_color,
            'font_size': font_size,
            'font_family': font_family,
            'sidebar_state': sidebar_state,
            'page_layout': page_layout,
            'default_chart_height': default_chart_height,
            'chart_color_palette': chart_color_palette,
            'enable_animations': enable_animations
        }
        
        # Save to session state
        st.session_state.user_preferences.update(appearance_settings)
        
        # Save to persistent storage
        if config.save_user_settings(appearance_settings):
            st.success("✅ Appearance settings saved successfully!")
        else:
            st.error("❌ Failed to save settings")

def render_dashboard_settings(config: AppConfig):
    """Render dashboard-specific settings"""
    st.subheader("📊 Dashboard Configuration")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Default Metrics**")
        
        # Metric selection
        available_metrics = [
            "Total Revenue",
            "Total Orders", 
            "Average Order Value",
            "Total Profit",
            "Conversion Rate",
            "Customer Count",
            "Growth Rate",
            "Profit Margin"
        ]
        
        selected_metrics = st.multiselect(
            "Select metrics to display on dashboard",
            available_metrics,
            default=config.DEFAULT_METRICS,
            help="Choose which key metrics to show on the main dashboard"
        )
        
        # Metric refresh rate
        refresh_rate = st.selectbox(
            "Auto Refresh Rate",
            ["None", "30 seconds", "1 minute", "5 minutes", "15 minutes"],
            index=0,
            help="Automatically refresh dashboard data"
        )
        
        # Default time period
        default_time_period = st.selectbox(
            "Default Time Period",
            ["Last 7 days", "Last 30 days", "Last 90 days", "Last 12 months", "All time"],
            index=1,
            help="Default time range for dashboard data"
        )
    
    with col2:
        st.write("**Chart Preferences**")
        
        # Default chart types
        revenue_chart_type = st.selectbox(
            "Revenue Chart Type",
            ["Line Chart", "Area Chart", "Bar Chart"],
            help="Preferred chart type for revenue displays"
        )
        
        category_chart_type = st.selectbox(
            "Category Chart Type", 
            ["Pie Chart", "Donut Chart", "Bar Chart", "Treemap"],
            help="Preferred chart type for category breakdowns"
        )
        
        # Data aggregation
        default_aggregation = st.selectbox(
            "Default Data Aggregation",
            ["Daily", "Weekly", "Monthly", "Quarterly"],
            index=1,
            help="Default time aggregation for trend analysis"
        )
        
        # Number formatting
        st.write("**Display Formatting**")
        
        currency_symbol = st.text_input(
            "Currency Symbol",
            value="$",
            help="Symbol to use for currency displays"
        )
        
        number_format = st.selectbox(
            "Number Format",
            ["1,234.56", "1.234,56", "1 234.56"],
            help="Number formatting style"
        )
        
        decimal_places = st.number_input(
            "Decimal Places",
            min_value=0,
            max_value=4,
            value=2,
            help="Number of decimal places for currency"
        )
    
    # Save dashboard settings
    if st.button("💾 Save Dashboard Settings", type="primary"):
        dashboard_settings = {
            'selected_metrics': selected_metrics,
            'refresh_rate': refresh_rate,
            'default_time_period': default_time_period,
            'revenue_chart_type': revenue_chart_type,
            'category_chart_type': category_chart_type,
            'default_aggregation': default_aggregation,
            'currency_symbol': currency_symbol,
            'number_format': number_format,
            'decimal_places': decimal_places
        }
        
        st.session_state.user_preferences.update(dashboard_settings)
        
        if config.save_user_settings(dashboard_settings):
            st.success("✅ Dashboard settings saved successfully!")
        else:
            st.error("❌ Failed to save settings")

def render_data_settings(config: AppConfig):
    """Render data processing settings"""
    st.subheader("📁 Data Processing Settings")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**File Upload Settings**")
        
        # Max file size
        max_file_size = st.slider(
            "Maximum File Size (MB)",
            10, 500, config.MAX_FILE_SIZE,
            help="Maximum allowed file size for uploads"
        )
        
        # Default encoding
        default_encoding = st.selectbox(
            "Default File Encoding",
            ["utf-8", "latin-1", "cp1252"],
            help="Default encoding for CSV file uploads"
        )
        
        # Date format preferences
        st.write("**Date Format Preferences**")
        
        preferred_date_format = st.selectbox(
            "Preferred Date Format",
            config.DATE_FORMATS,
            help="Preferred format for date parsing"
        )
        
        auto_detect_dates = st.checkbox(
            "Auto-detect Date Columns",
            value=True,
            help="Automatically detect and parse date columns"
        )
        
        # Data validation
        st.write("**Data Validation**")
        
        strict_validation = st.checkbox(
            "Strict Data Validation",
            value=False,
            help="Enable strict validation for data imports"
        )
        
        auto_clean_data = st.checkbox(
            "Auto-clean Data",
            value=True,
            help="Automatically clean common data issues"
        )
    
    with col2:
        st.write("**Processing Options**")
        
        # Memory management
        chunk_size = st.number_input(
            "Processing Chunk Size",
            min_value=1000,
            max_value=100000,
            value=10000,
            help="Number of rows to process at once for large files"
        )
        
        # Caching settings
        enable_caching = st.checkbox(
            "Enable Data Caching",
            value=True,
            help="Cache processed data to improve performance"
        )
        
        cache_duration = st.selectbox(
            "Cache Duration",
            ["1 hour", "6 hours", "24 hours", "1 week"],
            index=1,
            help="How long to keep cached data"
        )
        
        # Export settings
        st.write("**Export Preferences**")
        
        default_export_format = st.selectbox(
            "Default Export Format",
            ["CSV", "Excel", "JSON"],
            help="Default format for data exports"
        )
        
        include_index = st.checkbox(
            "Include Row Index in Exports",
            value=False,
            help="Include row numbers in exported files"
        )
        
        # Sample data settings
        st.write("**Sample Data**")
        
        sample_data_size = st.slider(
            "Sample Dataset Size",
            100, 10000, 1000,
            help="Number of rows in generated sample data"
        )
    
    # Save data settings
    if st.button("💾 Save Data Settings", type="primary"):
        data_settings = {
            'max_file_size': max_file_size,
            'default_encoding': default_encoding,
            'preferred_date_format': preferred_date_format,
            'auto_detect_dates': auto_detect_dates,
            'strict_validation': strict_validation,
            'auto_clean_data': auto_clean_data,
            'chunk_size': chunk_size,
            'enable_caching': enable_caching,
            'cache_duration': cache_duration,
            'default_export_format': default_export_format,
            'include_index': include_index,
            'sample_data_size': sample_data_size
        }
        
        st.session_state.user_preferences.update(data_settings)
        
        if config.save_user_settings(data_settings):
            st.success("✅ Data settings saved successfully!")
        else:
            st.error("❌ Failed to save settings")

def render_advanced_settings(config: AppConfig):
    """Render advanced configuration options"""
    st.subheader("🔧 Advanced Settings")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Performance Settings**")
        
        # Performance options
        enable_multithreading = st.checkbox(
            "Enable Multithreading",
            value=True,
            help="Use multiple threads for data processing"
        )
        
        max_threads = st.slider(
            "Maximum Threads",
            1, 8, 4,
            help="Maximum number of threads to use"
        )
        
        memory_limit = st.slider(
            "Memory Limit (MB)",
            512, 4096, 1024,
            help="Maximum memory usage for data processing"
        )
        
        # Debug options
        st.write("**Debug Options**")
        
        debug_mode = st.checkbox(
            "Debug Mode",
            value=False,
            help="Enable debug logging and error details"
        )
        
        show_performance_metrics = st.checkbox(
            "Show Performance Metrics",
            value=False,
            help="Display processing time and memory usage"
        )
        
        log_level = st.selectbox(
            "Log Level",
            ["ERROR", "WARNING", "INFO", "DEBUG"],
            index=2,
            help="Minimum level for log messages"
        )
    
    with col2:
        st.write("**Integration Settings**")
        
        # API settings
        api_timeout = st.slider(
            "API Timeout (seconds)",
            5, 60, 30,
            help="Timeout for external API calls"
        )
        
        retry_attempts = st.slider(
            "Retry Attempts",
            1, 5, 3,
            help="Number of retry attempts for failed operations"
        )
        
        # Security settings
        st.write("**Security Settings**")
        
        enable_ssl_verification = st.checkbox(
            "Enable SSL Verification",
            value=True,
            help="Verify SSL certificates for external connections"
        )
        
        secure_cookies = st.checkbox(
            "Secure Cookies",
            value=True,
            help="Use secure cookies for session management"
        )
        
        # Backup settings
        st.write("**Backup Settings**")
        
        auto_backup = st.checkbox(
            "Automatic Backups",
            value=False,
            help="Automatically backup user data and settings"
        )
        
        backup_frequency = st.selectbox(
            "Backup Frequency",
            ["Daily", "Weekly", "Monthly"],
            index=1,
            help="How often to create automatic backups"
        )
    
    # Configuration management
    st.markdown("---")
    st.write("**Configuration Management**")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if st.button("📥 Export Settings"):
            settings_json = json.dumps(st.session_state.user_preferences, indent=2)
            st.download_button(
                label="Download Settings",
                data=settings_json,
                file_name="dashboard_settings.json",
                mime="application/json"
            )
    
    with col2:
        uploaded_settings = st.file_uploader(
            "Import Settings",
            type=['json'],
            help="Upload a settings file to import configuration"
        )
        
        if uploaded_settings:
            try:
                imported_settings = json.load(uploaded_settings)
                st.session_state.user_preferences.update(imported_settings)
                if config.save_user_settings(imported_settings):
                    st.success("✅ Settings imported successfully!")
                else:
                    st.error("❌ Failed to import settings")
            except Exception as e:
                st.error(f"❌ Invalid settings file: {str(e)}")
    
    with col3:
        if st.button("🔄 Reset to Defaults"):
            if st.checkbox("Confirm reset all settings"):
                st.session_state.user_preferences = {}
                if config.save_user_settings({}):
                    st.success("✅ Settings reset to defaults!")
                    st.experimental_rerun()
                else:
                    st.error("❌ Failed to reset settings")
    
    # Save advanced settings
    if st.button("💾 Save Advanced Settings", type="primary"):
        advanced_settings = {
            'enable_multithreading': enable_multithreading,
            'max_threads': max_threads,
            'memory_limit': memory_limit,
            'debug_mode': debug_mode,
            'show_performance_metrics': show_performance_metrics,
            'log_level': log_level,
            'api_timeout': api_timeout,
            'retry_attempts': retry_attempts,
            'enable_ssl_verification': enable_ssl_verification,
            'secure_cookies': secure_cookies,
            'auto_backup': auto_backup,
            'backup_frequency': backup_frequency
        }
        
        st.session_state.user_preferences.update(advanced_settings)
        
        if config.save_user_settings(advanced_settings):
            st.success("✅ Advanced settings saved successfully!")
        else:
            st.error("❌ Failed to save settings")