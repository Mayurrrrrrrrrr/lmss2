#!/bin/bash
# deploy_v2.sh
# Lightweight deployment script for Firefly LMS V2

echo "Deploying Firefly LMS V2 Backend..."

# 1. Update Dependencies via venv
echo "Setting up Python virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate

echo "Installing/Updating dependencies..."
pip install -r requirements.txt

# 2. Halt existing instances gracefully
echo "Stopping existing Uvicorn instances..."
pkill -f "uvicorn app.main:app" || true
sleep 1

# 3. Boot Uvicorn (Memory Restricted)
# CRITICAL: --workers 1 ensures we stay strictly under the 1GB RAM ceiling.
# We set log-level to warning to prevent I/O disk bloat in production.
echo "Starting Uvicorn..."
nohup venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 1 --log-level warning > uvicorn.log 2>&1 &

# 4. Basic Process Health Check
sleep 2
if pgrep -f "uvicorn app.main:app" > /dev/null
then
    echo "✅ Backend successfully started and is running on port 8000!"
else
    echo "❌ Failed to start the backend. Check uvicorn.log for details."
    exit 1
fi
