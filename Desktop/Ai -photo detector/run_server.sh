#!/bin/bash
while true; do
  echo "Starting Uvicorn server with native asyncio loop..."
  # Pipe an infinite sleep and use --loop asyncio to prevent uvloop + PyTorch conflicts on macOS
  sleep 99999999 | /Applications/anaconda3/bin/python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --loop asyncio
  echo "Server exited with code $?. Restarting in 2 seconds..."
  sleep 2
done
