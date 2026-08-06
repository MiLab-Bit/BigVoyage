"""
music_api.py — 独立 FastAPI 音乐生成服务（基于 acemusic.ai / ACE-Step）

运行：
  ../ComfyUIApp/venv/Scripts/python.exe -m uvicorn music_api:app --host 0.0.0.0 --port 8002
或：
  python music_api.py

端点：
  GET  /health       -> 转发 acemusic health
  GET  /models       -> 可用模型列表
  POST /music        -> 生成音乐，返回 base64 音频 + 元数据
  GET  /            -> 简单说明
"""
import os
import base64
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from music_client import AceMusicClient, AceMusicError

_HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(_HERE, "output")
os.makedirs(OUT, exist_ok=True)

app = FastAPI(title="AceMusic API", version="1.0")
client = AceMusicClient()


class MusicRequest(BaseModel):
    prompt: str
    lyrics: str = ""
    duration: Optional[int] = None
    bpm: Optional[int] = None
    vocal_language: str = "en"
    instrumental: bool = False
    temperature: float = 0.85
    top_p: float = 0.9
    seed: Optional[int] = None
    sample_mode: bool = False
    return_base64: bool = True      # true: 返回 base64；false: 落盘并返回文件路径
    filename: Optional[str] = None


@app.get("/")
def root():
    return {"service": "AceMusic (ACE-Step)", "docs": "/docs", "endpoints": ["/health", "/models", "/music"]}


@app.get("/health")
def health():
    try:
        code, text = client.health()
        return {"status_code": code, "detail": text}
    except AceMusicError as e:
        raise HTTPException(status_code=502, detail=str(e))


@app.get("/models")
def models():
    try:
        return client.models()
    except AceMusicError as e:
        raise HTTPException(status_code=502, detail=str(e))


@app.post("/music")
def music(req: MusicRequest):
    try:
        res = client.generate(
            req.prompt, req.lyrics,
            duration=req.duration, bpm=req.bpm,
            vocal_language=req.vocal_language, instrumental=req.instrumental,
            temperature=req.temperature, top_p=req.top_p, seed=req.seed,
            sample_mode=req.sample_mode,
        )
    except AceMusicError as e:
        raise HTTPException(status_code=502, detail=str(e))

    fmt = res["format"]
    if req.return_base64:
        return {
            "ok": True,
            "format": fmt,
            "audio_base64": base64.b64encode(res["audio"]).decode("ascii"),
            "text": res.get("text"),
            "model": res.get("model"),
            "usage": res.get("usage"),
        }
    else:
        name = req.filename or f"music_{abs(hash(req.prompt)) % 10**8}.{fmt}"
        path = client.save(res["audio"], os.path.join(OUT, name))
        return {
            "ok": True,
            "format": fmt,
            "file": path,
            "text": res.get("text"),
            "model": res.get("model"),
            "usage": res.get("usage"),
        }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
