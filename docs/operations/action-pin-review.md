# GitHub Actions action pin の運用確認（Issue #356）

[ADR 0017](../adr/0017-pin-github-actions-by-owner-tier.md) で決定した Tier A / Tier B 方針について、Dependabot 関連のリポジトリ設定を有効化し、現在 `.github/workflows` で使用している action の pin 状態と advisory を確認した記録です。

## 確認日

2026-06-10

## 1. リポジトリ設定（Dependency graph / Dependabot alerts / security updates）

2026-06-07・2026-06-10 の確認時点では `kmryst/terraform-hannibal` の Dependabot alerts / vulnerability alerts および Dependabot security updates が disabled だった。本 Issue 対応で API 経由 (`PUT /repos/{owner}/{repo}/vulnerability-alerts`, `PUT /repos/{owner}/{repo}/automated-security-fixes`) で有効化し、以下の状態を確認した。

| 項目 | 確認方法 | 結果 |
|---|---|---|
| Dependency graph | `GET /repos/{owner}/{repo}/dependency-graph/sbom` | 有効。SBOM に 1,143 packages が含まれる（vulnerability-alerts 有効化前は 404） |
| Dependabot alerts / vulnerability alerts | `GET /repos/{owner}/{repo}/vulnerability-alerts` → 204、`GET /repos/{owner}/{repo}/dependabot/alerts` → 200 | 有効。open alert は npm 依存で 65 件、github-actions ecosystem の alert は 0 件。本ドキュメントでは action pin の確認を対象とし、npm 依存の alert は対象外とする |
| Dependabot security updates | `GET /repos/{owner}/{repo}/automated-security-fixes` → `{"enabled":true,"paused":false}`、`security_and_analysis.dependabot_security_updates.status` → `enabled` | 有効 |

3 項目とも有効化できたため、代替運用の検討は不要。

## 2. action 一覧と Tier 分類

`.github/workflows/**` の `uses:` を棚卸しし、ADR 0017 の基準（GitHub-owned = Tier A、それ以外 = Tier B）で分類した。すべて ADR 0017 の固定形式（Tier A: `@vX.Y.Z`、Tier B: `@<full-length-sha> # vX.Y.Z`）に沿っている。

### Tier A（GitHub-owned、`@vX.Y.Z`、Dependabot alerts 対象）

| Action | Pin | 利用 workflow |
|---|---|---|
| `actions/checkout` | `v6.0.3` | 全 workflow |
| `actions/setup-node` | `v6.4.0` | `pr-check.yml`, `deploy.yml` |
| `actions/upload-artifact` | `v7.0.1` | `pr-check.yml` |
| `actions/github-script` | `v9.0.0` | `issue-template-check.yml` |
| `github/codeql-action/init` `/autobuild` `/analyze` `/upload-sarif` | `v4.36.2` | `security-scan.yml` |

### Tier B（non-GitHub-owned、`@<sha> # vX.Y.Z`、Dependabot alerts 対象外）

| Action | Pin (`@<sha> # vX.Y.Z`) | 利用 workflow |
|---|---|---|
| `aws-actions/configure-aws-credentials` | `e7f100cf4c008499ea8adda475de1042d6975c7b # v6.2.0` | `deploy.yml`, `destroy.yml`, `pr-check.yml` |
| `hashicorp/setup-terraform` | `dfe3c3f87815947d99a8997f908cb6525fc44e9e # v4.0.1` | `deploy.yml`, `destroy.yml`, `pr-check.yml` |
| `aws-actions/amazon-ecr-login` | `fa648b43de3d4d023bcb3f89ed6940096949c419 # v2.1.5` | `deploy.yml` |
| `terraform-linters/setup-tflint` | `b480b8fcdaa6f2c577f8e4fa799e89e756bb7c93 # v6.2.2` | `pr-check.yml` |
| `aquasecurity/trivy-action` | `ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0` | `pr-check.yml`, `security-scan.yml` |
| `docker/setup-buildx-action` | `d7f5e7f509e45cec5c76c4d5afdd7de93d0b3df5 # v4.1.0` | `security-scan.yml` |
| `docker/build-push-action` | `f9f3042f7e2789586610d6e8b85c8f03e5195baf # v7.2.0` | `security-scan.yml` |
| `micnncim/action-label-syncer` | `3abd5ab72fda571e69fffd97bd4e0033dd5f495c # v1.3.0` | `sync-labels.yml` |

## 3. Tier B の SHA と `# vX.Y.Z` の対応確認

各 action について `git ls-remote <repo> refs/tags/<vX.Y.Z> refs/tags/<vX.Y.Z>^{}` で、コメントの tag が指す commit と `uses:` の SHA が一致するかを確認した（`^{}` は annotated tag の dereference）。

| Action | `# vX.Y.Z` が指す commit | `uses:` の SHA | 一致 |
|---|---|---|---|
| `aws-actions/configure-aws-credentials` (v6.2.0, lightweight tag) | `e7f100cf4c008499ea8adda475de1042d6975c7b` | `e7f100cf4c008499ea8adda475de1042d6975c7b` | ✅ |
| `hashicorp/setup-terraform` (v4.0.1, lightweight tag) | `dfe3c3f87815947d99a8997f908cb6525fc44e9e` | `dfe3c3f87815947d99a8997f908cb6525fc44e9e` | ✅ |
| `aws-actions/amazon-ecr-login` (v2.1.5, annotated tag) | `fa648b43de3d4d023bcb3f89ed6940096949c419` | `fa648b43de3d4d023bcb3f89ed6940096949c419` | ✅ |
| `terraform-linters/setup-tflint` (v6.2.2, lightweight tag) | `b480b8fcdaa6f2c577f8e4fa799e89e756bb7c93` | `b480b8fcdaa6f2c577f8e4fa799e89e756bb7c93` | ✅ |
| `aquasecurity/trivy-action` (v0.36.0, annotated tag) | `ed142fd0673e97e23eac54620cfb913e5ce36c25` | `ed142fd0673e97e23eac54620cfb913e5ce36c25` | ✅ |
| `docker/setup-buildx-action` (v4.1.0, lightweight tag) | `d7f5e7f509e45cec5c76c4d5afdd7de93d0b3df5` | `d7f5e7f509e45cec5c76c4d5afdd7de93d0b3df5` | ✅ |
| `docker/build-push-action` (v7.2.0, lightweight tag) | `f9f3042f7e2789586610d6e8b85c8f03e5195baf` | `f9f3042f7e2789586610d6e8b85c8f03e5195baf` | ✅ |
| `micnncim/action-label-syncer` (v1.3.0, lightweight tag) | `3abd5ab72fda571e69fffd97bd4e0033dd5f495c` | `3abd5ab72fda571e69fffd97bd4e0033dd5f495c` | ✅ |

8 件すべて一致を確認した。

## 4. Advisory 確認（GitHub Advisory Database）

`GET /advisories?ecosystem=actions&affects=<owner>/<repo>` で、利用中の全 action（Tier A / Tier B）について advisory を確認した。

| Action | 該当 advisory | 影響範囲 / patched | 現在の pin への影響 |
|---|---|---|---|
| `actions/checkout`, `actions/setup-node`, `actions/upload-artifact`, `actions/github-script` | なし | - | - |
| `github/codeql-action/*` | [GHSA-vqf5-2xx6-9wfm](https://github.com/advisories/GHSA-vqf5-2xx6-9wfm)（high, 2025-01-24, "GitHub PAT written to debug artifacts"） | `>= 3.26.11, <= 3.28.2` および `>= 2.26.11, < 3.0.0`。patched: `3.28.3` | 現在 pin は `v4.36.2`（v4系）であり影響範囲外。対応不要 |
| `aws-actions/configure-aws-credentials`, `hashicorp/setup-terraform`, `aws-actions/amazon-ecr-login`, `terraform-linters/setup-tflint`, `docker/setup-buildx-action`, `docker/build-push-action`, `micnncim/action-label-syncer` | なし | - | - |
| `aquasecurity/trivy-action` | [GHSA-69fq-xp46-6x23](https://github.com/advisories/GHSA-69fq-xp46-6x23)（critical, 2026-03-24, "Trivy ecosystem supply chain was briefly compromised"）、[GHSA-9p44-j4g5-cfx5](https://github.com/advisories/GHSA-9p44-j4g5-cfx5)（medium, 2026-02-18, "script injection via sourced env file"） | 下記「4-1」参照 | 下記「4-1」参照。対応不要（根拠を記録） |

### 4-1. `aquasecurity/trivy-action` の詳細確認

2026-03-19〜20 に `aquasecurity/trivy-action` の version tag 76/77 が攻撃者によって force-push され、infostealer を含む commit に書き換えられるサプライチェーン事案が発生した（[GHSA-69fq-xp46-6x23](https://github.com/advisories/GHSA-69fq-xp46-6x23)）。同時期に Trivy 本体 v0.69.4 の悪性リリースも発生している。本リポジトリは `aquasecurity/trivy-action` を Tier B として SHA pin しているため、以下を確認した。

- **`GHSA-69fq-xp46-6x23`**: `aquasecurity/trivy-action` の影響範囲は `< 0.35.0`、patched は `0.35.0`。現在の pin は `v0.36.0` であり version 上は影響範囲外。
  - pin 先 commit `ed142fd0673e97e23eac54620cfb913e5ce36c25` の commit 日時は **2026-04-22**（commit message: `chore: update action version to v0.36.0 in examples (#563)`）であり、攻撃が発生した 2026-03-19〜20 より後に作成された commit である。攻撃時に force-push された悪性 commit ではないことを確認した。
- **`GHSA-9p44-j4g5-cfx5`**: 影響範囲は `>= 0.31.0, < 0.34.0`、patched は `0.34.0`。現在の pin (`v0.36.0`) は範囲外。pin 先の `action.yaml` で `set_env_var_if_provided` が `printf 'export %s=%q\n'`（`%q` による shell escape）を使用していることを確認し、当該脆弱性の修正が反映されていることを確認した。
- **transitive action / default tool version の確認**: pin 先の `action.yaml` は `aquasecurity/setup-trivy@3fb12ec12f41e471780db15c232d5dd185dcb514 # v0.2.6` を内部で呼び出し、`version` input のデフォルトは `v0.70.0`（Trivy 本体のバージョン）。本リポジトリの 3 箇所の `trivy-action` 呼び出し（`pr-check.yml`, `security-scan.yml` x2）はいずれも `version` input を指定していないため、このデフォルトが使われる。
  - `aquasecurity/setup-trivy@3fb12ec1...` の commit 日時は **2026-01-15**（攻撃発生前）であり、現時点で `refs/tags/v0.2.6` が指す commit と一致する。`v0.2.6` は advisory が "Safe Version" として明示する setup-trivy のバージョンである。
  - Trivy 本体 `v0.70.0` は **2026-04-17** 公開（攻撃発生後）であり、`GHSA-69fq-xp46-6x23`（影響範囲 `= 0.69.4` のみ）・`GHSA-xcq4-m2r3-cmrj`（影響範囲 `< 0.51.2`）のいずれの影響範囲にも該当しない。

以上より、現在の `aquasecurity/trivy-action` pin（action 本体・transitive の `setup-trivy`・default の Trivy バージョンすべて）は active advisory の影響範囲外であり、known-safe な commit / version への差し替えは不要と判断した。

## 5. `.github/dependabot.yml` の確認

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:15"
      timezone: "Asia/Tokyo"
    open-pull-requests-limit: 5
    groups:
      github-actions:
        patterns:
          - "*"
```

全 action を 1 つの group にまとめ、週次・最大 5 PR で version updates を行う設定になっている。Tier A（semver tag 更新）・Tier B（SHA + コメント更新）のいずれも `package-ecosystem: github-actions` の version updates 対象であり、現在の groups / open-pull-requests-limit で運用上の支障はないため変更不要と判断した。

## 6. Tier B の Dependabot version update PR レビュー手順

Tier B action（`@<sha> # vX.Y.Z`）の Dependabot version update PR をレビューする際は、以下を確認する。

1. **SHA とコメントの対応確認**: `git ls-remote <repo> refs/tags/<新 vX.Y.Z> refs/tags/<新 vX.Y.Z>^{}` で、PR が更新する `@<sha>` が `# vX.Y.Z` コメントの tag が指す commit と一致するか確認する（本ドキュメント section 3 と同じ手順）。
2. **release notes / changelog の確認**: 旧 version から新 version までの release notes / CHANGELOG を確認し、breaking change や挙動変更がないか確認する。
3. **GitHub Advisory Database / upstream advisory の確認**: `GET /advisories?ecosystem=actions&affects=<owner>/<repo>` で新しい advisory がないか確認する。`aquasecurity/trivy-action` のように transitive action / default tool version を持つ action は、その対応関係も再確認する（本ドキュメント section 4-1 と同様の手順）。
4. **workflow permissions / secrets / OIDC / artifact への影響確認**: action 更新によって `permissions`、利用する secrets、OIDC (`aws-actions/configure-aws-credentials` 等)、artifact の入出力仕様に変更がないか確認する。
5. **CI 結果確認**: `pr-check.yml` の実行結果を確認する。`deploy.yml` / `destroy.yml` / `security-scan.yml` のように PR で実行されない workflow を更新する場合は、必要に応じて `workflow_dispatch` で手動実行して確認する。

## 7. 次回以降の確認事項

- Tier B の `@<sha> # vX.Y.Z` が Dependabot version updates で追従更新されることを、次回の Dependabot PR（`github-actions` group）で確認する。確認時は本ドキュメント section 6 のレビュー手順を適用する。

## 関連

- [Issue #356](https://github.com/kmryst/terraform-hannibal/issues/356)
- [ADR 0017](../adr/0017-pin-github-actions-by-owner-tier.md)
- [Quality Gates - action バージョン管理方針](./quality-gates.md#action-バージョン管理方針)
- [Threat Model - T10](../security/threat-model.md)
