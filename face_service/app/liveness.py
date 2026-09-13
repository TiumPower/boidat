"""Liveness thụ động — chặn ảnh in và ảnh chụp màn hình ở mức cơ bản.

Nói thẳng về giới hạn: đây KHÔNG phải chống giả mạo cấp ngân hàng. Ba tín hiệu
dưới đây bắt được kiểu tấn công phổ biến nhất ở quầy (giơ điện thoại có ảnh
sẵn), nhưng không chống được mặt nạ 3D hay màn hình chất lượng cao. Muốn mạnh
hơn thì phải làm active challenge (nháy mắt / quay đầu) — PWA gửi nhiều khung
hình liên tiếp và service so độ lệch landmark; khung dữ liệu cho việc đó đã sẵn
ở hàm `challenge_passed`.
"""

import cv2
import numpy as np

from .config import get_settings


def blur_score(image) -> float:
    """Phương sai Laplacian: ảnh chụp lại từ màn hình thường mờ hơn ảnh thật."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


def moire_score(image) -> float:
    """Phát hiện vân moiré — dấu hiệu đặc trưng khi chụp lại một màn hình.

    Ảnh chụp màn hình có năng lượng tần số cao tập trung bất thường; ảnh chụp
    người thật thì phổ trải đều hơn.
    """
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (256, 256))
    spectrum = np.abs(np.fft.fftshift(np.fft.fft2(gray)))
    h, w = spectrum.shape
    centre = spectrum[h // 2 - 8 : h // 2 + 8, w // 2 - 8 : w // 2 + 8].sum()
    total = spectrum.sum() + 1e-6
    return float(1.0 - centre / total)


def check(image) -> dict:
    """Trả về {passed, blur, moire, reason} — không ném lỗi, để quầy luôn chạy."""
    settings = get_settings()
    if not settings.liveness_enabled:
        return {"passed": True, "blur": None, "moire": None, "reason": None}

    blur = blur_score(image)
    moire = moire_score(image)
    passed = blur >= settings.min_blur_score
    reason = None if passed else "Ảnh quá mờ hoặc là ảnh chụp lại màn hình"
    return {"passed": passed, "blur": round(blur, 2), "moire": round(moire, 4), "reason": reason}


def challenge_passed(vectors: list[np.ndarray], min_shift: float = 0.02) -> bool:
    """Active challenge: nhiều khung hình của cùng một người phải KHÁC nhau đôi chút.

    Một tấm ảnh giơ trước camera cho ra các khung gần như giống hệt; người thật
    thì luôn lệch nhẹ. Ngưỡng cố tình đặt thấp để không làm phiền trẻ em đứng yên.
    """
    if len(vectors) < 2:
        return False
    diffs = [float(np.linalg.norm(vectors[i] - vectors[i - 1])) for i in range(1, len(vectors))]
    return max(diffs) >= min_shift
