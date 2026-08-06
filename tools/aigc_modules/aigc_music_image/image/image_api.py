"""
Pollinations 图像生成 —— 独立 FastAPI 服务（零 Key，云端生成）。
启动：venv/Scripts/python.exe -m uvicorn image_api:app --host 127.0.0.1 --port 8003
"""
import os
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from pollinations_client import PollinationsClient, KNOWN_MODELS

HERE = os.path.dirname(os.path.abspath(__file__))
client = PollinationsClient(out_dir=os.path.join(HERE, "output"))

app = FastAPI(title="Pollinations Image API", version="1.0")


class ImageRequest(BaseModel):
    prompt: str
    width: int = 1024
    height: int = 1024
    seed: int = None
    model: str = "flux"
    nologo: bool = True
    enhance: bool = False
    safe: bool = False
    filename: str = None
    return_base64: bool = False


@app.get("/health")
def health():
    return {"ok": True, "service": "pollinations-image", "models": KNOWN_MODELS}


@app.post("/image")
def image_gen(req: ImageRequest):
    try:
        res = client.generate(
            req.prompt, width=req.width, height=req.height, seed=req.seed,
            model=req.model, nologo=req.nologo, enhance=req.enhance,
            safe=req.safe, filename=req.filename,
            return_base64=req.return_base64,
        )
        if res.get("file"):
            res["url"] = f"/files/{os.path.basename(res['file'])}"
        return res
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))


@app.get("/files/{name}")
def get_file(name: str):
    p = os.path.join(client.out_dir, os.path.basename(name))
    if not os.path.exists(p):
        raise HTTPException(status_code=404, detail="not found")
    return FileResponse(p)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8003)
