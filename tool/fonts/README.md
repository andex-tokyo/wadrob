# Brand font

`RobotoFlex-Regular.ttf` は Android 端末の `/system/fonts/RobotoFlex-Regular.ttf` から取り出したもの。
アプリのクローゼット画面と同じRobotoの字形・字間でアイコンとスプラッシュを描くために同梱している。

再取得する場合:

```sh
adb pull /system/fonts/RobotoFlex-Regular.ttf tool/fonts/
python3 tool/generate_brand_assets.py
```

Roboto は Apache License 2.0（https://github.com/googlefonts/roboto-3-classic）で配布されている。
