# タムリエル交易戦 — アート方針と原画

PBs WarTableの重厚な素材感を参考に、暗い石造金庫・古い胡桃材・青銅・くすんだ金・羊皮紙を用いる。装飾は外周に置き、中央を買収ゲージと金貨のために空ける。原作の画像・文章・紋章は流用しない。

背景と紋章は内蔵 `image_gen` ツールで今回新規制作した。CLIは使用していない。採用した原画と実装用DDSはすべてこのプロジェクト内に保存している。`scripts/build_presentation.py` がサイズ調整とDDS変換を再現する。紋章の透過アルファを保持する。

| 原画 | 組み込み先 | 用途 |
|---|---|---|
| [treasury-master.png](art/treasury-master.png) | `PBsTradeGame/assets/treasury.dds` | 全画面の商会金庫背景 |
| [merchant-crest-master.png](art/merchant-crest-master.png) | `PBsTradeGame/assets/crest.dds` | タイトルと両商会の透過紋章 |
| [atlas-master.png](art/atlas-master.png) | `PBsTradeGame/assets/atlas.dds` | 地域索引の装飾地図 |
| [chapter_1.png](art/chapter_1.png) | `PBsTradeGame/assets/chapter_1.dds` | 第1章・商会の黎明 |
| [chapter_2.png](art/chapter_2.png) | `PBsTradeGame/assets/chapter_2.dds` | 第2章・港湾大商会 |
| [chapter_3.png](art/chapter_3.png) | `PBsTradeGame/assets/chapter_3.dds` | 第3章・ベールの守護者連合 |
| [chapter_4.png](art/chapter_4.png) | `PBsTradeGame/assets/chapter_4.dds` | 第4章・虫の教団の物流網 |
| [chapter_5.png](art/chapter_5.png) | `PBsTradeGame/assets/chapter_5.dds` | 第5章・異界コンツェルン |

`wood_frame.dds` はコードで制作したオリジナル素材。金貨は下記の追加制作原画へ更新済み。ゲーム内の地名・物件・数値・ボタンは画像へ焼き込まず、Lua UIで表示する。装飾地図はタムリエルの正確な地形図ではなく、実在するESO地域を選ぶための交易帳の意匠。

## 金貨の動き

資金投入で上から金貨が落下し、奥5本・中央6本・手前5本の柱を持つ立体的な山へ着地する。山が一定の高さを超えたら左右独立の表示が上層を追い、床が下がる。描画枚数の制限で山の成長を止めず、画面外の過去の層を描かない。巨額投入は代表金貨へまとめ、少数の落下体で表現する。正確な累計額は常時文字で表示する。

左右の金貨は同じ金額単位だが、表示位置はそれぞれの山の先端を優先する。背景帯は累計出資の比較ではなく、現在の買収ゲージを表す。シミュレーションと演出の乱数・時間更新は分離し、描画が勝敗を変えない。

画面左は相手、右は自社。相手の赤帯には左から右、自社の青帯には右から左へ移動する独自の光沢テクスチャを重ねる。全アセットはESO実機向けDXT5と完全なミップチェーンで収録する。
帯の境界には透過三角マスク `band_tip_right.dds` / `band_tip_left.dds` を配置し、赤と青が中央の一点へ向かって細くなる。マスクは `scripts/build_assets.py` で生成し、参照画像の画素は使用しない。

## 使用した最終プロンプト

### 金庫背景

Use case: stylized-concept. Asset type: production background plate for a full-screen fantasy merchant acquisition minigame, 16:9 landscape, 2048x1152. Create an original, richly crafted medieval fantasy merchant guild treasury hall, fitting the grounded material atmosphere of Elder Scrolls Online, without any official logos. Front-facing symmetrical scene: carved dark walnut and oxidized bronze architectural frame around a large quiet charcoal stone recess occupying the middle 80 percent, two subtle Gothic arches, candle sconces far left and far right, dusty green velvet drapes and merchant ledgers only on extreme edges. A low dark carved counting counter along the lower edge, restrained brass compass inlays, stone masonry and atmospheric warm candlelight, painterly photoreal game environment art. Keep center and upper center dark and uncluttered, ample room for independently rendered UI and two rising coin towers. Premium tactile realistic wood grain, hammered metal, worn stone; chic subdued palette, no neon. No coins, no people, no words, no lettering, no UI mockup, no charts, no buttons. Entire image is scenery for a live game.

### 商会紋章

Use case: logo-brand. Asset type: original transparent-background inventory emblem for a fantasy merchant guild game. A single exquisitely crafted aged bronze and pale gold heraldic compass rose resting within a circular merchant seal, with two delicate laurel branches and a subtle dusty rose enamel accent, tiny dark green leather backing inside the seal only. Straight-on, centered, silhouette readable at 80px, high-end realistic engraved metal relief, softly lit, richly tactile, restrained Elder Scrolls-like medieval fantasy craftsmanship but wholly original. Square canvas. True transparent background outside emblem, no rectangle, no text, no official logos, no letters, no numbers, no checkerboard.

### 交易地図

Use case: stylized-concept. Asset type: original game UI parchment atlas surface 1536x1024 landscape. A beautifully hand-painted old fantasy trading chart laid completely flat viewed straight overhead, muted sepia and charcoal ink on aged grey-beige vellum, irregular folded edges, antique bronze corner fasteners, delicate compass rose in bottom right, faint coastlines, mountains, maritime route dotted arcs and small merchant ship drawings mainly near the margins. Original evocative continent cartography reminiscent of a Tamriel trading ledger but not a copy of any existing map. Large low-contrast quiet center area for live location cards. Tactile, sophisticated, aged and darkened yet readable material. No words, no labels, no letters, no numbers, no UI buttons, no ornate thick outer picture frame, full bleed parchment.

## 金貨の質感・7秒演出の更新

2026-09-23：内蔵 `image_gen` で金貨原画を新規制作し、旧幾何図形の金貨を置換。CLIは未使用。
原画：[art/coin-master.png](art/coin-master.png)。組み込み先：`PBsTradeGame/assets/coin.dds`（128×64、アルファ保持）。`scripts/build_assets.py` で原画から変換を再現できる。

### 金貨に使用した最終プロンプト

Use case: product-mockup. Production game sprite, a SINGLE realistic aged gold coin isolated on a truly transparent background, no other objects. One coin lying flat horizontally, viewed from a shallow elevated angle, showing its elliptical top face and thick finely milled front edge, proportions approximately 2:1 width to total height. Centered and filling the canvas with only a slim transparent margin. Rich warm muted antique gold metal with physically realistic highlights, tiny worn dents and scratches, dark crevices around engraved relief, a raised original merchant compass rose emblem and a narrow beaded rim. Sophisticated medieval fantasy craftsmanship suitable for a dark candlelit merchant treasury. Directional soft warm light from upper left. Clean crisp alpha silhouette with NO cast shadow outside the coin. Photorealistic material, not a cartoon, not a flat vector icon, not yellow plastic. No text, lettering, numbers, official logos, ground plane, backdrop or checkerboard. Landscape canvas. It will be displayed at 44 by 22 pixels and stacked repeatedly, so prioritize convincing gold edge depth and a clear sculpted silhouette.

### 時間と効果音

出資1回ごとの最初の落下開始を0秒、最後の着地を7秒に固定。投入量が多いほど序盤の飛行時間と発生間隔を短くし、終盤に向けて徐々に減速する。追加入金は独立した時間軸で重なり、先の入金をリセットしない。非表示で明示的に中断した時間は数えない。結果画面でも残りを描画し、地図などへ離れると描画・SEを停止する。

着地イベントに合わせ、ESO内蔵の `SOUNDS.ITEM_MONEY_CHANGED`（`Money_Transact`）を `PlaySound` で再生。左右共通で最短0.18秒に制限し、音を何十個も同時発音しない。アドオン独自の録音音源ではない。設定は `Config.coins.soundEnabled` / `soundKey` / `soundInterval`。クライアントの音量設定を変更しない。実際の音色・音量はESOでの試聴が必要。

API出典：[ESO公開UIのSoundIds.lua](https://github.com/esoui/esoui/blob/live/esoui/libraries/globals/soundids.lua#L232)。

## 立体的な積層配置

参考画像の構成をもとに、奥・中央・手前の3列で16本の金貨の柱を並べる。奥は90%、中央は96%、手前は100%の大きさとし、奥の陰影を強くする。奥から手前へ描画し、落下中の金貨も同じ奥行き順へ挿入する。金貨原画は独自制作のまま、参照画像のピクセルは使わない。楕円の石製台座 `PBsTradeGame/assets/coin_plinth.dds` は `scripts/build_presentation.py` の幾何図形から制作。先端追従は16本のうち最も高く見える位置を基準に行う。

## 5章の導入背景

2026-09-23：内蔵 `image_gen` の画像生成モードで5点を制作。いずれも16:9、文字・ロゴなし、中央を説明文用に暗く空けた独自背景。ゲーム内では1024×512のDXT5＋完全ミップチェーンへ変換し、章開始モーダルの背面に表示する。

最終プロンプトの共通骨格は「painterly fantasy game UI background plate / realistic hand-painted textures / quiet dark center for Japanese text overlay / no readable text / no logos / original design」。各章固有の指定は次の通り。

1. 第1章：夜明けの商会帳場、羊皮紙地図、天秤、封蝋台帳、控えめな金貨箱、暗褐色と鈍い青緑。
2. 第2章：豪奢な港湾交易所と評議会室、紋章のない競合旗、積荷台帳、古金と濃紺。
3. 第3章：森境の秘密交易評議会、幾重の幕、封蝋、建築へ隠した蛾と甲殻の意匠、深紅・苔緑・炭色。
4. 第4章：旧市街地下の呪術的物流室、骨の灯籠、黒い台帳、封印貨物、影で示す儀式幾何、青黒と古銅。
5. 第5章：冷たい青黒の鎖塔と赤い火山異界を結ぶ巨大コンツェルン要塞、荷車の渡る不可能な橋、中央城塞。
