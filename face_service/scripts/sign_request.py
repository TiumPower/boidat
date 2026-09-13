#!/usr/bin/env python3
"""Ký thử một request để gọi service bằng curl khi debug.

    python scripts/sign_request.py '{"workspace_id":1,"top_k":3,"image":"..."}'
"""

import hashlib
import hmac
import os
import sys
import time

secret = os.environ.get("FACE_SERVICE_SECRET", "dev-face-secret")
body = (sys.argv[1] if len(sys.argv) > 1 else "").encode()
timestamp = str(int(time.time()))
signature = hmac.new(secret.encode(), f"{timestamp}.".encode() + body, hashlib.sha256).hexdigest()

print(f"X-Timestamp: {timestamp}")
print(f"X-Signature: {signature}")
