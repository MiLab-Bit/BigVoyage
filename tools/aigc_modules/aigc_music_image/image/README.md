# 图像生成模块（Pollinations · 零 Key 云端）

无需 API Key、无需本地算力，直接调用 [Pollinations](https://pollinations.ai) 免费图像接口。
适合作为管线里"不依赖本地模型"的图像入口，与 ComfyUI 本地 FLUX 路线互为补充。

## 接口说明

- Base：`https://image.pollinations.ai/prompt/{prompt}`
- 主用 **POST**（prompt 放路径 + JSON body），带重试应对代理偶发断连
- 返回原始图片字节（JPEG/PNG），无需鉴权
- 可用模型（免费）：`flux`(默认,高质量) / `turbo`(快) / `flux-realism` / `flux-anime` / `flux-3d` / `any-dark` / `flux-pro` / `dreamshaper` / `sdxl`

## 文件

| 文件 | 作用 |
|---|---|
| `pollinations_client.py` | 核心客户端：`PollinationsClient.generate(...)` + `quick()` 一行生成 |
| `image_api.py` | 独立 FastAPI 服务（默认 `127.0.0.1:8003`） |
| `test_image.py` | 冒烟测试（库调用 + API 调用） |
| `output/` | 生成图落盘目录 |

## 用法 1：作为库

```python
from pollinations_client import quick
r = quick("a red cat on a blue chair", width=768, height=768, seed=42, filename="cat.jpg")
print(r["file"], r["format"], r["bytes"])
```

## 用法 2：独立服务

```bash
cd image
../ComfyUIApp/venv/Scripts/python.exe -m uvicorn image_api:app --host 127.0.0.1 --port 8003
```

- `GET  /health` → `{"ok":true,"service":"pollinations-image","models":[...]}`
- `POST /image`（字段见下）→ 返回 `{ok, file, url, format, model, seed, ...}`
- `GET  /image/files/{name}` → 取回图片

```bash
curl -X POST http://127.0.0.1:8003/image \
  -H "Content-Type: application/json" \
  -d '{"prompt":"a serene mountain lake at sunrise, oil painting","width":768,"height":768,"seed":7,"model":"flux","filename":"demo.jpg"}'
```

## 用法 3：接入统一 AIGC API（端口 8000）

`../ComfyUIApp/aigc_api.py` 已 guard 引入本模块：

- `GET  /image/health`
- `POST /image` —— 同下字段；`return_base64=false` 时落盘并返回 `/image/files/{name}`
- `GET  /image/files/{name}`

### `POST /image` 请求字段

| 字段 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `prompt` | str | 必填 | 英文描述（中文也可，但英文质量更佳） |
| `width` | int | 1024 | 64–2048 |
| `height` | int | 1024 | 64–2048 |
| `seed` | int\|null | null | 固定可复现；null=随机 |
| `model` | str | `flux` | 见上方模型列表 |
| `nologo` | bool | true | 去除 Pollinations 水印 |
| `enhance` | bool | false | 自动增强 prompt |
| `safe` | bool | false | 安全过滤 |
| `filename` | str\|null | null | 落盘文件名（不含扩展名亦可） |
| `return_base64` | bool | false | true 时直接返回 base64 而非落盘 |

## 实测

- `smoke_direct.jpg`：768×768，约 46KB，耗时 ~3.2s
- `api_demo.jpg`：768×768，约 50KB，经 API 生成

## 备注

- 全程走系统代理 `127.0.0.1:7897`；大 POST 偶发断连已由客户端重试（4 次，指数退避）吸收。
- 与音乐线（`music/`）一样，这是**云端 SaaS**，不涉及本地模型许可问题，可商用场景请确认 Pollinations 服务条款。
- 若要做中文海报/复杂文字，Pollinations 的英文渲染优于中文；这类强文字需求仍建议走本地 Qwen-Image（需另部署）。
