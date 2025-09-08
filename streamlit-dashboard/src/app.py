"""
Comprehensive Streamlit Dashboard Application
Main entry point for the multi-page application
"""

import streamlit as st
import sys
import os
from pathlib import Path

# Add project root to path for imports
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

from utils.config import AppConfig
from utils.data_generator import DataGenerator
from utils.theme_manager import ThemeManager
from pages import dashboard, data_upload, data_explorer, settings, about

# Page configuration
st.set_page_config(
    page_title="Advanced Analytics Dashboard",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
    menu_items={
        'Get Help': 'https://docs.streamlit.io/',
        'Report a bug': None,
        'About': "Advanced Analytics Dashboard - Built with Streamlit"
    }
)

class StreamlitApp:
    """Main application class managing routing and session state"""
    
    def __init__(self):
        self.config = AppConfig()
        self.theme_manager = ThemeManager()
        self.data_generator = DataGenerator()
        self._initialize_session_state()
    
    def _initialize_session_state(self):
        """Initialize session state variables"""
        if 'initialized' not in st.session_state:
            st.session_state.initialized = True
            st.session_state.current_page = "Dashboard"
            st.session_state.theme = "light"
            st.session_state.uploaded_data = None
            st.session_state.user_preferences = {}
            st.session_state.sample_data = self.data_generator.generate_sample_data()
    
    def render_sidebar(self):
        """Render the navigation sidebar"""
        with st.sidebar:
            st.title("📊 Analytics Hub")
            st.markdown("---")
            
            # Navigation menu
            pages = {
                "📈 Dashboard": "Dashboard",
                "📤 Data Upload": "Data Upload", 
                "🔍 Data Explorer": "Data Explorer",
                "⚙️ Settings": "Settings",
                "ℹ️ About": "About"
            }
            
            selected_page = st.radio(
                "Navigate to:",
                list(pages.keys()),
                key="page_selector"
            )
            
            st.session_state.current_page = pages[selected_page]
            
            st.markdown("---")
            
            # Theme toggle
            if st.button("🌓 Toggle Theme"):
                st.session_state.theme = "dark" if st.session_state.theme == "light" else "light"
                st.experimental_rerun()
            
            # Quick stats in sidebar
            st.markdown("### Quick Stats")
            if st.session_state.uploaded_data is not None:
                data = st.session_state.uploaded_data
                st.metric("Rows", len(data))
                st.metric("Columns", len(data.columns))
            else:
                st.info("Upload data to see statistics")
            
            # Help section
            with st.expander("💡 Quick Help"):
                st.markdown("""
                **Dashboard**: View key metrics and visualizations
                
                **Data Upload**: Import CSV/Excel files
                
                **Data Explorer**: Interactive data analysis
                
                **Settings**: Customize your experience
                
                **About**: Learn more about this application
                """)
    
    def render_main_content(self):
        """Render the main page content based on current selection"""
        # Apply theme
        self.theme_manager.apply_theme(st.session_state.theme)
        
        # Route to appropriate page
        if st.session_state.current_page == "Dashboard":
            dashboard.render_page(st.session_state.sample_data, st.session_state.uploaded_data)
        elif st.session_state.current_page == "Data Upload":
            data_upload.render_page()
        elif st.session_state.current_page == "Data Explorer":
            data_explorer.render_page(st.session_state.sample_data, st.session_state.uploaded_data)
        elif st.session_state.current_page == "Settings":
            settings.render_page()
        elif st.session_state.current_page == "About":
            about.render_page()
    
    def run(self):
        """Main application entry point"""
        try:
            self.render_sidebar()
            self.render_main_content()
            
            # Footer
            st.markdown("---")
            col1, col2, col3 = st.columns([1, 2, 1])
            with col2:
                st.markdown(
                    "<p style='text-align: center; color: #666;'>Built with ❤️ using Streamlit</p>", 
                    unsafe_allow_html=True
                )
                
        except Exception as e:
            st.error(f"Application error: {str(e)}")
            st.exception(e)

def main():
    """Application entry point"""
    app = StreamlitApp()
    app.run()

if __name__ == "__main__":
    main()