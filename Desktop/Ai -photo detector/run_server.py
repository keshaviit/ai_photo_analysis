import uvicorn
import os
import sys
import time

class DummyStdin:
    def read(self, *args, **kwargs):
        while True:
            time.sleep(3600)
    def readline(self, *args, **kwargs):
        while True:
            time.sleep(3600)
    def isatty(self):
        return False

if __name__ == "__main__":
    # Override stdin with dummy blocker to survive standard input closure
    sys.stdin = DummyStdin()
    
    # Ensure correct working directory
    sys.path.append(os.path.dirname(os.path.abspath(__file__)))
    
    uvicorn.run("app.main:app", host="127.0.0.1", port=8000, log_level="info")
