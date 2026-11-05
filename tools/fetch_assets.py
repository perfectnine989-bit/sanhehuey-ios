"""Скачивает картинки кейсов и призов с сайта и кладёт их в каталог ресурсов приложения."""
import sys, os, io, json, urllib.request
from PIL import Image

CAT = sys.argv[1] if len(sys.argv) > 1 else "App/Assets.xcassets"
BASE = "https://sanhehuey.online"
HEAD = {"User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) SanHeHuey-Build"}

PRIZES = ["balance-100", "music-prize-v16", "second-chance", "telegram-premium-1m", "telegram-premium-1y",
          "unlimited", "vpn-14d", "vpn-1m", "vpn-1y", "vpn-3d", "vpn-3m", "vpn-5d", "vpn-6m", "vpn-7d"]
POSTERS = {
    "family": "case-family-poster",
    "red60": "case-red-envelope-poster",
    "g": "case-g-poster",
    "safe200": "case-family-safe-poster",
    "topg": "case-topg-poster",
    "contract800": "case-black-contract-poster",
}


def fetch(path):
    req = urllib.request.Request(BASE + path, headers=HEAD)
    with urllib.request.urlopen(req, timeout=40) as r:
        return r.read()


def write_imageset(name, im):
    d = os.path.join(CAT, name + ".imageset")
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, name + ".png"), optimize=True)
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": name + ".png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, f)


def grab(path, name, max_w):
    try:
        im = Image.open(io.BytesIO(fetch(path))).convert("RGBA")
        if im.width > max_w:
            im = im.resize((max_w, int(im.height * max_w / im.width)), Image.LANCZOS)
        write_imageset(name, im)
        print("ok  ", name, im.size)
        return True
    except Exception as e:
        print("FAIL", name, e)
        write_imageset(name, Image.new("RGBA", (512, 512), (24, 18, 22, 255)))
        return False


ok = 0
for p in PRIZES:
    ok += grab(f"/icons/prizes-mafia-v2/{p}.webp", "prize_" + p, 512)
for key, fn in POSTERS.items():
    ok += grab(f"/icons/cases-economy-v8/{fn}.webp", "poster_" + key, 1000)
print(f"downloaded {ok}/{len(PRIZES) + len(POSTERS)}")
