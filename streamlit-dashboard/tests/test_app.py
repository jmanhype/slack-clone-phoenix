"""
Basic tests for the Streamlit application
Tests core functionality and components
"""

import pytest
import pandas as pd
import numpy as np
import sys
from pathlib import Path

# Add project root to path for imports
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

from utils.config import AppConfig
from utils.data_generator import DataGenerator
from utils.theme_manager import ThemeManager

class TestAppConfig:
    """Test application configuration"""
    
    def test_config_initialization(self):
        """Test that config initializes correctly"""
        config = AppConfig()
        assert config.APP_NAME == "Advanced Analytics Dashboard"
        assert config.VERSION == "1.0.0"
        assert config.MAX_FILE_SIZE == 200
        assert len(config.SUPPORTED_FORMATS) > 0
        assert len(config.DEFAULT_COLOR_PALETTE) > 0
    
    def test_file_validation(self):
        """Test file upload validation"""
        config = AppConfig()
        
        # Valid CSV file
        is_valid, message = config.validate_file_upload("test.csv", 1024 * 1024)  # 1MB
        assert is_valid == True
        
        # Valid Excel file
        is_valid, message = config.validate_file_upload("test.xlsx", 1024 * 1024)
        assert is_valid == True
        
        # Invalid format
        is_valid, message = config.validate_file_upload("test.pdf", 1024 * 1024)
        assert is_valid == False
        assert "Unsupported file format" in message
        
        # File too large (300MB file with 200MB limit)
        large_size = 300 * 1024 * 1024
        is_valid, message = config.validate_file_upload("test.csv", large_size)
        assert is_valid == False
        assert "File too large" in message
    
    def test_theme_colors(self):
        """Test theme color configuration"""
        config = AppConfig()
        
        light_colors = config.get_theme_colors('light')
        assert 'background_color' in light_colors
        assert 'text_color' in light_colors
        assert 'accent_color' in light_colors
        
        dark_colors = config.get_theme_colors('dark')
        assert 'background_color' in dark_colors
        assert 'text_color' in dark_colors
        assert 'accent_color' in dark_colors
        
        # Test invalid theme defaults to light
        invalid_colors = config.get_theme_colors('invalid')
        assert invalid_colors == light_colors

class TestDataGenerator:
    """Test sample data generation"""
    
    def test_data_generator_initialization(self):
        """Test data generator initializes correctly"""
        generator = DataGenerator()
        assert len(generator.product_categories) > 0
        assert len(generator.customer_segments) > 0
        assert len(generator.regions) > 0
        assert len(generator.sales_channels) > 0
    
    def test_sample_data_generation(self):
        """Test sample data generation"""
        generator = DataGenerator()
        sample_data = generator.generate_sample_data(100)  # Small sample for testing
        
        # Check all datasets are generated
        assert 'sales_data' in sample_data
        assert 'customer_data' in sample_data
        assert 'product_data' in sample_data
        assert 'time_series' in sample_data
        
        # Check data types
        assert isinstance(sample_data['sales_data'], pd.DataFrame)
        assert isinstance(sample_data['customer_data'], pd.DataFrame)
        assert isinstance(sample_data['product_data'], pd.DataFrame)
        assert isinstance(sample_data['time_series'], pd.DataFrame)
    
    def test_sales_data_structure(self):
        """Test sales data structure and content"""
        generator = DataGenerator()
        sales_data = generator.generate_sales_data(50)
        
        # Check basic structure
        assert len(sales_data) == 50
        assert len(sales_data.columns) > 10  # Should have many columns
        
        # Check required columns exist
        required_columns = [
            'transaction_id', 'date', 'customer_id', 'product_category',
            'quantity', 'unit_price', 'total_amount', 'profit'
        ]
        for col in required_columns:
            assert col in sales_data.columns
        
        # Check data types
        assert sales_data['date'].dtype.name.startswith('datetime')
        assert sales_data['quantity'].dtype in ['int64', 'int32']
        assert sales_data['total_amount'].dtype in ['float64', 'float32']
        
        # Check data ranges
        assert sales_data['quantity'].min() >= 1
        assert sales_data['total_amount'].min() > 0
        assert sales_data['profit'].min() >= 0
    
    def test_customer_data_structure(self):
        """Test customer data structure"""
        generator = DataGenerator()
        customer_data = generator.generate_customer_data(30)
        
        # Check structure
        assert len(customer_data) == 30
        
        # Check required columns
        required_columns = [
            'customer_id', 'first_name', 'last_name', 'email',
            'age', 'region', 'total_orders', 'total_spent'
        ]
        for col in required_columns:
            assert col in customer_data.columns
        
        # Check data validity
        assert customer_data['age'].min() >= 18
        assert customer_data['age'].max() <= 80
        assert customer_data['total_spent'].min() > 0
        assert customer_data['total_orders'].min() >= 1
    
    def test_time_series_data(self):
        """Test time series data generation"""
        generator = DataGenerator()
        time_series = generator.generate_time_series_data(30)  # 30 days
        
        # Check structure
        assert len(time_series) == 31  # 30 days + today
        
        # Check required columns
        required_columns = ['date', 'sales', 'profit', 'profit_margin']
        for col in required_columns:
            assert col in time_series.columns
        
        # Check data types
        assert time_series['date'].dtype.name.startswith('datetime')
        assert time_series['sales'].dtype in ['float64', 'float32']
        
        # Check data validity
        assert time_series['sales'].min() > 0  # Sales should be positive
        assert time_series['profit_margin'].min() >= 0  # Profit margin should be non-negative

class TestThemeManager:
    """Test theme management functionality"""
    
    def test_theme_manager_initialization(self):
        """Test theme manager initializes correctly"""
        theme_manager = ThemeManager()
        assert 'light' in theme_manager.themes
        assert 'dark' in theme_manager.themes
        
        # Check theme structure
        for theme_name, theme in theme_manager.themes.items():
            assert 'primary_color' in theme
            assert 'background_color' in theme
            assert 'text_color' in theme
    
    def test_metric_card_creation(self):
        """Test metric card HTML generation"""
        theme_manager = ThemeManager()
        
        card_html = theme_manager.create_metric_card("Revenue", "$10,000", "↗️ +15%", "positive")
        
        # Check HTML contains expected elements
        assert "metric-card" in card_html
        assert "Revenue" in card_html
        assert "$10,000" in card_html
        assert "↗️ +15%" in card_html
        assert "positive" in card_html
    
    def test_status_indicator_creation(self):
        """Test status indicator creation"""
        theme_manager = ThemeManager()
        
        indicator_html = theme_manager.create_status_indicator("success", "All systems operational")
        
        assert "status-indicator" in indicator_html
        assert "status-success" in indicator_html
        assert "All systems operational" in indicator_html
    
    def test_chart_theme_configuration(self):
        """Test chart theme configuration"""
        theme_manager = ThemeManager()
        
        light_theme = theme_manager.get_chart_theme('light')
        dark_theme = theme_manager.get_chart_theme('dark')
        
        # Check required keys exist
        required_keys = ['background_color', 'text_color', 'paper_bgcolor', 'plot_bgcolor']
        for key in required_keys:
            assert key in light_theme
            assert key in dark_theme
        
        # Check themes are different
        assert light_theme['background_color'] != dark_theme['background_color']

class TestDataProcessing:
    """Test data processing utilities"""
    
    def test_pandas_operations(self):
        """Test basic pandas operations work correctly"""
        # Create test data
        data = {
            'A': [1, 2, 3, 4, 5],
            'B': ['a', 'b', 'c', 'd', 'e'],
            'C': [1.1, 2.2, 3.3, 4.4, 5.5]
        }
        df = pd.DataFrame(data)
        
        # Test basic operations
        assert len(df) == 5
        assert list(df.columns) == ['A', 'B', 'C']
        assert df['A'].sum() == 15
        assert df['C'].mean() == 3.3
    
    def test_numpy_operations(self):
        """Test basic numpy operations work correctly"""
        arr = np.array([1, 2, 3, 4, 5])
        
        assert arr.sum() == 15
        assert arr.mean() == 3.0
        assert arr.std() > 0

# Integration test for basic functionality
class TestIntegration:
    """Integration tests for combined functionality"""
    
    def test_full_data_pipeline(self):
        """Test complete data generation and processing pipeline"""
        # Generate data
        generator = DataGenerator()
        sample_data = generator.generate_sample_data(100)
        
        # Process sales data
        sales_data = sample_data['sales_data']
        
        # Test basic analytics operations
        total_revenue = sales_data['total_amount'].sum()
        avg_order_value = sales_data['total_amount'].mean()
        
        assert total_revenue > 0
        assert avg_order_value > 0
        
        # Test grouping operations
        category_revenue = sales_data.groupby('product_category')['total_amount'].sum()
        assert len(category_revenue) > 0
        
        # Test filtering operations
        high_value_orders = sales_data[sales_data['total_amount'] > avg_order_value]
        assert len(high_value_orders) >= 0  # Could be empty, that's valid
    
    def test_theme_and_config_integration(self):
        """Test theme manager and config work together"""
        config = AppConfig()
        theme_manager = ThemeManager()
        
        # Test theme colors from config
        light_colors = config.get_theme_colors('light')
        chart_theme = theme_manager.get_chart_theme('light')
        
        # Both should provide color information
        assert len(light_colors) > 0
        assert len(chart_theme) > 0

if __name__ == "__main__":
    # Run tests if script is executed directly
    pytest.main([__file__, "-v"])