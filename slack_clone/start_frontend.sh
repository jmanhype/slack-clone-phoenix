#!/bin/bash

echo "🚀 Starting Slack Clone Frontend (Asset-only mode)"

# Set up environment
export MIX_ENV=dev
export PORT=4000

# Compile assets first
echo "📦 Building frontend assets..."
mix assets.build

echo "🔧 Setting up basic static file server on port 4000..."

# Start a simple file server for the static assets
cd priv/static
python3 -m http.server 4000 &
SERVER_PID=$!

echo "✅ Frontend assets server started on http://localhost:4000"
echo "📄 Serving static files from priv/static/"
echo "🔗 Main application available at http://localhost:4000/assets/"
echo ""
echo "🛑 To stop the server, run: kill $SERVER_PID"

# Store the PID for later cleanup
echo $SERVER_PID > /tmp/slack_frontend_server.pid

# Wait for server to start
sleep 2
echo "🌐 Opening browser..."
open http://localhost:4000 || echo "Please open http://localhost:4000 in your browser"

# Keep the script running
wait $SERVER_PID