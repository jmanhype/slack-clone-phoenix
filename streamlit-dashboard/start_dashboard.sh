#!/bin/bash

# Advanced Analytics Dashboard Launcher
# Simple script to start the Streamlit application

echo "🚀 Starting Advanced Analytics Dashboard..."
echo "📊 Launching Streamlit application..."

# Change to script directory
cd "$(dirname "$0")"

# Check if Python is available
if ! command -v python &> /dev/null; then
    echo "❌ Python not found. Please install Python 3.8 or higher."
    exit 1
fi

# Check if Streamlit is installed
if ! python -c "import streamlit" 2>/dev/null; then
    echo "❌ Streamlit not installed. Installing dependencies..."
    pip install -r requirements.txt
fi

# Start the application
echo "🌐 Opening dashboard in your default browser..."
echo "⏹️  Press Ctrl+C to stop the application"
echo "📁 Application running from: $(pwd)"
echo ""

# Launch Streamlit with the main app
streamlit run src/app.py \
    --server.headless false \
    --server.enableCORS false \
    --server.enableXsrfProtection false \
    --browser.gatherUsageStats false

echo ""
echo "👋 Dashboard stopped. Thank you for using Analytics Dashboard!"