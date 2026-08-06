"""
test_music.py — 端到端冒烟测试
生成一个 15 秒纯器乐短片，保存到 music/output/demo.mp3，并打印体积与元数据。
"""
import os
from music_client import AceMusicClient

_HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    c = AceMusicClient()
    print("[test] health:", c.health())
    print("[test] models:", [m["id"] for m in c.models().get("data", [])])

    print("[test] generating 15s instrumental lo-fi ...")
    res = c.generate(
        "Lo-fi chill hop, warm piano, rain ambience, relaxing study beats",
        duration=15,
        instrumental=True,
        vocal_language="en",
    )
    out = os.path.join(_HERE, "output", "demo.mp3")
    c.save(res["audio"], out)
    kb = len(res["audio"]) / 1024
    print(f"[test] OK -> {out}  ({kb:.1f} KB, format={res['format']}, model={res['model']})")
    if res.get("text"):
        print("[test] text/lyrics:", res["text"][:200])


if __name__ == "__main__":
    main()
