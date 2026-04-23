# Architecture Diagram Automation History

AWS 構成図の自動生成に関する履歴メモです。

## Summary

This repository previously contained a GitHub Actions workflow intended to regenerate the AWS architecture diagram automatically.

このリポジトリには以前、AWS 構成図を GitHub Actions で自動再生成するための Workflow がありました。

- Removed workflow: `.github/workflows/architecture-diagram.yml`
- Current diagram sources:
  - `docs/architecture/aws/cacoo/architecture.svg`
  - `docs/architecture/aws/diagrams/latest.png`
- Current manual generation scripts:
  - `scripts/diagrams/generate_aws_diagram.py`
  - `scripts/diagrams/README.md`

- 削除した Workflow: `.github/workflows/architecture-diagram.yml`
- 現在の構成図ソース:
  - `docs/architecture/aws/cacoo/architecture.svg`
  - `docs/architecture/aws/diagrams/latest.png`
- 現在の手動生成スクリプト:
  - `scripts/diagrams/generate_aws_diagram.py`
  - `scripts/diagrams/README.md`

## Why The Workflow Was Removed

The workflow had drifted away from the current repository layout and was no longer runnable.

この Workflow は現在のリポジトリ構成からずれてしまっており、もはや実行できない状態でした。

It referenced paths and outputs that do not exist anymore:

参照していたパスと出力先は、すでに存在しないものになっていました。

- `infrastructure/diagrams/requirements.txt`
- `infrastructure/diagrams/generate_diagram.py`
- `docs/architecture.svg`

The current repository uses different paths:

現在のリポジトリで使われている正しいパスは以下です。

- `scripts/diagrams/requirements.txt`
- `scripts/diagrams/generate_aws_diagram.py`
- `docs/architecture/aws/cacoo/architecture.svg`
- `docs/architecture/aws/diagrams/latest.png`

Because of that mismatch, keeping the workflow around would suggest automation exists when it does not.

この不一致があるまま Workflow を残すと、実際には存在しない自動化が動いているように見えてしまいます。

## Historical Intent

The original intent appears to have been:

もともとの狙いは、次のようなものだったと考えられます。

1. Install Python + Graphviz in GitHub Actions.
2. Run a Diagrams-based script to generate an AWS architecture diagram.
3. Commit the generated artifact back to the repository automatically.

1. GitHub Actions 上で Python と Graphviz をセットアップする。
2. Diagrams ベースのスクリプトを実行して AWS 構成図を生成する。
3. 生成物をリポジトリへ自動コミットして戻す。

That idea is still reasonable, but it should be rebuilt against the current `scripts/diagrams/` structure rather than restored as-is.

この考え方自体は今でも妥当ですが、そのまま復活させるのではなく、現在の `scripts/diagrams/` 構成に合わせて作り直すべきです。

## Recommended Future Approach

If automation is needed again, recreate it with the current script layout and decide on a single published artifact for README usage.

将来また自動化が必要になったら、現在のスクリプト配置に合わせて作り直し、README で使う公開用の成果物を 1 つに決めるのがよいです。

Suggested steps:

おすすめの進め方は次の通りです。

1. Define the canonical output file for README consumption.
2. Make `scripts/diagrams/generate_aws_diagram.py` write that file deterministically.
3. Reintroduce a workflow only after the script path, output path, and commit target are aligned.

1. README で参照する正本の出力ファイルを決める。
2. `scripts/diagrams/generate_aws_diagram.py` がそのファイルを決定的に出力するようにする。
3. スクリプトの場所、出力先、コミット対象が揃ってから Workflow を再導入する。
