#!/usr/bin/env python3
"""
Demo script to verify all components work correctly
Tests core functionality without launching the full Streamlit app
"""

import sys
import os
from pathlib import Path

# Add project root to path for imports
project_root = Path(__file__).parent
sys.path.append(str(project_root))

def test_imports():
    """Test all critical imports"""
    print("🔍 Testing imports...")
    
    try:
        from utils.config import AppConfig
        from utils.data_generator import DataGenerator  
        from utils.theme_manager import ThemeManager
        print("✅ All utility imports successful")
        return True
    except ImportError as e:
        print(f"❌ Import failed: {e}")
        return False

def test_data_generation():
    """Test sample data generation"""
    print("📊 Testing data generation...")
    
    try:
        from utils.data_generator import DataGenerator
        
        generator = DataGenerator()
        sample_data = generator.generate_sample_data(50)
        
        # Verify all datasets created
        required_datasets = ['sales_data', 'customer_data', 'product_data', 'time_series']
        for dataset in required_datasets:
            if dataset not in sample_data:
                print(f"❌ Missing dataset: {dataset}")
                return False
            if len(sample_data[dataset]) == 0:
                print(f"❌ Empty dataset: {dataset}")
                return False
        
        print(f"✅ Generated {len(sample_data['sales_data'])} sales records")
        print(f"✅ Generated {len(sample_data['customer_data'])} customer records") 
        print(f"✅ Generated {len(sample_data['product_data'])} product records")
        print(f"✅ Generated {len(sample_data['time_series'])} time series points")
        
        return True
        
    except Exception as e:
        print(f"❌ Data generation failed: {e}")
        return False

def test_configuration():
    """Test configuration management"""
    print("⚙️ Testing configuration...")
    
    try:
        from utils.config import AppConfig
        
        config = AppConfig()
        
        # Test basic properties
        assert config.APP_NAME == "Advanced Analytics Dashboard"
        assert config.VERSION == "1.0.0"
        assert len(config.SUPPORTED_FORMATS) > 0
        assert config.MAX_FILE_SIZE == 200
        
        # Test file validation
        is_valid, message = config.validate_file_upload("test.csv", 1024*1024)
        assert is_valid == True
        
        is_valid, message = config.validate_file_upload("test.pdf", 1024*1024)
        assert is_valid == False
        
        # Test theme colors
        light_colors = config.get_theme_colors('light')
        dark_colors = config.get_theme_colors('dark')
        
        assert 'background_color' in light_colors
        assert 'background_color' in dark_colors
        assert light_colors != dark_colors
        
        print("✅ Configuration validation passed")
        return True
        
    except Exception as e:
        print(f"❌ Configuration test failed: {e}")
        return False

def test_theme_management():
    """Test theme management"""
    print("🎨 Testing theme management...")
    
    try:
        from utils.theme_manager import ThemeManager
        
        theme_manager = ThemeManager()
        
        # Test metric card creation
        card_html = theme_manager.create_metric_card("Test Metric", "$1,000", "+10%", "positive")
        assert "metric-card" in card_html
        assert "Test Metric" in card_html
        assert "$1,000" in card_html
        
        # Test status indicator
        status_html = theme_manager.create_status_indicator("success", "All good")
        assert "status-indicator" in status_html
        assert "status-success" in status_html
        
        # Test chart theme
        chart_theme = theme_manager.get_chart_theme('light')
        required_keys = ['background_color', 'text_color', 'paper_bgcolor']
        for key in required_keys:
            assert key in chart_theme
        
        print("✅ Theme management validation passed")
        return True
        
    except Exception as e:
        print(f"❌ Theme management test failed: {e}")
        return False

def test_page_imports():
    """Test page module imports"""
    print("📄 Testing page imports...")
    
    try:
        # Test page imports
        from pages import dashboard, data_upload, data_explorer, settings, about
        
        # Verify render_page functions exist
        pages_to_test = [
            (dashboard, 'dashboard'),
            (data_upload, 'data_upload'), 
            (data_explorer, 'data_explorer'),
            (settings, 'settings'),
            (about, 'about')
        ]
        
        for page_module, page_name in pages_to_test:
            if not hasattr(page_module, 'render_page'):
                print(f"❌ {page_name} missing render_page function")
                return False
        
        print("✅ All page modules imported successfully")
        return True
        
    except Exception as e:
        print(f"❌ Page import test failed: {e}")
        return False

def display_summary(config, sample_data):
    """Display application summary"""
    print("\n" + "="*60)
    print("📊 ADVANCED ANALYTICS DASHBOARD - SETUP COMPLETE")
    print("="*60)
    
    print(f"🏷️  Application: {config.APP_NAME}")
    print(f"📋 Version: {config.VERSION}")
    print(f"👨‍💻 Author: {config.AUTHOR}")
    print()
    
    print("📊 Sample Data Overview:")
    print(f"   • Sales Data: {len(sample_data['sales_data']):,} transactions")
    print(f"   • Customer Data: {len(sample_data['customer_data']):,} customers")
    print(f"   • Product Data: {len(sample_data['product_data']):,} products")
    print(f"   • Time Series: {len(sample_data['time_series']):,} data points")
    print()
    
    print("🚀 How to Run:")
    print(f"   • Command Line: python run.py")
    print(f"   • Shell Script: ./start_dashboard.sh")
    print(f"   • Direct: streamlit run src/app.py")
    print()
    
    print("🌐 Application Features:")
    print("   ✅ Interactive Dashboard with KPIs")
    print("   ✅ CSV/Excel Data Upload (up to 200MB)")
    print("   ✅ Advanced Data Explorer with Filtering")
    print("   ✅ Custom Chart Builder")
    print("   ✅ Statistical Analysis Tools")
    print("   ✅ Light/Dark Theme Support")
    print("   ✅ Customizable Settings")
    print("   ✅ Responsive Design")
    print()
    
    print("📁 Project Structure:")
    print("   • src/app.py - Main application")
    print("   • pages/ - Individual page modules")  
    print("   • utils/ - Core utilities")
    print("   • tests/ - Test suite")
    print("   • .streamlit/ - Streamlit configuration")
    print()
    
    print("🎯 Next Steps:")
    print("   1. Run the application: python run.py")
    print("   2. Open http://localhost:8501 in your browser")
    print("   3. Upload your own data or explore sample data")
    print("   4. Customize themes and settings")
    print("   5. Create custom visualizations")
    print()
    
    print("="*60)

def main():
    """Main demo function"""
    print("🚀 ADVANCED ANALYTICS DASHBOARD - SETUP VERIFICATION")
    print("="*60)
    
    # Run all tests
    tests = [
        test_imports,
        test_configuration,
        test_theme_management, 
        test_data_generation,
        test_page_imports
    ]
    
    passed_tests = 0
    total_tests = len(tests)
    
    for test_func in tests:
        try:
            if test_func():
                passed_tests += 1
            print()
        except Exception as e:
            print(f"❌ Test {test_func.__name__} failed with exception: {e}")
            print()
    
    # Show results
    print(f"📊 Test Results: {passed_tests}/{total_tests} tests passed")
    
    if passed_tests == total_tests:
        print("🎉 ALL TESTS PASSED! Application is ready to run.")
        
        # Generate final summary
        from utils.config import AppConfig
        from utils.data_generator import DataGenerator
        
        config = AppConfig()
        generator = DataGenerator()
        sample_data = generator.generate_sample_data(100)
        
        display_summary(config, sample_data)
        
        return 0
    else:
        print("❌ Some tests failed. Please check the errors above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())