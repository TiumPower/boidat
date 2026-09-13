"""Chữ ký HMAC là hàng rào duy nhất của service — phải test kỹ."""

import hashlib
import hmac
import time

import pytest
from fastapi import HTTPException

from app.security import sign, verify_signature


class FakeRequest:
    def __init__(self, body: bytes):
        self._body = body

    async def body(self):
        return self._body


SECRET = "dev-face-secret"


def make_signature(body: bytes, timestamp: str) -> str:
    return hmac.new(SECRET.encode(), f"{timestamp}.".encode() + body, hashlib.sha256).hexdigest()


@pytest.mark.asyncio
async def test_chu_ky_dung_thi_qua():
    body = b'{"workspace_id":1}'
    ts = str(int(time.time()))
    await verify_signature(FakeRequest(body), x_timestamp=ts, x_signature=make_signature(body, ts))


@pytest.mark.asyncio
async def test_sua_body_thi_chu_ky_hong():
    ts = str(int(time.time()))
    signature = make_signature(b'{"workspace_id":1}', ts)
    with pytest.raises(HTTPException) as exc:
        await verify_signature(FakeRequest(b'{"workspace_id":2}'), x_timestamp=ts, x_signature=signature)
    assert exc.value.status_code == 401


@pytest.mark.asyncio
async def test_chu_ky_cu_bi_tu_choi():
    """Chống replay: request ký từ 10 phút trước không dùng lại được."""
    body = b"{}"
    ts = str(int(time.time()) - 600)
    with pytest.raises(HTTPException) as exc:
        await verify_signature(FakeRequest(body), x_timestamp=ts, x_signature=make_signature(body, ts))
    assert "hết hạn" in exc.value.detail


@pytest.mark.asyncio
async def test_thieu_header_thi_tu_choi():
    with pytest.raises(HTTPException):
        await verify_signature(FakeRequest(b"{}"), x_timestamp="", x_signature="")


def test_sign_khop_voi_cach_rails_ky():
    """Rails ký `"#{timestamp}.#{body}"` — hai bên phải ra cùng một chuỗi."""
    ts = "1700000000"
    body = b'{"a":1}'
    expected = hmac.new(SECRET.encode(), b"1700000000." + body, hashlib.sha256).hexdigest()
    assert sign(SECRET, ts, body) == expected
