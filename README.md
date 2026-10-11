# my_subs

my_subsは、自分が払っているサブスクの金額と請求日を管理するFlutterアプリです。対応OSはAndroidとiOSで、データは[shared_preferences](https://pub.dev/packages/shared_preferences)を使って端末に保存します。アプリ自身はデータをサーバーへ送りません。OSの[Android自動バックアップ](https://developer.android.com/identity/data/autobackup)やiCloudバックアップには、ほかのアプリのデータと同じく含まれます。

## できること

- サブスクを名前、カテゴリ、金額（円）、周期（毎月・3か月・半年・毎年）、初回請求日で登録します。
- 一覧画面には、今月の支払額、月額換算、年額換算の合計が出ます。初回請求日が未来の件は、請求が始まるまで換算合計に含めません。
- カレンダー画面は、請求日のある日に印を付けます。日付を押すと、その日に請求されるサブスクが下に並びます。
- 分析画面は、カテゴリごとの月額換算を横棒と割合で表示します。
- 請求日の当日、1日前、3日前、7日前のいずれかの9:00に通知を出せます。通知はOSの繰り返し予約で出すので、アプリを開かなくても毎回届きます。予約には[flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)を使っています。
- 初回請求日が未来の件は、開始前の3回分だけを単発で予約します。開始後に一度アプリを開くと、繰り返し予約へ切り替わります。iOSの予約上限（64件）に合わせて、全体を60件までに抑えています。
- Androidでは、一覧画面右上の「カレンダー」をオンにすると、請求日を端末のカレンダーにも繰り返しの予定として書き込みます。Androidでアプリを強制停止すると、アプリの通知の予約は消えます。カレンダーのリマインダーはカレンダー側が出すので、強制停止の影響を受けません。書き込むのは、どのアカウントにも属さない端末内のカレンダー「my_subs」です。予定のタイトルはサービス名だけで、金額は書きません。オンの間はアプリ自身の通知を止め、カレンダーへの書き込みに失敗するとアプリの通知に戻します。予定とリマインダーの書き込みには[device_calendar_plus](https://pub.dev/packages/device_calendar_plus)を使っています。

## 開発環境の準備

Flutter 3.47.7で開発しています。リポジトリを取得したら、git hookを有効にしてください。

```bash
flutter pub get
git config core.hooksPath .githooks
```

iOS実機向けにビルドするときは、Apple DeveloperのTeam IDを`ios/Flutter/DevelopmentTeam.xcconfig`に`DEVELOPMENT_TEAM = <Team ID>`の形で書きます。このファイルは`.gitignore`の対象です。Xcodeの署名画面でチームを選ぶと`project.pbxproj`にTeam IDが書き込まれてしまうので、署名画面での選択は避けてください。

pre-commitは、フォーマット、静的解析、テスト、カバレッジ80%以上の判定を順に実行します。pre-pushは接続中のAndroid端末でE2Eテストを実行するので、push前にエミュレータを起動しておいてください。GitHub Actionsのワークフローは、pushとpull requestごとに同じ検証を実行します。E2EテストはCIで実行せず、pre-pushだけで実行します。

## アプリアイコン

アイコンの元絵は`tool/icon/gen.py`の中にSVGとして書いてあります。`python3 tool/icon/gen.py`を実行すると、iOS用のIcon Composer形式（`ios/Runner/AppIcon.icon`）と、Android用のアダプティブアイコン（前景・背景・テーマ用モノクロ）および旧形式のPNGが作り直されます。実行には[librsvg](https://wiki.gnome.org/Projects/LibRsvg)の`rsvg-convert`が必要です。

## 候補チップのファイル

追加画面の上部には、よく使うサービスを選ぶ候補チップを出せます。候補は`assets/private/presets.json`に次の形式で書きます。

```json
[
  { "name": "サービス名", "category": "video", "intervalMonths": 1 }
]
```

`category`には`video`、`music`、`software`、`cloud`、`news`、`game`、`life`、`other`のいずれかを指定します。このファイルは個人の利用状況を含むため、`.gitignore`の対象です。誤って`git add -f`した場合も、pre-commitがcommitを止めます。ファイルが無いときは、候補チップを出さずにアプリが動作します。

## ライセンス

MIT Licenseで公開しています。全文は[LICENSE](LICENSE)を参照してください。
