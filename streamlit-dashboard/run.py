#!/usr/bin/env python3
"""
Application launcher script
Simplified entry point for the Streamlit dashboard
"""

import os
import sys
import subprocess
from pathlib import Path

def main():
    """Launch the Streamlit application"""
    
    # Get the directory where this script is located
    script_dir = Path(__file__).parent
    app_path = script_dir / "src" / "app.py"
    
    # Change to the project directory
    os.chdir(script_dir)
    
    # Check if the app file exists
    if not app_path.exists():
        print("❌ Error: app.py not found!")
        print(f"Expected location: {app_path}")
        return 1
    
    # Check if Streamlit is installed
    try:
        import streamlit
        print(f"✅ Streamlit {streamlit.__version__} found")
    except ImportError:
        print("❌ Error: Streamlit not installed!")
        print("Please run: pip install -r requirements.txt")
        return 1
    
    # Print startup information
    print("🚀 Starting Analytics Dashboard...")
    print(f"📁 Project directory: {script_dir}")
    print(f"📊 App file: {app_path}")
    print("🌐 The app will open in your default browser")
    print("⏹️  Press Ctrl+C to stop the server")
    print("-" * 50)
    
    # Launch Streamlit
    try:
        cmd = [
            sys.executable, "-m", "streamlit", "run", str(app_path),
            "--server.headless", "false",
            "--server.enableCORS", "false",
            "--server.enableXsrfProtection", "false"
        ]
        
        subprocess.run(cmd, check=True)
        
    except KeyboardInterrupt:
        print("\n👋 Dashboard stopped by user")
        return 0
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Error starting Streamlit: {e}")
        return 1
        
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())