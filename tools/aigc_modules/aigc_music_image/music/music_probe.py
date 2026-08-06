"""
music_probe.py — 探测 acemusic.ai (ACE-Step) API 的真实接口与返回格式。
步骤：
  1) GET /health
  2) GET /v1/models
  3) POST /v1/chat/completions 最小生成（纯器乐、短时长）并解析返回
仅用于部署前验证，验证后删除或保留均可。
"""
import os
import sys
import json
import base64
import requests

# 从 .env 读取配置（和正式客户端一致）
env_path = os.path.join(os.path.dirname(__file__), ".env")
if os.path.exists(env_path):
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip())

BASE = os.environ.get("ACEMUSIC_BASE_URL", "https://api.acemusic.ai").rstrip("/")
KEY = os.environ.get("ACEMUSIC_API_KEY", "")
MODEL = os.environ.get("ACEMUSIC_MODEL", "acemusic/acestep-v1.5-turbo")

HEADERS = {"Content-Type": "application/json"}
if KEY:
    HEADERS["Authorization"] = f"Bearer {KEY}"

print(f"[probe] base={BASE}  model={MODEL}  key_present={bool(KEY)}")


def short(s, n=200):
    s = str(s)
    return s if len(s) <= n else s[:n] + " ...(truncated)"


# 1) health
try:
    r = requests.get(f"{BASE}/health", headers=HEADERS, timeout=30)
    print(f"[1] GET /health -> {r.status_code}")
    print("    ", short(r.text))
except Exception as e:
    print(f"[1] GET /health ERROR: {e}")

# 2) models
try:
    r = requests.get(f"{BASE}/v1/models", headers=HEADERS, timeout=30)
    print(f"[2] GET /v1/models -> {r.status_code}")
    try:
        j = r.json()
        ids = [m.get("id") for m in j.get("data", [])] if isinstance(j, dict) else j
        print("    model ids:", ids)
    except Exception:
        print("    ", short(r.text))
except Exception as e:
    print(f"[2] GET /v1/models ERROR: {e}")

# 3) minimal generation
payload = {
    "model": MODEL,
    "messages": [
        {"role": "user", "content": "[musical_prompt]\nLo-fi chill hop, warm piano, rain ambience\n[lyrics]\n"}
    ],
    "stream": False,
    "instrumental": True,
    "duration": 20,
    "vocal_language": "en",
}
print("[3] POST /v1/chat/completions (instrumental, 20s)")
try:
    r = requests.post(f"{BASE}/v1/chat/completions", headers=HEADERS, json=payload, timeout=180)
    print(f"    status={r.status_code}")
    try:
        j = r.json()
        # 只打印结构，避免巨大 base64 刷屏
        def summarize(obj, depth=0):
            if isinstance(obj, dict):
                for k, v in obj.items():
                    if isinstance(v, (dict, list)):
                        print("    " * (depth + 1) + f"{k}: <{type(v).__name__} len={len(v)}>")
                        if depth < 2:
                            summarize(v, depth + 1)
                    elif isinstance(v, str) and len(v) > 80:
                        print("    " * (depth + 1) + f"{k}: <str len={len(v)}> " + v[:40] + "...")
                    else:
                        print("    " * (depth + 1) + f"{k}: {v}")
        summarize(j)
        # 尝试提取音频并保存
        audio = None
        if isinstance(j, dict):
            # OpenAI 风格：choices[0].message.content 可能含 base64 或 URL
            msg = j.get("choices", [{}])[0].get("message", {})
            content = msg.get("content")
            if isinstance(content, str):
                if content.startswith("data:audio") or "base64" in content:
                    # 提取 base64
                    if "base64," in content:
                        audio = content.split("base64,", 1)[1]
                elif content.startswith("http"):
                    print("    audio_url:", content[:120])
            # 也可能顶层有 audio 字段
            if not audio and j.get("audio"):
                audio = j["audio"]
        if audio:
            try:
                data = base64.b64decode(audio)
                out = os.path.join(os.path.dirname(__file__), "probe_sample.mp3")
                with open(out, "wb") as f:
                    f.write(data)
                print(f"    [OK] saved audio -> {out} ({len(data)} bytes)")
            except Exception as e:
                print("    [warn] base64 decode failed:", e)
    except Exception as e:
        print("    [warn] json parse failed:", e)
        print("    ", short(r.text, 400))
except Exception as e:
    print(f"[3] POST ERROR: {e}")
