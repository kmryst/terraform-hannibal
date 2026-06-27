# 0024. シェルスクリプト / Dockerfile の lint を pre-commit と CI の二層で実行する

## ステータス

Accepted

## 日付

2026-06-27

## 決定内容

ShellCheck / Hadolint を pre-commit フックと CI（`pr-check.yml`）の両方に組み込み、二層で実行する。

- pre-commit: ローカルコミット時に即時フィードバックを返す
- CI: PR 上で全開発者に対して強制実行し、検出時に job fail させる

shfmt は formatter のため CI には追加せず pre-commit のみとする（この判断はスコープ外）。

## 背景

Issue #426 で `scripts/**/*.sh`（4 本）と `Dockerfile` の静的解析を導入した。
それ以前は lint なしでコミットできる状態であり、pre-commit / CI のチェックが空白だった。

lint を追加するにあたり、どの層に置くかを検討する必要があった。

## 検討した選択肢

### pre-commit のみ（不採択）

- 長所: ローカルで即座にフィードバックが得られ、CI のキュー待ちが不要
- 短所: `git commit --no-verify` で hook を意図的にスキップできる
- 短所: `pre-commit install` を実行していない開発者には hook が存在しない
- 短所: GitHub Actions 環境では pre-commit は実行されず、CI として機能しない

### CI のみ（不採択）

- 長所: push / PR 作成後に全員へ強制される
- 長所: ローカル環境のセットアップ状態に左右されない
- 短所: コミット後に push するまでフィードバックが来ない
- 短所: ローカルで即座に気づける問題を CI まで引っ張るため、手戻りが大きい

### pre-commit と CI の両方（採択）

- 長所: ローカルでの早期発見（速さ）と CI による強制実行（確実性）を両立できる
- 長所: `--no-verify` や install 忘れによる抜け穴を CI が補完する
- 短所: 同じ check を二か所に定義するため、設定の同期を維持する必要がある

## 採択理由

pre-commit と CI はそれぞれ異なる問題を解決する。

pre-commit はローカルで即座にフィードバックを返すが、強制力がない。
CI は全員に強制するが、フィードバックが push 後になる。

どちらか一方では「速いが抜け穴がある」か「確実だが遅い」になる。
二層にすることで速さと強制力を両立できる。

なお、ShellCheck / Hadolint は初期導入時点で branch protection の required status check には追加しない。観察期間後に false positive・実行時間・merge blocking にする価値を確認してから判断する（ADR 0013 の方針に従う）。

## 影響

- lint の設定変更は `.pre-commit-config.yaml` と `pr-check.yml` の両方を更新する必要がある
- ルールを追加・変更した場合は、既存スクリプト / Dockerfile がパスすることを両層で確認する
- ShellCheck / Hadolint の required 化判断は ADR 0013 の方針に従い、別 Issue で実施する

## 関連

- [Issue #426](https://github.com/kmryst/terraform-hannibal/issues/426) - ShellCheck / shfmt / Hadolint 導入
- [ADR 0013](./0013-promote-quality-checks-to-required-gradually.md) - 品質チェックを観察期間後に段階的 required 化する
- [Quality Gates](../operations/quality-gates.md) - PR 品質ゲートと required 化判断の正本
