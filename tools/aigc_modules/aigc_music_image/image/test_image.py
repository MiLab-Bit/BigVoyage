"""
冒烟测试：直接生成一张图 + 通过本地 API 生成一张图。
用法：venv/Scripts/python.exe test_image.py
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from pollinations_client import quick

PROMPT = "a futuristic city at night, neon lights, cinematic, highly detailed"


def test_direct():
    print("=== 直接生成（库调用）===")
    t0 = time.time()
    r = quick(PROMPT, filename="smoke_direct.jpg", width=768, height=768, seed=42)
    print("ok=", r["ok"], "file=", r["file"], "format=", r["format"],
          "bytes=", r["bytes"], "cost=%.1fs" % (time.time() - t0))
    assert r["ok"] and os.path.exists(r["file"])
    return r


def test_api():
    print("=== 通过 API 生成 ===")
    import requests
    base = "http://127.0.0.1:8003"
    h = requests.get(f"{base}/health", timeout=10)
    print("health:", h.status_code, h.json().get("service"))
    t0 = time.time()
    r = requests.post(f"{base}/image", json={
        "prompt": PROMPT, "width": 768, "height": 768, "seed": 7,
        "model": "flux", "filename": "smoke_api.jpg",
    }, timeout=240)
    print("status", r.status_code, "cost=%.1fs" % (time.time() - t0))
    j = r.json()
    print("file=", j.get("file"), "url=", j.get("url"))
    assert r.status_code == 200 and j.get("ok")


if __name__ == "__main__":
    test_direct()
    try:
        test_api()
    except Exception as e:
        print("[warn] API 测试跳过（服务可能未启动）:", e)
    print("\n完成。样例见", os.path.join(HERE, "output"))
