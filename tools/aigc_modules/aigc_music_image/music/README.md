# 音乐生成模块（acemusic.ai / ACE-Step）

基于 [acemusic.ai](https://api.acemusic.ai) 的 ACE-Step 文生音乐 API，已实测跑通。
无需本地算力，调用云端模型，返回 MP3 音频（base64 或落盘）。

## 文件
- `music/.env` —— 配置：`ACEMUSIC_API_KEY` / `ACEMUSIC_BASE_URL` / `ACEMUSIC_MODEL`
- `music/music_client.py` —— 核心客户端（importable）：health / models / generate
- `music/music_api.py` —— 独立 FastAPI 服务（端口 8002）
- `music/test_music.py` —— 端到端冒烟测试
- `music/output/` —— 生成的样例音频

## 配置（已写入 .env，按需修改）
```
ACEMUSIC_API_KEY=fbb275547a0c4444ad5988bfd87a054a
ACEMUSIC_BASE_URL=https://api.acemusic.ai
ACEMUSIC_MODEL=acemusic/acestep-v1.5-turbo
```

## 实测确认的接口
| 方法 | 路径 | 说明 |
|---|---|---|
| GET  | `/health` | 健康检查，返回 200 "health check" |
| GET  | `/v1/models` | 模型列表，当前 `acemusic/acestep-v1.5-turbo` |
| POST | `/v1/chat/completions` | 生成，返回 OpenAI 风格 `choices[0].message.audio[0].audio_url.url`（data:audio/mpeg;base64,...） |

认证：`Authorization: Bearer <API_KEY>`

## 用法 1：作为库调用
```python
from music_client import AceMusicClient
c = AceMusicClient()
res = c.generate(
    "Lo-fi chill hop, warm piano, rain ambience",
    duration=15, instrumental=True, vocal_language="en",
)
c.save(res["audio"], "output/demo.mp3")
print(res["text"])  # 模型返回的 Caption/歌词元数据
```

## 用法 2：独立 API 服务
```bash
cd music
../ComfyUIApp/venv/Scripts/python.exe -m uvicorn music_api:app --host 0.0.0.0 --port 8002
```
请求示例：
```bash
curl -X POST http://127.0.0.1:8002/music \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Cinematic orchestral trailer, epic drums","duration":15,"instrumental":true}'
```

## 用法 3：接入统一 AIGC API（端口 8000）
`ComfyUIApp/aigc_api.py` 已内建音乐路由（guard 引入，不影响图/视频链路）：
- `GET  /music/health`
- `POST /music`  —— 同上字段；`return_base64=false` 时落盘并返回 `/music/files/{name}`
- `GET  /music/files/{name}`

> 注意：统一服务文件名为 `aigc_api.py`，因为 ComfyUI 自带 `api_server/` 包会
> 同名遮蔽顶层 `api_server.py`（Python 优先导入包），故已改名避免冲突。

## 生成参数速查
| 字段 | 说明 |
|---|---|
| `prompt` | 音乐风格/场景描述（caption） |
| `lyrics` | 歌词；`instrumental=true` 时忽略 |
| `duration` | 时长(秒)，不传由模型自定 |
| `bpm` | 每分钟节拍 |
| `vocal_language` | `en`/`zh`/`ja`/`ko`... |
| `instrumental` | 纯器乐（无人声） |
| `sample_mode` | `true` 时把 prompt 当自然语言，由模型自动拆 prompt/lyrics |
| `temperature` / `top_p` | LM 采样参数（默认 0.85 / 0.9） |
| `seed` | 固定可复现 |

## 状态
- 已部署、已实测（生成 15s 纯器乐 MP3 成功，格式 mpeg，含 Caption 元数据）。
- 代理偶发 SSL/Proxy 抖动，客户端已内置重试（最多 3 次）。
- 许可证：云端 API，按 acemusic.ai 服务条款使用；与本地模型（FLUX/Wan2.2）的本地部署许可无关。
