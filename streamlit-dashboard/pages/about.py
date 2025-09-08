"""
About Page
Documentation and information about the application
"""

import streamlit as st
import sys
from pathlib import Path

# Add project root to path for imports
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

from utils.config import AppConfig

def render_page():
    """Render the about page"""
    config = AppConfig()
    
    st.title("ℹ️ About Analytics Dashboard")
    st.markdown("Learn more about this comprehensive data analytics platform")
    
    # Application overview
    render_app_overview(config)
    
    st.markdown("---")
    
    # Features section
    render_features_section()
    
    st.markdown("---")
    
    # Technical details
    render_technical_details()
    
    st.markdown("---")
    
    # Usage guide
    render_usage_guide()
    
    st.markdown("---")
    
    # Support and resources
    render_support_section()

def render_app_overview(config: AppConfig):
    """Render application overview section"""
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.subheader("📊 Application Overview")
        
        st.markdown(f"""
        **{config.APP_NAME}** is a comprehensive, interactive data analytics dashboard 
        built with Streamlit. It provides powerful tools for data visualization, 
        exploration, and analysis in an intuitive web-based interface.
        
        **Version:** {config.VERSION}  
        **Author:** {config.AUTHOR}  
        **Built with:** Streamlit, Plotly, Pandas
        
        This application is designed to help users:
        - 📈 Visualize complex datasets with interactive charts
        - 🔍 Explore data through advanced filtering and analysis
        - 📤 Upload and process their own CSV/Excel files
        - ⚙️ Customize the dashboard to their preferences
        - 📊 Generate insights from business data
        """)
    
    with col2:
        st.subheader("🎯 Key Benefits")
        
        benefits = [
            "✅ **No Coding Required** - User-friendly interface",
            "🚀 **Fast Performance** - Optimized data processing", 
            "📱 **Responsive Design** - Works on all devices",
            "🔒 **Data Privacy** - All processing happens locally",
            "🎨 **Customizable** - Themes and preferences",
            "📊 **Professional Charts** - Publication-ready visualizations"
        ]
        
        for benefit in benefits:
            st.markdown(benefit)

def render_features_section():
    """Render detailed features section"""
    st.subheader("🌟 Key Features")
    
    # Feature tabs
    tab1, tab2, tab3, tab4 = st.tabs([
        "📊 Dashboard", 
        "📤 Data Upload", 
        "🔍 Data Explorer", 
        "⚙️ Customization"
    ])
    
    with tab1:
        st.write("**Main Dashboard Features:**")
        
        dashboard_features = [
            "📈 **Real-time KPI Metrics** - Track key performance indicators",
            "📊 **Interactive Charts** - Line charts, bar charts, pie charts, and more",
            "📅 **Time Series Analysis** - Trend analysis with moving averages",
            "🌍 **Regional Performance** - Geographic data visualization", 
            "💰 **Revenue & Profit Tracking** - Financial metrics and analysis",
            "📱 **Responsive Layout** - Optimized for desktop and mobile",
            "🎨 **Custom Themes** - Light and dark mode support",
            "⚡ **Fast Loading** - Optimized performance with caching"
        ]
        
        for feature in dashboard_features:
            st.markdown(feature)
    
    with tab2:
        st.write("**Data Upload Capabilities:**")
        
        upload_features = [
            "📁 **Multiple Formats** - CSV, Excel (XLSX, XLS) support",
            "🔍 **Data Validation** - Automatic format and quality checking",
            "👀 **Live Preview** - See your data before processing",
            "🧹 **Data Cleaning** - Automatic data type detection and conversion",
            "⚙️ **Processing Options** - Custom encoding, sheet selection",
            "📊 **Quality Analysis** - Missing values and data type analysis",
            "🔧 **Transformations** - Built-in data transformation tools",
            "💾 **Export Options** - Download processed data"
        ]
        
        for feature in upload_features:
            st.markdown(feature)
    
    with tab3:
        st.write("**Data Explorer Tools:**")
        
        explorer_features = [
            "🔍 **Advanced Filtering** - Multi-column filtering with ranges",
            "📊 **Custom Charts** - Build your own visualizations",
            "📈 **Statistical Analysis** - Descriptive statistics and correlations",
            "🎯 **Outlier Detection** - Identify and analyze data anomalies",
            "📋 **Interactive Tables** - Search, sort, and paginate data",
            "📥 **Export Filtered Data** - Download your filtered datasets",
            "🔗 **Correlation Analysis** - Understand relationships in your data",
            "📊 **Distribution Analysis** - Visualize data distributions"
        ]
        
        for feature in explorer_features:
            st.markdown(feature)
    
    with tab4:
        st.write("**Customization Options:**")
        
        custom_features = [
            "🎨 **Theme Selection** - Light and dark themes",
            "🖌️ **Custom Colors** - Personalize your color scheme",
            "📊 **Chart Preferences** - Default chart types and settings",
            "📱 **Layout Options** - Sidebar and page layout customization",
            "⚙️ **Data Processing** - File upload and processing preferences",
            "💾 **Settings Export** - Backup and share your configuration",
            "🔄 **Auto-refresh** - Configurable data refresh rates",
            "📏 **Display Formatting** - Number and currency formatting"
        ]
        
        for feature in custom_features:
            st.markdown(feature)

def render_technical_details():
    """Render technical specifications"""
    st.subheader("🛠️ Technical Specifications")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Technology Stack:**")
        
        tech_stack = {
            "**Frontend Framework**": "Streamlit 1.28+",
            "**Data Processing**": "Pandas 2.0+",
            "**Visualization**": "Plotly 5.15+",
            "**Scientific Computing**": "NumPy 1.24+",
            "**Alternative Charts**": "Altair 5.0+",
            "**File Processing**": "OpenPyXL 3.1+"
        }
        
        for tech, version in tech_stack.items():
            st.markdown(f"• {tech}: {version}")
        
        st.write("\n**Supported File Formats:**")
        formats = ["CSV (.csv)", "Excel (.xlsx, .xls)", "JSON (export only)"]
        for fmt in formats:
            st.markdown(f"• {fmt}")
    
    with col2:
        st.write("**System Requirements:**")
        
        requirements = [
            "🐍 **Python:** 3.8 or higher",
            "💾 **RAM:** 4GB minimum (8GB recommended)",
            "💽 **Storage:** 100MB+ free space",
            "🌐 **Browser:** Modern web browser (Chrome, Firefox, Safari, Edge)",
            "📶 **Network:** Internet connection for initial setup"
        ]
        
        for req in requirements:
            st.markdown(req)
        
        st.write("\n**Performance Specifications:**")
        
        performance = [
            "📊 **Max File Size:** 200MB (configurable)",
            "📈 **Max Rows:** 100K+ rows supported", 
            "🔄 **Processing Speed:** ~1M rows/minute",
            "💾 **Memory Efficiency:** Chunked processing for large files",
            "⚡ **Caching:** Smart caching for improved performance"
        ]
        
        for perf in performance:
            st.markdown(perf)

def render_usage_guide():
    """Render quick usage guide"""
    st.subheader("📖 Quick Usage Guide")
    
    # Usage steps
    usage_steps = [
        {
            "title": "1️⃣ Getting Started",
            "content": [
                "Launch the application using `streamlit run src/app.py`",
                "Navigate using the sidebar menu",
                "Start with the Dashboard to see sample data",
                "Explore the sample visualizations and metrics"
            ]
        },
        {
            "title": "2️⃣ Uploading Your Data",
            "content": [
                "Go to the Data Upload page",
                "Select a CSV or Excel file (max 200MB)",
                "Preview and validate your data",
                "Apply any necessary transformations",
                "Your data will be available across all pages"
            ]
        },
        {
            "title": "3️⃣ Exploring Data",
            "content": [
                "Visit the Data Explorer page",
                "Use filters to narrow down your dataset",
                "Create custom visualizations with the chart builder",
                "Analyze correlations and detect outliers",
                "Export filtered data for further analysis"
            ]
        },
        {
            "title": "4️⃣ Customizing Experience",
            "content": [
                "Access Settings to personalize the dashboard",
                "Choose your preferred theme (light/dark)",
                "Configure default metrics and chart types",
                "Set up data processing preferences",
                "Export/import your settings for backup"
            ]
        }
    ]
    
    for step in usage_steps:
        with st.expander(step["title"], expanded=False):
            for item in step["content"]:
                st.markdown(f"• {item}")

def render_support_section():
    """Render support and resources section"""
    st.subheader("🆘 Support & Resources")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Getting Help:**")
        
        help_resources = [
            "📚 **Documentation** - Comprehensive user guide and API docs",
            "💡 **Tutorials** - Step-by-step video and text tutorials", 
            "❓ **FAQ** - Frequently asked questions and solutions",
            "🐛 **Bug Reports** - Report issues and get support",
            "💬 **Community** - Join the discussion forum",
            "📧 **Direct Support** - Contact the development team"
        ]
        
        for resource in help_resources:
            st.markdown(resource)
        
        st.write("\n**Useful Tips:**")
        
        tips = [
            "💡 Use the search function in data tables for quick filtering",
            "🎨 Dark theme is easier on the eyes for long analysis sessions",
            "📊 Export your charts as images for presentations",
            "💾 Regularly backup your settings configuration",
            "🔄 Use auto-refresh for real-time data monitoring"
        ]
        
        for tip in tips:
            st.markdown(tip)
    
    with col2:
        st.write("**Development Information:**")
        
        dev_info = [
            "🔓 **Open Source** - Built with open-source technologies",
            "🔐 **Privacy First** - No data leaves your environment", 
            "🚀 **Regular Updates** - Continuous improvement and new features",
            "🧪 **Tested** - Comprehensive testing for reliability",
            "📱 **Mobile Ready** - Responsive design for all devices",
            "♿ **Accessible** - Designed with accessibility in mind"
        ]
        
        for info in dev_info:
            st.markdown(info)
        
        st.write("\n**Version History:**")
        
        versions = [
            "**v1.0.0** - Initial release with core functionality",
            "**v0.9.0** - Beta release with advanced features",
            "**v0.8.0** - Alpha release with basic dashboard",
            "**v0.7.0** - Development preview"
        ]
        
        for version in versions:
            st.markdown(f"• {version}")
    
    # Acknowledgments
    st.markdown("---")
    st.subheader("🙏 Acknowledgments")
    
    acknowledgments = """
    This application is built with amazing open-source technologies:
    
    • **Streamlit** - For the incredible web app framework
    • **Plotly** - For powerful and interactive visualizations  
    • **Pandas** - For robust data manipulation capabilities
    • **NumPy** - For efficient numerical computing
    • **The Python Community** - For continuous innovation and support
    
    Special thanks to all contributors and users who help improve this application!
    """
    
    st.markdown(acknowledgments)
    
    # Footer
    st.markdown("---")
    st.markdown(
        "<p style='text-align: center; color: #666; font-style: italic;'>"
        f"Analytics Dashboard v{AppConfig().VERSION} - Built with ❤️ using Streamlit"
        "</p>", 
        unsafe_allow_html=True
    )