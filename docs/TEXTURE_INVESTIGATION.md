# 画像が1×1になる問題の調査（2026-09-24）

## 実機で確認できた事実

ユーザーの `/pbtrade assets` 出力では、atlas、crest、band_glow、左右band_tip、coin_plinth等が1×1と報告された。地図画面では白い矩形となっている。描画順だけを直す対応では解消していない。出力にはアドオン相対パスと管理された格納先の2候補が存在するが、未読込画像ごとの使用中パスは旧診断には出ていない。両候補を実機で正常に試せたとまでは断定しない。

## ローカルの比較

- オープニング追加直前v0.7.5とv0.8.0の既存DDS全14点、Assets.luaはバイト単位で同一。マニフェストの画像登録にも差分なし。
- アップロード用フォルダの版はv0.16.3。実際にサーバーから配信された内容までは未確認。
- アップロード用フォルダのDDS全15点は現行開発版と一致（下表）。登録パスの大小文字も一致。
- atlas.ddsのDDSヘッダーは、表示できているWarTableのboard_material.ddsと同一。これはヘッダー形式の確認であり、PS5でのデコード成功を保証しない。
- アップローダーのローカルコードは選択されたファイルをZIPに格納する。ローカルフォルダに存在することと、実際のリリースに含まれることは区別する。

## 次の切り分け

ESOをホーム画面から完全終了して再起動した結果を確認する。UIリロードと区別する。キャッシュが原因と確定したわけではない。改善しなければ、配信物の内容と実機での各パスの読み込みを比較する。画像の削除やセーブ初期化は行わない。v0.16.4の切り戻し修正だけで今回の原因を解消したとは扱わない。

| 画像 | バイト数 | アップロード用との比較 | SHA256 |
|---|---:|---|---|
| atlas.dds | 1398256 | 一致 | b015fde534b73e24a17a5357f31bffdfdcbce79550be70f1fddca176d9b56d71 |
| band_glow.dds | 5648 | 一致 | e3f325a867a752c9a895ea8427fbe6296dd657d8e8c26ffffc9ca71f7737d602 |
| band_tip_left.dds | 5648 | 一致 | 9622c47ecdddcb49e962582eab3053b28d8d27afec8eba034aecdbba7d421ebb |
| band_tip_right.dds | 5648 | 一致 | 2b1ea1ecef125e38adc14afe320ccdf935aa9188f9f27ad5e5cae63863a67050 |
| chapter_1.dds | 699216 | 一致 | faf67d29e9dd8b0c77d0f752f210e7f29de1837d36bc853537549f26f173e78e |
| chapter_2.dds | 699216 | 一致 | 71a4e09b715fd90c164d343ca4754db3979850ad29ad2c0671801c1477ab947b |
| chapter_3.dds | 699216 | 一致 | 1db862231250b07855e5c123c8d164fadb18b84cf79e1ce7f3bc2f31ef881ee4 |
| chapter_4.dds | 699216 | 一致 | 5ba40a0c34f87a8ab147786362c4b8568030a4554f2bdca492b670320eb45b80 |
| chapter_5.dds | 699216 | 一致 | 822de296da966d56836d2daa71d8232dc81e5d9d06720e9c0df9c89c6b66793a |
| coin.dds | 11088 | 一致 | fb1ed9ebe2f3bdb8b8f643e24f9e0b6c6d0e8a1fa5286228f1664379137bef45 |
| coin_plinth.dds | 87568 | 一致 | 9a9d4002a027423dbc81c3e91fc9c58f39557499d5ed56aa856ad95b492b774a |
| crest.dds | 87536 | 一致 | 0c68a252d9b2455a5eacc290a57b1571ec42caf996bc8b86defa7e025b2c1e61 |
| title_hall.dds | 699216 | 一致 | 5a9a88726d82ec03717bdd33697d4095f5ca92ba53a3d48643f751ded1cdc9a0 |
| treasury.dds | 2796368 | 一致 | b831539dad6f89ea37335ddde4dad04968da54ba6ade854598044343d26e5604 |
| wood_frame.dds | 174928 | 一致 | 986fb0e5f69f0662f4808d1ae4a847ab464407b60d1b588a15e6b0f9e95d1d7b |
