# Gyazo Capture for macOS

範囲・全画面・ウィンドウを撮影し、注釈やマスク加工を加えてからGyazoへアップロードできるメニューバーアプリです。

## 動作環境

- macOS 13以降
- Gyazoアカウント
- Gyazoで登録したOAuthアプリ

## 開発版を起動する

```sh
./script/build_and_run.sh
```

開発版は `GyazoCaptureDev.app`、Bundle IDは `com.toma7698.GyazoCapture.dev` として生成されます。リリース版の画面収録許可やKeychainを上書きしません。開発版でOAuthを試す場合は、リダイレクトURIとして `gyazocapture-dev://oauth/callback` を登録してください。

インストール済みのリリース版は次のコマンドで起動できます。

```sh
./script/launch_installed.sh
```

Codexの「Run」はインストール済みリリース版、「Develop」は分離された開発版を起動します。起動するとメニューバーにカメラアイコンが表示されます。範囲・メイン画面全体・ウィンドウ・前回範囲には、それぞれ独立したグローバルショートカットを設定できます。

ショートカットと既定のキャプチャモードは「設定…」の「一般」で変更できます。同じ組み合わせの重複やmacOS標準のスクリーンショットキーと重なる組み合わせは登録できず、変更に失敗した方式だけ直前の設定へ戻ります。

## 画像編集

- 矩形、楕円、直線、矢印、テキスト、ハイライト
- 完全な黒塗り、ブラー、モザイク
- クロップ、左右90度回転、Undo／Redo
- 編集後画像のクリップボードコピー、PNG保存、Gyazoアップロード

アップロードに失敗しても編集画面と加工内容は維持され、「Gyazoへ再試行」からそのまま再送できます。コピー・保存・アップロードはいずれも同じ最終合成画像を使用します。

## Gyazo OAuthの設定

1. [Gyazo Developers](https://gyazo.com/api)でアプリケーションを登録します。
2. リダイレクトURIに `gyazocapture://oauth/callback` を設定します。
3. Gyazo Captureの「設定…」を開きます。
4. client IDとclient secretを入力し、「保存してGyazoに接続」を押します。

client ID、client secret、access tokenはmacOS Keychainへ保存されます。開発版とリリース版は別々のKeychain領域を使用します。画像の説明に `#tag` を含めるとGyazo上のタグとして利用できます。

## コレクション

Gyazoの公開APIにはコレクション一覧APIがないため、アカウント内の一覧を自動同期することはできません。設定画面の「Gyazoでコレクションを確認」でCapturesページを開き、対象コレクションのURLをコピーして「クリップボードからURLを読み込む」で登録してください。登録後は編集画面のコレクション一覧から選択できます。

## Ad Hoc署名版の初回起動

GitHub ReleasesのビルドはDeveloper IDを使わないAd Hoc署名です。初回起動がGatekeeperに止められた場合は、次の手順で許可します。

1. DMGを開き、Gyazo CaptureをApplicationsへコピーします。
2. 一度アプリを起動します。
3. システム設定の「プライバシーとセキュリティ」を開きます。
4. Gyazo Captureについて「このまま開く」を選択します。
5. 起動後、画面収録を許可します。

Ad Hoc署名では、アプリ更新後に画面収録の再許可が必要になる場合があります。

## チェック

```sh
./script/run_checks.sh
```

## リリースビルド

```sh
./script/build_release.sh 0.1.0 1
```

`dist/GyazoCapture-0.1.0.dmg` とSHA-256チェックサムを作成します。`v0.1.0` のようなタグをpushすると、GitHub Actionsが同じ成果物をGitHub Releasesへ公開します。
