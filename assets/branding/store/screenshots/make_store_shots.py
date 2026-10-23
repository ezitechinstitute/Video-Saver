"""Builds the Play Store phone screenshots (1080x1920) from emulator captures.

Each one: a bold benefit headline at the top, a short line under it, and the
real app screen in a phone frame. Captions name no other company's product,
so the listing never reads as affiliated with one.
"""
import base64
import pathlib
import subprocess

HERE = pathlib.Path(__file__).parent / "source"
OUT = pathlib.Path(__file__).parent
OUT.mkdir(exist_ok=True)
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

SHOTS = [
    ("01_home", "home.png", "Save Any Video<br>in <em>HD</em>", "No watermark &middot; No login &middot; Free"),
    ("02_paste", "home_platforms.png", "Copy a Link,<br>Tap <em>Paste</em>", "The download starts by itself"),
    ("03_progress", "progress.png", "Fast <em>1080p</em><br>Downloads", "Full HD MP4, straight to your phone"),
    ("04_saved", "saved.png", "Right in Your<br><em>Gallery</em>", "Tap Open and watch it instantly"),
    ("05_status", "status.png", "<em>Status Saver</em><br>Built In", "Keep the status videos you have watched"),
]

CSS = """
html,body{margin:0;width:1080px;height:1920px;overflow:hidden;font-family:'Segoe UI',Arial,sans-serif}
.bg{position:absolute;inset:0;background:linear-gradient(160deg,#2B3BFF 0%,#5A2BE0 55%,#2A0F8C 100%)}
.glow{position:absolute;width:900px;height:900px;left:90px;top:640px;border-radius:50%;
  background:radial-gradient(circle,rgba(62,242,201,.35),rgba(62,242,201,0) 65%)}
h1{position:absolute;top:110px;left:0;right:0;margin:0;text-align:center;color:#fff;
  font-size:104px;line-height:1.05;font-weight:800;letter-spacing:-1px}
h1 em{font-style:normal;color:#3EF2C9}
p{position:absolute;top:360px;left:0;right:0;margin:0;text-align:center;color:#DCE3FF;font-size:44px;font-weight:500}
.phone{position:absolute;left:50%;top:500px;transform:translateX(-50%);width:640px;height:1422px;
  border-radius:78px;background:#0B0F24;padding:18px;box-sizing:border-box;
  box-shadow:0 40px 90px rgba(10,4,60,.55),0 0 0 3px rgba(255,255,255,.18) inset}
.phone img{width:100%;height:100%;border-radius:62px;display:block;object-fit:cover;object-position:top}
"""

FEATURES = [
    ("&#10003;", "No watermark"),
    ("&#9654;", "HD up to 1080p"),
    ("&#8681;", "Saves to your gallery"),
    ("&#9741;", "Status saver"),
    ("&#128274;", "No login, no sign up"),
    ("&#9733;", "Free to use"),
]

FEATURE_CSS = """
.title{position:absolute;top:150px;left:0;right:0;text-align:center;color:#fff;font-size:96px;font-weight:800;line-height:1.08}
.title em{font-style:normal;color:#3EF2C9}
.list{position:absolute;top:520px;left:120px;right:120px}
.row{display:flex;align-items:center;gap:40px;background:rgba(255,255,255,.10);border:2px solid rgba(255,255,255,.18);
  border-radius:40px;padding:34px 44px;margin-bottom:34px;color:#fff;font-size:52px;font-weight:700}
.ic{width:96px;height:96px;border-radius:30px;background:linear-gradient(135deg,#3EF2C9,#11A6E8);
  display:flex;align-items:center;justify-content:center;font-size:52px;color:#fff;flex:none}
"""


def render(name: str, body: str, css: str) -> None:
    html = HERE / f"_{name}.html"
    html.write_text(
        f"<!doctype html><html><head><meta charset='utf-8'><style>{css}</style></head><body>{body}</body></html>",
        encoding="utf-8",
    )
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
         "--window-size=1080,1920", f"--screenshot={OUT / (name + '.png')}", html.as_uri()],
        check=True, capture_output=True,
    )
    html.unlink()
    print("rendered", name)


for name, src, title, sub in SHOTS:
    data = base64.b64encode((HERE / src).read_bytes()).decode()
    body = (f"<div class='bg'></div><div class='glow'></div><h1>{title}</h1><p>{sub}</p>"
            f"<div class='phone'><img src='data:image/png;base64,{data}'></div>")
    render(name, body, CSS)

rows = "".join(f"<div class='row'><div class='ic'>{i}</div>{t}</div>" for i, t in FEATURES)
render("06_features",
       f"<div class='bg'></div><div class='glow'></div><div class='title'>Everything You<br>Need, <em>Free</em></div>"
       f"<div class='list'>{rows}</div>",
       CSS + FEATURE_CSS)
