# Architecture Diagram Automation History

AWS 構成図の作り方の履歴メモです。

## 現在の構成図（2026-11-14 以降）

README の構成図は、観点（view）ごとの draw.io の図 2 枚です（[#718](https://github.com/kmryst/terraform-hannibal/issues/718)）。

| パス | 中身 |
| --- | --- |
| `docs/architecture/diagrams/request-flow.drawio` / `.png` | リクエストの流れ（地図表示 1 回分。番号 ①〜⑥） |
| `docs/architecture/diagrams/operations.drawio` / `.png` | デプロイ・監視・監査・Game Day・バックアップ |
| `docs/architecture/diagrams/src/inventory.md` | リソース一覧と接続関係。各項目に根拠のファイルと行番号を付けた、作図の正本 |
| `docs/architecture/diagrams/src/architecture.drawio` | 全体図（検証の正本。README 用の図はここから観点ごとに切り出す） |
| `docs/architecture/diagrams/src/diagram_common.py` | 要素・枠名・線のラベルの共通定義と drawio XML の生成 |
| `docs/architecture/diagrams/src/build_*.py` | 全体図・観点ごとの図を生成するスクリプト |

### 図の作り直し方

1. 構成を変えたら、まず `src/inventory.md` を IaC・workflow・アプリのコードに合わせて更新する
2. 要素名・ラベルは `src/diagram_common.py` で変え、図ごとのスクリプトで上書きしない
3. drawio を生成する（Python 3 の標準ライブラリだけで動く）

    ```bash
    cd docs/architecture/diagrams/src
    python3 -B build_architecture.py architecture.drawio
    python3 -B build_request_flow.py ../request-flow.drawio
    python3 -B build_operations.py ../operations.drawio
    ```

4. PNG は draw.io で書き出す（draw.io desktop の export、または draw.io viewer を Chromium で描画してスクリーンショットする）。README には PNG を載せる。SVG は閲覧者の環境のフォントで文字を描くため、日本語の配置が崩れる
5. 全体図と観点ごとの図で、要素・線・ラベルが inventory と一致しているかを確認する

## 作り方を変えた理由とトレードオフ（#718）

旧方式は、Python の [Diagrams](https://diagrams.mingrammer.com/) で書いた `scripts/diagrams/generate_aws_diagram.py` が 1 枚の全体図（`docs/architecture/aws/diagrams/latest.png`）を生成し、README は Cacoo で描いた `docs/architecture/aws/cacoo/architecture.svg` を表示していました。

新方式は、IaC・workflow・アプリのコードを調査して根拠付きの inventory を作り、それを元に draw.io の全体図と観点ごとの図をスクリプトで生成し、全体図と inventory の一致を検証してから README に載せます。

| 観点 | 旧方式（Diagrams による自動生成 / Cacoo） | 新方式（inventory + draw.io + 検証） |
| --- | --- | --- |
| 手軽さ | スクリプト 1 本で生成でき、手軽 | inventory の更新と検証の手間がかかる |
| 正確さ | 要素と線は手で書いたもので、IaC との対応を確かめる仕組みが無かった。実際に、Cacoo の図には ADR 0003 で S3 lockfile に移行した DynamoDB が残り、CloudWatch Synthetics・AWS FIS・Amazon SNS・AWS CloudTrail などが無かった。Diagrams のスクリプトには VPC・subnet・CodeDeploy・監視が無く、`Route53 >> CloudFront` のように通信の向きを表さない線があった | inventory の各項目に根拠のファイルと行番号があり、図と突き合わせて検証できる |
| 可読性 | 自動レイアウトのため線の重なりや配置を制御しにくい。1 枚に全要素が入る | 配置とラベルを明示し、README の幅で読める文字の大きさにしている |
| 観点 | 全体図 1 枚だけ | リクエストの流れと、デプロイ・監視・監査などの運用を分けた 2 枚。番号付きの流れを本文と対応させられる |
| 自動化 | GitHub Actions での再生成を試みたが、パスがずれて動かなくなり削除した（下記） | 生成はスクリプトで再現できる（同じ入力から同じ drawio）。CI での自動再生成はしない |

## 削除した旧資産（#718）

次のファイルを削除しました。削除前の状態は commit `c3c9501` で参照できます（例: `git show c3c9501:docs/architecture/aws/cacoo/architecture.svg`）。

- `docs/architecture/aws/cacoo/`（3 ファイル: `architecture.svg` と画像 2 つ。追加は `9e8cea7`）
- `docs/architecture/aws/diagrams/`（21 ファイル: `latest.png` とタイムスタンプ付きの PNG 20 枚。追加は `9e8cea7`）
- `scripts/diagrams/`（5 ファイル: `generate_aws_diagram.py`、`check_image_size.py`、`requirements.txt`、`setup.ps1`、`README.md`。最初の追加は `217f817`）

削除した理由:

- 図の内容が現行の構成と合っていなかった
- `generate_aws_diagram.py` の出力先が `docs/architecture/diagrams/` で、新しい図の置き場所と重なる。残すと、実行したときに旧形式の画像が新しい図と混ざる。README のキャッシュバスターを書き換える処理もあった
- `check_image_size.py` は存在しないパスを参照していた

## 旧方式の自動生成 workflow を削除した経緯

This repository previously contained a GitHub Actions workflow intended to regenerate the AWS architecture diagram automatically.

このリポジトリには以前、AWS 構成図を GitHub Actions で自動再生成するための Workflow がありました。

- Removed workflow: `.github/workflows/architecture-diagram.yml`
- 削除した Workflow: `.github/workflows/architecture-diagram.yml`

The workflow had drifted away from the repository layout and was no longer runnable. It referenced paths and outputs that did not exist anymore:

この Workflow はリポジトリ構成からずれてしまっており、実行できない状態でした。参照していたパスと出力先は、すでに存在しないものになっていました。

- `infrastructure/diagrams/requirements.txt`
- `infrastructure/diagrams/generate_diagram.py`
- `docs/architecture.svg`

At that time, the scripts and outputs had moved to `scripts/diagrams/` and `docs/architecture/aws/` (both removed in #718). Keeping the workflow would have suggested automation exists when it does not.

当時のスクリプトと出力先は `scripts/diagrams/` と `docs/architecture/aws/` に移っていました（どちらも #718 で削除）。Workflow を残すと、実際には存在しない自動化が動いているように見えてしまうため削除しました。

The original intent was to install Python + Graphviz in GitHub Actions, run a Diagrams-based script, and commit the generated artifact back to the repository automatically.

もともとの狙いは、GitHub Actions 上で Python と Graphviz をセットアップし、Diagrams ベースのスクリプトで AWS 構成図を生成して、生成物をリポジトリへ自動コミットすることでした。#718 で作り方を変えたため、この方式の自動化は再導入しません。
