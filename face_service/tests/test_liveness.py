"""Liveness thụ động: bắt được ảnh mờ / ảnh chụp lại màn hình ở mức cơ bản."""

import numpy as np

from app import liveness


def sharp_image():
    """Ảnh nhiễu ngẫu nhiên — độ nét cao, giống ảnh chụp thật."""
    rng = np.random.default_rng(42)
    return rng.integers(0, 255, (240, 240, 3), dtype=np.uint8)


def flat_image():
    """Ảnh phẳng lì — mô phỏng ảnh out nét hoặc che camera."""
    return np.full((240, 240, 3), 128, dtype=np.uint8)


def test_anh_net_thi_qua():
    result = liveness.check(sharp_image())
    assert result["passed"] is True
    assert result["blur"] > 0


def test_anh_phang_bi_chan():
    result = liveness.check(flat_image())
    assert result["passed"] is False
    assert "mờ" in result["reason"]


def test_active_challenge_can_it_nhat_hai_khung():
    v = np.ones(512, dtype=np.float32)
    assert liveness.challenge_passed([v]) is False


def test_anh_tinh_giơ_truoc_camera_bi_chan():
    """Hai khung hình giống hệt nhau = một tấm ảnh, không phải người thật."""
    v = np.ones(512, dtype=np.float32)
    assert liveness.challenge_passed([v, v.copy()]) is False


def test_nguoi_that_luon_lech_nhe_giua_cac_khung():
    rng = np.random.default_rng(7)
    base = rng.normal(size=512).astype(np.float32)
    moved = base + rng.normal(scale=0.01, size=512).astype(np.float32)
    assert liveness.challenge_passed([base, moved]) is True
