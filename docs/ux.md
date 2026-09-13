# Wardrobe UX

ログイン後はクローゼットへ直行する。2列を標準に2/3/4列を保存でき、4:5画像、ブランド、商品名の順で表示する。カテゴリは横スクロール、検索はAppBar内、複合filterはbottom sheet、sortはmenuで完結する。

Drift cacheを先に表示してから同期し、refresh中や通信エラーでも既存一覧を消さない。画像領域を固定してlayout shiftを防ぎ、detailは同じnavigation stackに積んでscroll位置を保持する。登録後は完了画面を挟まず一覧へ戻す。
