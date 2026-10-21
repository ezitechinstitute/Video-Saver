"""Renders every icon asset for design B through headless Chrome.

Outputs (in ./out):
  app_icon.png            1024  rounded icon, transparent corners (legacy launcher, iOS)
  icon_bg.png             1024  adaptive icon background, full bleed
  icon_fg.png             1024  adaptive icon foreground, artwork inside the 66% safe zone
  play_icon_512.png        512  Play Store icon, full bleed square (Play applies its own mask)
  splash.png              1254  splash artwork on transparent
  splash_android12.png    1152  splash artwork inside Android 12's circular mask
  feature_graphic.png  1024x500 Play Store feature graphic
"""
import pathlib
import subprocess

HERE = pathlib.Path(__file__).parent
OUT = HERE / "out"
OUT.mkdir(exist_ok=True)

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

DEFS = """
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#2B3BFF"/>
    <stop offset=".6" stop-color="#5A2BE0"/>
    <stop offset="1" stop-color="#2A0F8C"/>
  </linearGradient>
  <radialGradient id="glow" cx=".35" cy=".3" r=".6">
    <stop offset="0" stop-color="#8FB4FF" stop-opacity=".55"/>
    <stop offset="1" stop-color="#8FB4FF" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity=".38"/>
    <stop offset="1" stop-color="#fff" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="play" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#FFFFFF"/>
    <stop offset="1" stop-color="#DCD3FF"/>
  </linearGradient>
  <linearGradient id="badge" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#3EF2C9"/>
    <stop offset="1" stop-color="#11A6E8"/>
  </linearGradient>
  <filter id="sh" x="-30%" y="-30%" width="160%" height="160%">
    <feDropShadow dx="0" dy="20" stdDeviation="20" flood-color="#160650" flood-opacity=".5"/>
  </filter>
</defs>
"""

# Background layer, drawn over a full 1024 square.
BG = """
<rect width="1024" height="1024" fill="url(#bg)"/>
<rect width="1024" height="1024" fill="url(#glow)"/>
<path d="M0 0 H1024 V400 C760 500 260 500 0 400 Z" fill="url(#gloss)"/>
"""

# Play button and download badge, in the 1024 design space.
ART = """
<g filter="url(#sh)">
  <path d="M360 270 C360 236 396 216 425 233 L740 418 C769 435 769 477 740 494 L425 679 C396 696 360 676 360 642 Z" fill="url(#play)"/>
</g>
<path d="M392 280 C392 262 410 252 426 261 L640 386 C580 392 470 430 392 500 Z" fill="#fff" opacity=".6"/>
<g filter="url(#sh)">
  <circle cx="742" cy="742" r="168" fill="url(#badge)"/>
  <circle cx="742" cy="742" r="168" fill="none" stroke="#fff" stroke-opacity=".9" stroke-width="18"/>
  <path d="M742 650 V800 M682 744 L742 806 L802 744" fill="none" stroke="#fff" stroke-width="40" stroke-linecap="round" stroke-linejoin="round"/>
</g>
"""

RX = 232  # corner radius of the rounded icon, in 1024 units


def rounded_icon(size: int) -> str:
    """The finished icon: rounded square, artwork inside."""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024">
{DEFS}
<clipPath id="r"><rect width="1024" height="1024" rx="{RX}"/></clipPath>
<g clip-path="url(#r)">{BG}</g>
{ART}
</svg>"""


def full_bleed(size: int) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024">
{DEFS}{BG}{ART}</svg>"""


def background_only(size: int) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024">
{DEFS}{BG}</svg>"""


def foreground_only(size: int) -> str:
    # The artwork's furthest point from its own centre (639.5, 567.5) is about
    # 436 units away; Android's adaptive safe zone is a 66/108 circle, 313
    # units in radius on a 1024 canvas. Scale 0.72 and re-centre.
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024">
{DEFS}
<g transform="translate(512 512) scale(0.60) translate(-639.5 -567.5)">{ART}</g>
</svg>"""


def centred_icon(canvas: int, icon: int) -> str:
    """The rounded icon centred on a transparent canvas, for splash screens."""
    off = (canvas - icon) / 2
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{canvas}" height="{canvas}">
<g transform="translate({off} {off}) scale({icon / 1024})">
{DEFS}
<clipPath id="r"><rect width="1024" height="1024" rx="{RX}"/></clipPath>
<g clip-path="url(#r)">{BG}</g>
{ART}
</g></svg>"""


def feature_graphic() -> str:
    icon = 300
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="500">
<defs>
  <linearGradient id="fg_bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#0E1E5A"/>
    <stop offset=".55" stop-color="#1B1570"/>
    <stop offset="1" stop-color="#2A0F8C"/>
  </linearGradient>
  <radialGradient id="fg_glow" cx=".27" cy=".5" r=".45">
    <stop offset="0" stop-color="#5A6BFF" stop-opacity=".55"/>
    <stop offset="1" stop-color="#5A6BFF" stop-opacity="0"/>
  </radialGradient>
</defs>
<rect width="1024" height="500" fill="url(#fg_bg)"/>
<rect width="1024" height="500" fill="url(#fg_glow)"/>
<g transform="translate(110 100) scale({icon / 1024})">
{DEFS}
<clipPath id="r"><rect width="1024" height="1024" rx="{RX}"/></clipPath>
<g clip-path="url(#r)">{BG}</g>
{ART}
</g>
<text x="470" y="215" font-family="Segoe UI, Arial, sans-serif" font-size="58" font-weight="800" fill="#FFFFFF">Video Downloader</text>
<text x="470" y="282" font-family="Segoe UI, Arial, sans-serif" font-size="46" font-weight="700" fill="#3EF2C9">Status Saver</text>
<text x="470" y="340" font-family="Segoe UI, Arial, sans-serif" font-size="26" font-weight="500" fill="#C9D3FF">No watermark · HD · No login</text>
</svg>"""


def render(name: str, svg: str, w: int, h: int, transparent: bool) -> None:
    html = HERE / f"_{name}.html"
    html.write_text(
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<style>html,body{margin:0;background:transparent;overflow:hidden}"
        "svg{display:block}</style></head><body>" + svg + "</body></html>",
        encoding="utf-8",
    )
    args = [
        CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
        "--force-device-scale-factor=1",
        f"--window-size={w},{h}",
        f"--screenshot={OUT / name}",
    ]
    if transparent:
        args.append("--default-background-color=00000000")
    args.append(html.as_uri())
    subprocess.run(args, check=True, capture_output=True)
    html.unlink()
    print("rendered", name)


render("app_icon.png", rounded_icon(1024), 1024, 1024, True)
render("icon_bg.png", background_only(1024), 1024, 1024, False)
render("icon_fg.png", foreground_only(1024), 1024, 1024, True)
render("play_icon_512.png", full_bleed(512), 512, 512, False)
render("splash.png", centred_icon(1254, 1000), 1254, 1254, True)
render("splash_android12.png", centred_icon(1152, 600), 1152, 1152, True)
render("feature_graphic.png", feature_graphic(), 1024, 500, False)
render("app_icon_ios.png", full_bleed(1024), 1024, 1024, False)
