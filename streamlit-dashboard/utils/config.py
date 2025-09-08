"""
Application configuration management
Centralized settings and constants
"""

import os
from dataclasses import dataclass, field
from typing import Dict, List, Any
import json

@dataclass
class AppConfig:
    """Application configuration class"""
    
    # Application metadata
    APP_NAME: str = "Advanced Analytics Dashboard"
    VERSION: str = "1.0.0"
    AUTHOR: str = "Streamlit Dashboard Team"
    
    # File upload settings
    MAX_FILE_SIZE: int = 200  # MB
    SUPPORTED_FORMATS: List[str] = field(default_factory=lambda: ['.csv', '.xlsx', '.xls'])
    
    # Chart settings
    DEFAULT_COLOR_PALETTE: List[str] = field(default_factory=lambda: [
        '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
        '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'
    ])
    
    # Dashboard settings
    DEFAULT_METRICS: List[str] = field(default_factory=lambda: [
        'Total Sales', 'Revenue', 'Customers', 'Growth Rate'
    ])
    
    # Theme settings
    THEMES: Dict[str, Dict[str, str]] = field(default_factory=lambda: {
        'light': {
            'background_color': '#FFFFFF',
            'text_color': '#262730',
            'accent_color': '#FF6B6B'
        },
        'dark': {
            'background_color': '#0E1117',
            'text_color': '#FAFAFA', 
            'accent_color': '#FF6B6B'
        }
    })
    
    # Data processing settings
    DATE_FORMATS: List[str] = field(default_factory=lambda: [
        '%Y-%m-%d', '%d/%m/%Y', '%m/%d/%Y', '%Y-%m-%d %H:%M:%S'
    ])
    
    def __post_init__(self):
        """Initialize configuration after object creation"""
        self.config_file = self._get_config_file_path()
        self.load_user_settings()
    
    def _get_config_file_path(self) -> str:
        """Get path to user configuration file"""
        config_dir = os.path.expanduser("~/.streamlit_dashboard")
        os.makedirs(config_dir, exist_ok=True)
        return os.path.join(config_dir, "config.json")
    
    def load_user_settings(self) -> Dict[str, Any]:
        """Load user settings from file"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    return json.load(f)
        except Exception as e:
            print(f"Error loading config: {e}")
        return {}
    
    def save_user_settings(self, settings: Dict[str, Any]) -> bool:
        """Save user settings to file"""
        try:
            with open(self.config_file, 'w') as f:
                json.dump(settings, f, indent=2)
            return True
        except Exception as e:
            print(f"Error saving config: {e}")
            return False
    
    def get_theme_colors(self, theme: str) -> Dict[str, str]:
        """Get colors for specified theme"""
        return self.THEMES.get(theme, self.THEMES['light'])
    
    def validate_file_upload(self, file_name: str, file_size: int) -> tuple[bool, str]:
        """Validate uploaded file"""
        # Check file extension
        file_ext = os.path.splitext(file_name)[1].lower()
        if file_ext not in self.SUPPORTED_FORMATS:
            return False, f"Unsupported file format. Supported: {', '.join(self.SUPPORTED_FORMATS)}"
        
        # Check file size (convert MB to bytes)
        max_size_bytes = self.MAX_FILE_SIZE * 1024 * 1024
        if file_size > max_size_bytes:
            return False, f"File too large. Max size: {self.MAX_FILE_SIZE}MB"
        
        return True, "File validation passed"