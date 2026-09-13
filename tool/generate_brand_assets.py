#!/usr/bin/env python3
"""WDRB のアイコンとスプラッシュを生成する。

白地に黒文字のワードマークという決まった図案なので、画像生成ではなくコードで描く。
書体はアプリのログイン画面と同じ Roboto（Weight 500）に揃える。フォントは
Android 端末の /system/fonts から取り出したものを tool/fonts/ に置いている。

    python3 tool/generate_brand_assets.py

文字は描画後のインクの外接矩形を求めてからキャンバス中央へ置くため、
フォントのメトリクスに依存せず光学中心に揃う。
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "tool/fonts"
RES = ROOT / "apps/mobile/android/app/src/main/res"
STORE = ROOT / "store"

INK = (17, 17, 17, 255)
PAPER = (255, 255, 255, 255)
TEXT = "WDRB"
WEIGHT = 500  # Flutter 側の FontWeight.w500 に合わせる


def load_font(point: int) -> ImageFont.FreeTypeFont:
    flex = FONTS / "RobotoFlex-Regular.ttf"
    if flex.exists():
        font = ImageFont.truetype(str(flex), point)
        try:
            font.set_variation_by_name("Medium")
        except Exception:
            axes = [axis["default"] for axis in font.get_variation_axes()]
            axes[1] = WEIGHT  # 2番目が Weight 軸
            font.set_variation_by_axes(axes)
        return font

    for fallback in (
        "/System/Library/Fonts/Avenir Next.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ):
        if Path(fallback).exists():
            return ImageFont.truetype(fallback, point)
    raise SystemExit("no usable font found")


def render(point: int, tracking: float) -> Image.Image:
    """指定サイズで WDRB を描き、余白を詰めて返す。"""
    font = load_font(point)
    pad = point
    canvas = Image.new("RGBA", (point * len(TEXT) * 2, point * 3), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    x = pad
    gap = point * tracking
    for index, char in enumerate(TEXT):
        draw.text((x, pad), char, font=font, fill=INK)
        x += draw.textlength(char, font=font) + (gap if index < len(TEXT) - 1 else 0)
    return canvas.crop(canvas.getbbox())


def wordmark(width: int, tracking: float) -> Image.Image:
    """幅が width になる WDRB を返す（高さは書体に従う）。"""
    point = max(8, round(width / 3.0))
    ink = render(point, tracking)
    for _ in range(6):
        if ink.width == 0:
            break
        point = max(8, round(point * width / ink.width))
        ink = render(point, tracking)
    return ink


def place(ink: Image.Image, size: int, background) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), background or (0, 0, 0, 0))
    canvas.paste(ink, ((size - ink.width) // 2, (size - ink.height) // 2), ink)
    return canvas


def icon(size: int, ratio: float, background) -> Image.Image:
    return place(wordmark(round(size * ratio), 0.06), size, background)


def splash(width: int, height: int) -> Image.Image:
    ink = wordmark(round(width * 0.8), 0.16)
    scale = min((width * 0.86) / ink.width, (height * 0.86) / ink.height)
    ink = ink.resize(
        (max(1, round(ink.width * scale)), max(1, round(ink.height * scale))),
        Image.LANCZOS,
    )
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.paste(ink, ((width - ink.width) // 2, (height - ink.height) // 2), ink)
    return canvas


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"  {path.relative_to(ROOT)} {image.width}x{image.height}")


def main() -> None:
    print("launcher icon (white background, black wordmark)")
    for density, size in [
        ("mdpi", 48),
        ("hdpi", 72),
        ("xhdpi", 96),
        ("xxhdpi", 144),
        ("xxxhdpi", 192),
    ]:
        save(icon(size, 0.70, PAPER), RES / f"mipmap-{density}/ic_launcher.png")
        # アダプティブアイコンは 108dp 中 72dp しか見えないため余白を多めに取る。
        save(
            icon(round(size * 2.25), 0.50, None),
            RES / f"mipmap-{density}/ic_launcher_foreground.png",
        )

    print("splash logo")
    save(splash(640, 200), RES / "drawable-nodpi/splash_logo.png")

    print("store assets")
    save(icon(512, 0.70, PAPER), STORE / "play-icon-512.png")


if __name__ == "__main__":
    main()
