# 0025. GitHub Actions 内 Docker image を tag と digest で固定する

## ステータス

Accepted

## 日付

2026-06-27

## 決定内容

`.github/workflows/**` の `run:` step で `docker run` する外部 Docker image は、原則として次の形式で固定する。

```text
image:tag@sha256:<manifest-list-or-index-digest>
```

tag は人間が確認する version / line を表し、digest は実際に pull する immutable な image 実体を固定する。digest には platform 個別 manifest digest ではなく、multi-arch manifest list / OCI image index の digest を使う。これにより、GitHub-hosted runner の architecture が将来変わっても、同じ image line の範囲で platform 解決できるようにする。

tag なし参照、特に `latest` 相当の参照は使わない。

今回の初期 pin では、version upgrade と digest pin を分離するため、原則として「現在 CI が実際に使っている image 実体」を固定する。既存の明示 tag は維持し、tag なしだった `curlimages/curl` だけは、確認時点の `latest` と同じ実体を指す `8.21.0` tag に置き換える。

現在有効な image 参照の正本は `.github/workflows/pr-check.yml`、運用上の棚卸しと更新手順の正本は [Quality Gates](../operations/quality-gates.md) とする。次の表は本 ADR 採択時点の初期 pin スナップショットであり、将来の更新で毎回 ADR を追記するものではない。

| 用途 | 変更前 | 初期 pin snapshot | 選定理由 | 確認コマンド |
|---|---|---|---|---|
| Docker smoke test DB | `postgres:16-alpine` | `postgres:16-alpine@sha256:e013e867e712fec275706a6c51c966f0bb0c93cfa8f51000f85a15f9865a28cb` | 既存 tag を維持する。PostgreSQL の line 変更は smoke test の前提を変えるため、今回は version upgrade せず現行 tag の digest だけを固定する。 | `docker buildx imagetools inspect postgres:16-alpine` |
| Docker smoke test health check | `curlimages/curl` | `curlimages/curl:8.21.0@sha256:7c12af72ceb38b7432ab85e1a265cff6ae58e06f95539d539b654f2cfa64bb13` | 既存は tag なしで実質 `latest` だった。確認時点の `latest` が `curl 8.21.0` で、`curlimages/curl:8.21.0` と digest が一致したため、現在の挙動を保ったまま `latest` drift を止める。 | `docker run --rm curlimages/curl --version`; `docker buildx imagetools inspect curlimages/curl:8.21.0` |
| ShellCheck CI | `koalaman/shellcheck:v0.11.0` | `koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d` | 既存 tag を維持する。ShellCheck version を上げると lint 結果が変わり得るため、今回は digest pin のみにする。pre-commit 側の ShellCheck 0.11 系とも揃える。 | `docker buildx imagetools inspect koalaman/shellcheck:v0.11.0` |
| Hadolint CI | `ghcr.io/hadolint/hadolint:v2.14.0` | `ghcr.io/hadolint/hadolint:v2.14.0@sha256:27086352fd5e1907ea2b934eb1023f217c5ae087992eb59fde121dce9c9ff21e` | 既存 tag を維持する。Hadolint version を上げると rule set や検出結果が変わり得るため、今回は digest pin のみにする。pre-commit の Hadolint tag とも揃える。 | `docker buildx imagetools inspect ghcr.io/hadolint/hadolint:v2.14.0` |

`docker build` で使う application image の base image（例: `Dockerfile` の `FROM node:24-alpine`）は今回の対象に含めない。base image 更新は application runtime や dependency update の影響を持つため、Renovate 導入を扱う [Issue #350](https://github.com/kmryst/terraform-hannibal/issues/350) などで別途管理する。

## 背景

[ADR 0017](./0017-pin-github-actions-by-owner-tier.md) では、`.github/workflows/**` の `uses:` action を GitHub-owned / non-GitHub-owned の owner tier で固定する方針を決めた。

一方、`run:` step 内の `docker run` は GitHub Actions の `uses:` ではないため、ADR 0017 の対象外だった。`pr-check.yml` には Docker smoke test、ShellCheck、Hadolint のために外部 Docker image を直接 pull して実行する箇所があり、特に `curlimages/curl` は tag なし参照だった。

tag なし参照や tag のみ参照は、workflow ファイルの diff なしに実行される image 実体が変わる。これは CI の再現性を下げ、supply chain risk のレビュー面でも GitHub Action pin 方針と差が出る。

## 検討した選択肢

### ADR 0017 を拡張する

- 長所: GitHub Actions 内の supply chain 方針を 1 つの ADR にまとめられる
- 短所: ADR 0017 は `uses:` action の owner tier、Dependency graph、Dependabot alerts/security updates の扱いに特化している。`run:` step の Docker image は owner tier では分類しにくく、更新手段も Docker registry / Renovate / 手動確認になるため、同じ ADR に入れると責務が広がる

### tag のみで固定する

- 長所: 読みやすく、更新も簡単
- 長所: `latest` や tag なし参照よりは drift を抑えられる
- 短所: tag は registry 側で再ポイントされ得るため、実行される image 実体を immutable には固定できない

### digest のみで固定する

- 長所: 実行される image 実体を immutable に固定できる
- 短所: 人間が見たときに version line が分からず、review や更新判断が難しい
- 短所: 更新 PR の diff だけでは何の version に追従したのか読みづらい

### tag と digest の両方で固定する（採択）

- 長所: tag で意図する version line を示し、digest で実行される image 実体を固定できる
- 長所: review 時に「どの version を使うつもりか」と「実際に pull される実体」を両方確認できる
- 短所: tag と digest の対応がずれると混乱するため、更新時に `docker buildx imagetools inspect` などで対応確認が必要

## 採択理由

GitHub Actions の `run:` step で実行する外部 Docker image は、CI 上で任意の code を実行する supply chain dependency である。`uses:` action と同様に、PR の diff なしに実行内容が変わる状態は避けるべきである。

tag のみでは image 実体を immutable に固定できず、digest のみでは review 時の意図が読み取りにくい。そのため `image:tag@sha256:<digest>` を採用し、tag と digest の対応を docs と PR review で確認する。

初期 pin では、CI 挙動の変化を避けるため version upgrade は行わない。今回の目的は「現在使われている実体を固定し、今後の変更を PR diff として見えるようにすること」であり、各 tool / service image の upgrade 判断は別 PR で扱う。

## 影響

- `pr-check.yml` の Docker smoke test、ShellCheck、Hadolint は外部 image の silent drift を受けにくくなる
- `curlimages/curl` は tag なし `latest` 相当から明示 tag + digest へ変わる
- image 更新時は tag と manifest list / index digest の対応確認が必要になる
- Docker image digest は Dependabot alerts / security updates の対象としては扱いづらいため、当面は手動確認で補完する
- Renovate 導入時は、workflow 内 Docker image の tag / digest を regex manager などで更新対象にできるか検討する

## 関連

- [Issue #430](https://github.com/kmryst/terraform-hannibal/issues/430) - GitHub Actions 内 Docker image の tag / digest pin 方針を整理する
- [Issue #350](https://github.com/kmryst/terraform-hannibal/issues/350) - Renovate 導入と Dockerfile base image 更新管理
- [ADR 0017](./0017-pin-github-actions-by-owner-tier.md) - GitHub Actions の action 参照を owner tier で固定する
- [ADR 0024](./0024-use-pre-commit-and-ci-dual-layer-for-shell-dockerfile-lint.md) - ShellCheck / Hadolint を pre-commit と CI の二層で実行する
- [Quality Gates](../operations/quality-gates.md) - workflow Docker image 管理方針、現在の棚卸し、更新手順の正本
- [Threat Model](../security/threat-model.md) - T10 supply chain / GitHub Action 依存の侵害
