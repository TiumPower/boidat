"""Xác thực request từ Rails bằng HMAC-SHA256.

Service chỉ bind 127.0.0.1 nên không lộ ra Internet, nhưng vẫn ký từng request:
một tiến trình khác trên cùng máy chủ (hoặc một container bị chiếm) không được
phép tra cứu khuôn mặt trẻ em chỉ vì nó gọi được localhost.
"""

import hashlib
import hmac
import time

from fastapi import Header, HTTPException, Request

from .config import get_settings


def sign(secret: str, timestamp: str, body: bytes) -> str:
    payload = f"{timestamp}.".encode() + body
    return hmac.new(secret.encode(), payload, hashlib.sha256).hexdigest()


async def verify_signature(
    request: Request,
    x_timestamp: str = Header(default=""),
    x_signature: str = Header(default=""),
) -> None:
    settings = get_settings()

    if not x_timestamp or not x_signature:
        raise HTTPException(status_code=401, detail="Thiếu chữ ký request")

    try:
        skew = abs(int(time.time()) - int(x_timestamp))
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Timestamp không hợp lệ") from exc

    # Chống replay: chữ ký cũ hơn ngưỡng cho phép thì từ chối.
    if skew > settings.signature_max_skew:
        raise HTTPException(status_code=401, detail="Chữ ký đã hết hạn")

    body = await request.body()
    expected = sign(settings.face_service_secret, x_timestamp, body)
    if not hmac.compare_digest(expected, x_signature):
        raise HTTPException(status_code=401, detail="Chữ ký không hợp lệ")
