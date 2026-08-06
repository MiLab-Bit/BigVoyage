"""
Pollinations 图像生成客户端（零门槛，无需 API Key）。

官方图像接口：https://image.pollinations.ai/prompt/{prompt}
- 支持 GET（query 参数）与 POST（prompt 放路径 + JSON body）
- 返回原始图片字节（JPEG/PNG），无鉴权
- 模型可选：flux(默认,高质量) / turbo(快) / flux-realism / flux-anime / flux-3d / any-dark 等

本模块主用 POST（prompt 放路径 + JSON body），带重试以应对代理偶发断连。
"""
import os
import time
import base64
import requests

BASE_URL = "https://image.pollinations.ai/prompt"

# 常用免费模型（无需 key）。flux 质量最好，turbo 最快。
DEFAULT_MODEL = "flux"
KNOWN_MODELS = [
    "flux", "turbo", "flux-realism", "flux-anime", "flux-3d",
    "any-dark", "flux-pro", "dreamshaper", "sdxl",
]

DEFAULT_WIDTH = 1024
DEFAULT_HEIGHT = 1024
MAX_DIM = 2048  # Pollinations 实际上限更高，这里设个稳妥上限


def _pick_ext(data: bytes) -> str:
    if data[:8].startswith(b"\x89PNG"):
        return "png"
    if data[:3] == b"\xff\xd8\xff":
        return "jpg"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    return "jpg"


class PollinationsClient:
    def __init__(self, out_dir: str = None, retries: int = 4, timeout: int = 240):
        self.out_dir = out_dir or os.path.join(os.path.dirname(__file__), "output")
        os.makedirs(self.out_dir, exist_ok=True)
        self.retries = retries
        self.timeout = timeout
        self.session = requests.Session()

    def _request(self, prompt: str, *, width, height, seed, model,
                 nologo, enhance, safe) -> bytes:
        enc = requests.utils.quote(prompt)
        body = {
            "model": model,
            "width": width,
            "height": height,
            "nologo": bool(nologo),
            "enhance": bool(enhance),
            "safe": bool(safe),
        }
        if seed is not None:
            body["seed"] = int(seed)
        url = f"{BASE_URL}/{enc}"
        last_err = None
        for attempt in range(1, self.retries + 1):
            try:
                r = self.session.post(url, json=body, timeout=self.timeout)
                if r.status_code == 200 and len(r.content) > 200:
                    return r.content
                last_err = f"HTTP {r.status_code} bytes={len(r.content)}"
            except Exception as e:  # 代理偶发断连，重试
                last_err = repr(e)
            time.sleep(min(2 ** attempt, 8))
        raise RuntimeError(f"Pollinations 生成失败（重试 {self.retries} 次）: {last_err}")

    def generate(self, prompt: str, *, width: int = DEFAULT_WIDTH,
                 height: int = DEFAULT_HEIGHT, seed: int = None,
                 model: str = DEFAULT_MODEL, nologo: bool = True,
                 enhance: bool = False, safe: bool = False,
                 filename: str = None, return_base64: bool = False):
        width = max(64, min(int(width), MAX_DIM))
        height = max(64, min(int(height), MAX_DIM))
        data = self._request(prompt, width=width, height=height, seed=seed,
                             model=model, nologo=nologo, enhance=enhance, safe=safe)
        ext = _pick_ext(data)
        used_seed = seed if seed is not None else -1
        out_path = None
        if filename:
            fname = filename if filename.endswith(f".{ext}") else f"{filename}.{ext}"
            out_path = os.path.join(self.out_dir, fname)
            with open(out_path, "wb") as f:
                f.write(data)
        b64 = base64.b64encode(data).decode("ascii") if return_base64 else None
        return {
            "ok": True,
            "file": out_path,
            "format": ext,
            "model": model,
            "seed": used_seed,
            "width": width,
            "height": height,
            "bytes": len(data),
            "base64": b64,
        }


def quick(prompt: str, out_path: str = None, **kw):
    """一行生成：quick('a cat') -> 保存并返回 {file, ...}"""
    c = PollinationsClient()
    if out_path:
        fname = os.path.basename(out_path)
        d = os.path.dirname(out_path)
        if d:
            c.out_dir = d
        return c.generate(prompt, filename=fname, **kw)
    return c.generate(prompt, **kw)


if __name__ == "__main__":
    r = quick("a red cat on a blue chair, studio light", filename="test.jpg",
              width=512, height=512, seed=7)
    print(r)
