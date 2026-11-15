# 構成図のソースと作り直し手順

`docs/architecture/diagrams/` の構成図（`request-flow.drawio` / `.png`、`operations.drawio` / `.png`）を生成する作図スクリプトと、その元にした inventory を置く。
図の作り方を変えた経緯と旧方式との比較は [Architecture Diagram History](../../diagram-automation-history.md) を参照。

## ファイル

| パス | 内容 |
| --- | --- |
| `inventory.md` | リソース一覧と接続関係。各項目に根拠のファイルと行番号を付けた、作図の正本。図に描くかどうかと、その理由も書く |
| `diagram_common.py` | 共通定義。要素（名前・アイコン・説明）、グループ枠の名前、線（通信元・通信先・ラベル）、観点ごとの図で使う短いラベルと説明、drawio XML の生成器 |
| `build_architecture.py` | 全体図（`architecture.drawio`）を生成する。観点ごとの図の照合の基準（検証の正本）で、README には載せない |
| `build_request_flow.py` | 観点 request-flow の図（`../request-flow.drawio`）を生成する |
| `build_operations.py` | 観点 operations の図（`../operations.drawio`）を生成する |
| `architecture.drawio` | 全体図 |

## ラベル・要素を変えるとき

1. 構成を変えたら、まず `inventory.md` を IaC・workflow・アプリのコードに合わせて更新する
2. 要素名・説明・線のラベルは `diagram_common.py` で変える。全体図と観点ごとの図に同時に反映される。観点ごとのスクリプトで文言を上書きしない（図ごとに変えてよいのは改行の位置と、`diagram_common.py` の短いラベル・短い説明を使うかどうかだけ）
3. 配置（座標・線の経路・ラベルの位置）を変えるときは、その図の `build_*.py` だけを直す
4. 下の「生成」「PNG の書き出し」「検査」をすべて実行し、drawio・PNG をまとめてコミットする

## 必要なもの

| 用途 | 必要なもの |
| --- | --- |
| 生成 | Python 3（標準ライブラリだけ） |
| PNG の書き出し・一部の検査 | Node.js と [Playwright](https://playwright.dev/)（Chromium 入り）。書き出しはネットワーク接続も要る（draw.io の viewer のスクリプトとアイコン画像を取得する） |
| PNG の書き出しと検査のスクリプト | 作図の支援スクリプト一式（`export.js`、`check-*.py` ほか）。このリポジトリには含まない（作図に使った Claude Code の skill `architecture-diagram` の `scripts/`） |

以下のコマンドは、リポジトリの root で、次の 2 つの環境変数を設定してから実行する。

```bash
# 支援スクリプトのディレクトリ（export.js・check-*.py があるところ）
export DIAGRAM_SCRIPTS=/path/to/architecture-diagram/scripts
# Playwright の install 先。グローバルに入れた場合は次のとおり
#   npm install -g playwright && npx playwright install chromium
export PLAYWRIGHT_PATH="$(npm root -g)/playwright"
```

`PLAYWRIGHT_PATH` は、支援スクリプトの Node.js 部分（`export.js` と、SVG の描画位置を測る `dump-geometry.js`）が `require` する Playwright のパス。リポジトリ内に `node_modules/playwright` がある場合は不要。

## 生成

```bash
python3 -B docs/architecture/diagrams/src/build_architecture.py docs/architecture/diagrams/src/architecture.drawio
python3 -B docs/architecture/diagrams/src/build_request_flow.py docs/architecture/diagrams/request-flow.drawio
python3 -B docs/architecture/diagrams/src/build_operations.py docs/architecture/diagrams/operations.drawio
```

- 3 つは互いに依存しないので順序は問わない（上の順は全体図 → 観点ごとの図）
- 各スクリプトは出力先を引数で受け取る。同じ入力から同じ drawio をバイト単位で再現するので、別の場所に書き出して `cmp` で既存のファイルと比べられる
- `-B` は `src/__pycache__/` を作らないため

## PNG の書き出し

README には PNG を載せる（SVG は閲覧者の環境のフォントで文字を描くため、日本語の配置が崩れる）。
PNG は観点ごとの図だけをコミットする。SVG と全体図の PNG は検査用で、リポジトリの外（下の `$OUT`）に書き出す。

```bash
OUT=$(mktemp -d)
D=docs/architecture/diagrams
node "$DIAGRAM_SCRIPTS/export.js" "$D/request-flow.drawio" "$OUT/request-flow.svg" "$D/request-flow.png"
node "$DIAGRAM_SCRIPTS/export.js" "$D/operations.drawio" "$OUT/operations.svg" "$D/operations.png"
node "$DIAGRAM_SCRIPTS/export.js" "$D/src/architecture.drawio" "$OUT/architecture.svg" "$OUT/architecture.png"
```

`export.js` は、PNG の tEXt チャンク（キーワード `source-sha256`）に、元の `.drawio` のファイルの SHA-256 を入れる（入れるのはハッシュだけ）。
下の `check-publish.py` がこれを今の `.drawio` と比べるので、drawio を直して PNG を書き出し直し忘れると検査で見つかる。
draw.io desktop など別のツールで書き出した PNG にはこのチャンクが無く、照合できないという警告になる。

## 検査

上の「PNG の書き出し」と同じシェルで（`$OUT` と `$D` を使う）実行する。すべての検査が合格してからコミットする。

### 全体図との一致

```bash
python3 "$DIAGRAM_SCRIPTS/check-views.py" "$D/src/architecture.drawio" "$D/request-flow.drawio" "$D/operations.drawio" \
  --label-differs request-flow:e4,request-flow:e5,request-flow:db \
  --endpoint-differs operations:tf \
  --view-only operations:migration
```

観点ごとの図の線（通信元・通信先・ラベル）と要素名が、全体図の同じ id の cell と一致するかを見る。
合格の基準: `mismatches=0`（終了コード 0）で、`note:`（渡したのに使われなかった免除）が出ないこと。

意図して全体図と変えたもの（免除）は次の 5 件。免除を足す・消すときは、この表とコマンドを一緒に直す。

| 指定 | 違い | 理由 |
| --- | --- | --- |
| `--label-differs request-flow:e4` | ④ のラベルが「④ GraphQL の転送」（全体図は「④ GraphQL の要求の転送」） | README の幅（1000px）で最小 12px の文字を保つため、`diagram_common.py` の短いラベル（`SHORT_LABELS`）を使う |
| `--label-differs request-flow:e5` | ⑤ のラベルが「⑤ GraphQL の転送」（全体図は「⑤ GraphQL の要求の転送」） | 同上 |
| `--label-differs request-flow:db` | ECS → RDS のラベルが「routes の取得」（全体図は「routes の取得・migration」） | request-flow は地図表示のリクエストの流れの図なので migration を省く。migration は operations の `migration` の線で示す |
| `--endpoint-differs operations:tf` | GitHub Actions からの線を束ねた 1 本。終点が AWS Cloud 枠（全体図は Region 枠）で、ラベルが terraform apply・aws s3 sync・CreateInvalidation・RegisterTaskDefinition・aws s3 cp（AppSpec）・GetCanaryRuns | GitHub Actions からの線を 4 本に減らして読みやすくするため、全体図の 6 本（`tf`・`sync`・`inval`・`taskdef`・`appspec`・`canaryruns`）を 1 本に束ねた。CreateInvalidation の相手の CloudFront が Region の外にあるので、終点を AWS Cloud 枠にした |
| `--view-only operations:migration` | ECS → RDS の「migration」の線が全体図に無い | 全体図は同じ通信を `db`（routes の取得・migration）の 1 本で描く。operations では運用側の目的だけを書いた線にする |

### 番号付きの流れ

```bash
cat > "$OUT/expect.json" <<'JSON'
{"①": ["browser", "cloudfront"], "②": ["cloudfront", "s3_frontend"], "③": ["browser", "cloudfront"],
 "④": ["cloudfront", "alb"], "⑤": ["alb", "ecs"], "⑥": ["browser", "mapbox"]}
JSON
python3 "$DIAGRAM_SCRIPTS/check-flow.py" "$D/src/architecture.drawio" "$OUT/architecture.svg" "$OUT/expect.json"
python3 "$DIAGRAM_SCRIPTS/check-flow.py" "$D/request-flow.drawio" "$OUT/request-flow.svg" "$OUT/expect.json"
```

①〜⑥ の線が inventory の「番号を振る流れ」どおりの通信元 → 通信先で描かれ、描画された線の終点が通信先に届いているかを見る。
合格の基準: ①〜⑥ がすべて `OK`（終了コード 0）。番号を変えたときは `expect.json` も inventory に合わせて直す。

### ラベルの重なり

```bash
python3 "$DIAGRAM_SCRIPTS/check-label-overlap.py" "$OUT/request-flow.svg" "$D/request-flow.drawio"
python3 "$DIAGRAM_SCRIPTS/check-label-overlap.py" "$OUT/operations.svg" "$D/operations.drawio"
python3 "$DIAGRAM_SCRIPTS/check-label-overlap.py" "$OUT/architecture.svg" "$D/src/architecture.drawio"
```

書き出した SVG の描画位置で、ラベルどうし・ラベルと枠線・線・アイコンの重なり、ラベルどうしの接触、ラベルが矢印の先端を覆うことを見る。
合格の基準: 3 枚とも `overlaps=0`（終了コード 0）。矢印の先端の判定は境界に近い値なので、PNG を拡大して目視もする。

### README の幅での文字の大きさ

```bash
python3 "$DIAGRAM_SCRIPTS/check-min-font.py" "$D/request-flow.drawio" --png "$D/request-flow.png"
python3 "$DIAGRAM_SCRIPTS/check-min-font.py" "$D/operations.drawio" --png "$D/operations.png"
```

README の表示幅 1000px に縮小したときの最小の文字の大きさを計算する。
合格の基準: 2 枚とも 12px 以上（`OK`、終了コード 0）。図の幅 W に対して最小フォントが 12 × W / 1000 px 以上なら通る（例: 最小 19px なら W ≤ 1583px）。全体図は README に載せないので対象外。

### 公開可否と PNG の書き出し直し忘れ

```bash
python3 "$DIAGRAM_SCRIPTS/check-publish.py" "$D/request-flow.png" "$D/operations.png" \
  "$D/request-flow.drawio" "$D/operations.drawio" "$D/src/architecture.drawio"
```

drawio のラベル・属性と PNG のテキストチャンクから、公開リポジトリに載せるべきでない値（AWS account ID、ARN、メールアドレス、リソース ID など）を組み込みのパターンで探す。
PNG は、同じフォルダの同名の `.drawio` の SHA-256 と `source-sha256` を比べ、違えば古い PNG として検出する。

合格の基準: 検出が次の既知の 3 件だけで、古い PNG・`source-sha256` が無い PNG の警告が無いこと。

| 検出 | 件数 | 扱い |
| --- | --- | --- |
| AWS Region code（3 枚の Region 枠の名前） | 3 | 公開済み（Terraform の provider に書いてある）。枠名として表示する |

文書（`inventory.md` とこの README）も対象に加えると、次の 5 件が増える（2026-11-15 時点。どれも公開済みの値で、載せてよいと確認した）。この README には値そのものを書かない（書くとこの README も検出される）。

| 検出 | 件数 | どこにあるか |
| --- | --- | --- |
| AWS Region code | 2 | inventory の対象環境の説明と、CloudFront 用の Region の説明 |
| IPv4/CIDR | 1 | inventory の route table の説明（デフォルトルート） |
| URL | 2 | AWS の公式ドキュメント（inventory の根拠）、Playwright の公式サイト（この README） |

まだ公開していない値の一覧（deny list）は非公開の場所で管理し、このリポジトリには置かない。
deny list を渡さないと `--deny 未指定` の警告が出て、名前（リソース名など）は検出できない。その場合は、変更したファイルに tfvars の値・12 桁の数字・ARN・メールアドレスが無いことを `grep` でも確かめる。

### 検査が正しく落ちることの確認

検査スクリプトを変えたときや、初めて使う環境では、壊した版（リポジトリの外にコピーして作る）で終了コード 1 になることを確かめる。

- `check-views.py`: 観点ごとの図の線を 1 本、別の要素に付け替えた版
- `check-flow.py`: 番号付きの線の target を別の要素に付け替えた版
- `check-label-overlap.py`: ラベルを別のラベルに重ねた版
- `check-min-font.py`: `--min-px 100` を付けて実行
- `check-publish.py`: `source-sha256` を別の値に書き換えた PNG（古い PNG として検出される）
