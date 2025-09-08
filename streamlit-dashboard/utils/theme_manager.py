"""
Theme management for consistent UI styling
Handles light/dark themes and custom CSS injection
"""

import streamlit as st
from typing import Dict, Any

class ThemeManager:
    """Manages application themes and styling"""
    
    def __init__(self):
        """Initialize theme manager"""
        self.themes = {
            'light': {
                'primary_color': '#FF6B6B',
                'background_color': '#FFFFFF',
                'secondary_background_color': '#F0F2F6',
                'text_color': '#262730',
                'accent_color': '#FF4B4B',
                'sidebar_background': '#F0F2F6'
            },
            'dark': {
                'primary_color': '#FF6B6B',
                'background_color': '#0E1117',
                'secondary_background_color': '#262730',
                'text_color': '#FAFAFA',
                'accent_color': '#FF4B4B',
                'sidebar_background': '#262730'
            }
        }
    
    def apply_theme(self, theme_name: str = 'light'):
        """Apply selected theme to the application"""
        theme = self.themes.get(theme_name, self.themes['light'])
        
        # Custom CSS for theme styling
        css = f"""
        <style>
        /* Main container styling */
        .main {{
            background-color: {theme['background_color']};
            color: {theme['text_color']};
        }}
        
        /* Sidebar styling */
        .css-1d391kg {{
            background-color: {theme['sidebar_background']};
        }}
        
        /* Metric cards styling */
        .css-1xarl3l {{
            background-color: {theme['secondary_background_color']};
            border: 1px solid {theme['accent_color']}40;
            border-radius: 10px;
            padding: 1rem;
        }}
        
        /* Custom metric card */
        .metric-card {{
            background-color: {theme['secondary_background_color']};
            padding: 1.5rem;
            border-radius: 10px;
            border: 1px solid {theme['accent_color']}40;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            text-align: center;
            margin: 0.5rem 0;
        }}
        
        .metric-value {{
            font-size: 2rem;
            font-weight: bold;
            color: {theme['accent_color']};
            margin: 0;
        }}
        
        .metric-label {{
            font-size: 0.9rem;
            color: {theme['text_color']};
            opacity: 0.8;
            margin: 0;
        }}
        
        .metric-delta {{
            font-size: 0.8rem;
            margin-top: 0.5rem;
        }}
        
        .metric-delta.positive {{
            color: #00C851;
        }}
        
        .metric-delta.negative {{
            color: #FF4444;
        }}
        
        /* Headers */
        h1, h2, h3 {{
            color: {theme['text_color']};
        }}
        
        /* Cards and containers */
        .stContainer > div {{
            background-color: {theme['secondary_background_color']};
            border-radius: 10px;
            padding: 1rem;
        }}
        
        /* Buttons */
        .stButton > button {{
            background-color: {theme['accent_color']};
            color: white;
            border: none;
            border-radius: 5px;
            transition: all 0.3s ease;
        }}
        
        .stButton > button:hover {{
            background-color: {theme['accent_color']}CC;
            transform: translateY(-2px);
        }}
        
        /* Selectbox and inputs */
        .stSelectbox > div > div {{
            background-color: {theme['secondary_background_color']};
            color: {theme['text_color']};
        }}
        
        .stTextInput > div > div > input {{
            background-color: {theme['secondary_background_color']};
            color: {theme['text_color']};
        }}
        
        /* Plotly chart container */
        .js-plotly-plot {{
            background-color: {theme['background_color']} !important;
        }}
        
        /* Status indicators */
        .status-indicator {{
            display: inline-block;
            width: 10px;
            height: 10px;
            border-radius: 50%;
            margin-right: 8px;
        }}
        
        .status-success {{
            background-color: #00C851;
        }}
        
        .status-warning {{
            background-color: #FF8800;
        }}
        
        .status-error {{
            background-color: #FF4444;
        }}
        
        /* Data table styling */
        .dataframe {{
            background-color: {theme['secondary_background_color']};
            color: {theme['text_color']};
        }}
        
        /* Sidebar navigation */
        .nav-item {{
            padding: 0.5rem 1rem;
            margin: 0.25rem 0;
            border-radius: 5px;
            cursor: pointer;
            transition: background-color 0.3s ease;
        }}
        
        .nav-item:hover {{
            background-color: {theme['accent_color']}20;
        }}
        
        .nav-item.active {{
            background-color: {theme['accent_color']};
            color: white;
        }}
        
        /* Loading spinner */
        .stSpinner {{
            color: {theme['accent_color']};
        }}
        
        /* Alert messages */
        .alert {{
            padding: 1rem;
            border-radius: 5px;
            margin: 1rem 0;
        }}
        
        .alert-success {{
            background-color: #00C85120;
            border-left: 4px solid #00C851;
            color: #00C851;
        }}
        
        .alert-warning {{
            background-color: #FF880020;
            border-left: 4px solid #FF8800;
            color: #FF8800;
        }}
        
        .alert-error {{
            background-color: #FF444420;
            border-left: 4px solid #FF4444;
            color: #FF4444;
        }}
        
        .alert-info {{
            background-color: {theme['accent_color']}20;
            border-left: 4px solid {theme['accent_color']};
            color: {theme['accent_color']};
        }}
        </style>
        """
        
        st.markdown(css, unsafe_allow_html=True)
    
    def create_metric_card(self, title: str, value: str, delta: str = None, delta_color: str = "normal"):
        """Create a styled metric card"""
        delta_class = ""
        if delta and delta_color != "normal":
            delta_class = f"metric-delta {delta_color}"
        
        delta_html = ""
        if delta:
            delta_html = f'<p class="{delta_class}">{delta}</p>'
        
        card_html = f"""
        <div class="metric-card">
            <p class="metric-value">{value}</p>
            <p class="metric-label">{title}</p>
            {delta_html}
        </div>
        """
        
        return card_html
    
    def create_status_indicator(self, status: str, text: str = ""):
        """Create a status indicator with optional text"""
        status_class = f"status-{status}"
        return f'<span class="status-indicator {status_class}"></span>{text}'
    
    def create_alert(self, message: str, alert_type: str = "info"):
        """Create a styled alert message"""
        return f'<div class="alert alert-{alert_type}">{message}</div>'
    
    def get_chart_theme(self, theme_name: str = 'light') -> Dict[str, Any]:
        """Get chart styling configuration for the current theme"""
        theme = self.themes.get(theme_name, self.themes['light'])
        
        return {
            'background_color': theme['background_color'],
            'text_color': theme['text_color'],
            'grid_color': theme['text_color'] + '20',
            'paper_bgcolor': theme['background_color'],
            'plot_bgcolor': theme['background_color']
        }