# 给 Cursor 的交接说明：音乐 + 图像模块

> 用途：这两个模块是一个 AIGC 管线里的「音乐生成」与「图像生成」两条通道。
> 代码在 `aigc_music_image/`（压缩包解压后），可直接运行、直接集成。

---

## 一、总览

| 模块 | 目录 | 能力 | 后端 | Key |
|---|---|---|---|---|
| 音乐 | `music/` | 文字→音乐（器乐/带歌词），返回 MP3 | acemusic.ai / ACE-Step（云端） | 有（在 `.env`） |
| 图像 | `image/` | 文字→图片（JPEG/PNG），可指定模型/尺寸/seed | Pollinations（云端，零 Key） | 无需 |

两者都是 **HTTP API 封装**：即「调用云端服务 → 返回文件/字节」。无本地 GPU 依赖，任何机器都能跑。

---

## 二、运行环境

- Python 3.10+（本机用的 3.13 venv）
- 依赖极少：`requests` + `fastapi` + `uvicorn`（+ `python-multipart` 若用上传）

安装：
```bash
pip install requests fastapi uvicorn python-multipart
```

---

## 三、音乐模块 `music/`

### 文件
- `music_client.py` —— 核心客户端（推荐直接用）
  - `AceMusicClient(base_url, api_key, model)` 类
  - `generate(prompt, duration=15, instrumental=True, vocal_language="en", lyrics="", filename=None)` → 返回 `{ok, file, format, text, audio_base64?}`
  - 内置重试（代理偶发断连）
- `music_api.py` —— FastAPI 独立服务（端口 8002）
- `test_music.py` —— 冒烟测试示例
- `music_probe.py` —— 接口探针
- `.env` —— 凭证（**不要提交到公开仓库**）

### API 端点（独立服务 8002）
```
GET  /health                     → 服务与 key 状态
POST /music                      → 生成音乐
     body: {prompt, duration?, instrumental?, vocal_language?, lyrics?, return_base64?, filename?}
GET  /music/files/{name}         → 取回已生成的 mp3
```

### 调用示例
```bash
curl -X POST http://127.0.0.1:8002/music \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Cinematic orchestral trailer, epic drums","duration":15,"instrumental":true}'
```
```python
from music_client import AceMusicClient
c = AceMusicClient.from_env()   # 读 .env
r = c.generate("Lo-fi chill hop, warm piano, rain", duration=15, instrumental=True)
print(r["file"])                # 本地 mp3 路径
```

### 底层接口（对接时要知道）
`POST https://api.acemusic.ai/v1/chat/completions`（OpenAI 风格）
- headers: `Authorization: Bearer <key>`
- body: `{model:"acemusic/acestep-v1.5-turbo", messages:[{role:"user",content:"[musical_prompt]\n<描述>\n[lyrics]\n<歌词>"}], stream:false, instrumental:bool, duration:int, vocal_language:"en|zh|..."}`
- 返回：音频在 `choices[0].message.audio[0].audio_url.url`，是 `data:audio/mpeg;base64,...`

---

## 四、图像模块 `image/`

### 文件
- `pollinations_client.py` —— 核心客户端（推荐直接用）
  - `PollinationsClient.generate(prompt, width, height, model="flux", seed=None, nologo=True, enhance=False, safe=False)` → `{ok, file, format, bytes}`
  - `quick(prompt, filename=..., ...)` 一行生成
  - 内置 4 次指数退避重试
- `image_api.py` —— FastAPI 独立服务（端口 8003）
- `test_image.py` —— 冒烟测试示例

### API 端点（独立服务 8003）
```
GET  /health                 → 可用模型列表等
POST /image                  → 生成图片
     body: {prompt, width?, height?, model?, seed?, nologo?, enhance?, safe?, filename?}
GET  /image/files/{name}     → 取回图片
```

### 调用示例
```bash
curl -X POST http://127.0.0.1:8003/image \
  -H "Content-Type: application/json" \
  -d '{"prompt":"a red cat on a blue chair","width":768,"height":768,"seed":7,"model":"flux"}'
```
```python
from pollinations_client import quick
r = quick("futuristic city at night, neon", filename="city.jpg", width=768, height=768, seed=42)
print(r["file"])
```

### 底层接口
`POST https://image.pollinations.ai/prompt/{urlencoded_prompt}` + JSON body `{model,width,height,seed,nologo,enhance,safe}` → 直接返回图片字节。无需鉴权。
可用模型：`flux`(默认)、`turbo`、`flux-realism`、`flux-anime`、`flux-3d` 等。

---

## 五、给前端/产品集成时的建议

1. **统一入口**：本机已有一个统一 FastAPI `aigc_api.py`（端口 8000），把 `/music`、`/image` 路由合并在一处。前端只需连这一个地址：
   ```
   POST /image    # 图片
   POST /music    # 音乐
   ```
2. **异步体验**：音乐生成通常 15–40s，前端建议「提交 → 轮询/回调」；图片通常 3–10s，可同步等。
3. **文件管理**：两模块都落盘到各自 `output/`，并暴露 `/files/{name}` 静态取回；生产环境可换对象存储。
4. **Key 管理**：音乐 key 在 `music/.env`，绝不可下发到浏览器端；服务端代理即可。

---

## 六、注意事项 / 已知坑

- 网络走代理（127.0.0.1:7897）时偶发断连，两个客户端都已内置**重试**；如果部署到别的机器，去掉代理或用直连即可。
- 音乐 key 有配额/计费，测试勿过量调用。
- Pollinations 是公共免费服务，质量随模型与负载波动；**强中文文字/海报**场景建议后续接 Qwen-Image。
- 许可证：Pollinations 可商用（确认其服务条款）；acemusic 商用需按其条款。
