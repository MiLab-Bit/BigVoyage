"""
music_client.py — acemusic.ai (ACE-Step) 音乐生成客户端

接口已实测确认：
  GET  {base}/health              -> 200 "health check"
  GET  {base}/v1/models           -> {"data":[{"id":"acemusic/acestep-v1.5-turbo", ...}]}
  POST {base}/v1/chat/completions -> OpenAI 风格：
        choices[0].message.audio[0].audio_url.url = "data:audio/mpeg;base64,...."

认证：Authorization: Bearer <API_KEY>
依赖：仅标准库 + requests
"""
import os
import time
import base64
import json
import requests

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load_env():
    env_path = os.path.join(_HERE, ".env")
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


_load_env()

DEFAULT_BASE = os.environ.get("ACEMUSIC_BASE_URL", "https://api.acemusic.ai").rstrip("/")
DEFAULT_KEY = os.environ.get("ACEMUSIC_API_KEY", "")
DEFAULT_MODEL = os.environ.get("ACEMUSIC_MODEL", "acemusic/acestep-v1.5-turbo")

# 代理偶尔 SSL/Proxy 抖动，做有限重试
_RETRYABLE = (requests.exceptions.ConnectionError, requests.exceptions.ProxyError,
              requests.exceptions.SSLError, requests.exceptions.Timeout)


class AceMusicError(Exception):
    pass


class AceMusicClient:
    def __init__(self, base_url=None, api_key=None, model=None, timeout=300):
        self.base = (base_url or DEFAULT_BASE).rstrip("/")
        self.key = api_key or DEFAULT_KEY
        self.model = model or DEFAULT_MODEL
        self.timeout = timeout
        if not self.key:
            raise AceMusicError("缺少 API Key：请在 music/.env 设置 ACEMUSIC_API_KEY")
        self.session = requests.Session()
        self.session.headers.update({
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.key}",
        })

    # ---- 基础探测 ----
    def health(self):
        for _ in range(3):
            try:
                r = self.session.get(f"{self.base}/health", timeout=20)
                return r.status_code, r.text
            except _RETRYABLE:
                time.sleep(2)
        raise AceMusicError("health 检查失败（代理/网络抖动）")

    def models(self):
        r = self.session.get(f"{self.base}/v1/models", timeout=30)
        r.raise_for_status()
        return r.json()

    # ---- 生成 ----
    def generate(self, prompt, lyrics="", *, duration=None, bpm=None,
                 vocal_language="en", instrumental=False, temperature=0.85,
                 top_p=0.9, seed=None, sample_mode=False, stream=False,
                 max_retries=3):
        """生成一段音乐。

        prompt: 音乐风格/场景描述（caption）
        lyrics: 歌词；instrumental=True 时忽略
        duration: 时长(秒)，None 由模型自定
        bpm: 每分钟节拍；None 自定
        vocal_language: "en"/"zh"/"ja"/"ko"...
        instrumental: 纯器乐
        sample_mode: True 时把 prompt 当自然语言，由模型自动拆 prompt/lyrics
        返回: {"audio": bytes, "format": "mp3", "text": str|None, "model": str, "usage": dict|None}
        """
        if sample_mode:
            content = prompt
        else:
            content = f"[musical_prompt]\n{prompt}\n"
            if lyrics:
                content += f"[lyrics]\n{lyrics}\n"
        payload = {
            "model": self.model,
            "messages": [{"role": "user", "content": content}],
            "stream": stream,
            "instrumental": instrumental,
            "vocal_language": vocal_language,
            "temperature": temperature,
            "top_p": top_p,
        }
        if duration is not None:
            payload["duration"] = duration
        if bpm is not None:
            payload["bpm"] = bpm
        if seed is not None:
            payload["seed"] = seed
        if sample_mode:
            payload["sample_mode"] = True

        last_err = None
        for attempt in range(1, max_retries + 1):
            try:
                r = self.session.post(f"{self.base}/v1/chat/completions",
                                      json=payload, timeout=self.timeout)
                if r.status_code != 200:
                    raise AceMusicError(f"HTTP {r.status_code}: {r.text[:300]}")
                return self._parse(r.json())
            except _RETRYABLE as e:
                last_err = e
                time.sleep(3 * attempt)
            except AceMusicError:
                raise
        raise AceMusicError(f"生成失败（重试 {max_retries} 次）: {last_err}")

    @staticmethod
    def _parse(j):
        audio = None
        fmt = "mp3"
        text = None
        try:
            msg = j["choices"][0]["message"]
            aud = msg.get("audio")
            if isinstance(aud, list) and aud:
                url = aud[0].get("audio_url", {}).get("url", "")
                if url.startswith("data:"):
                    if ";base64," in url:
                        b64 = url.split(";base64,", 1)[1]
                        audio = base64.b64decode(b64)
                    mime = url[5:].split(";")[0]
                    fmt = mime.split("/")[-1] if "/" in mime else "mp3"
            if isinstance(msg.get("content"), str) and msg["content"].strip():
                text = msg["content"]
        except (KeyError, IndexError, TypeError) as e:
            raise AceMusicError(f"无法解析返回结构: {e}\n原始: {json.dumps(j, ensure_ascii=False)[:500]}")
        if audio is None:
            raise AceMusicError(f"返回中不含音频数据: {json.dumps(j, ensure_ascii=False)[:500]}")
        return {
            "audio": audio,
            "format": fmt,
            "text": text,
            "model": j.get("model"),
            "usage": j.get("usage"),
        }

    @staticmethod
    def save(audio_bytes, path):
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        with open(path, "wb") as f:
            f.write(audio_bytes)
        return path


if __name__ == "__main__":
    c = AceMusicClient()
    print("health:", c.health())
    print("models:", [m["id"] for m in c.models().get("data", [])])
    res = c.generate("Lo-fi chill hop, warm piano, rain ambience",
                     duration=15, instrumental=True, vocal_language="en")
    p = c.save(res["audio"], os.path.join(_HERE, "output", "demo.mp3"))
    print(f"saved -> {p} ({len(res['audio'])} bytes), format={res['format']}")
