# 0017. GitHub Actions の action 参照を owner tier で固定する（GitHub-owned は semver tag / 外部は SHA pin）

## ステータス

Accepted

## 日付

2026-06-07

## 決定内容

`terraform-hannibal` の `.github/workflows` における action 参照を、owner の trust boundary で 2 tier に分けて固定する。

- **Tier A: GitHub-owned actions**（`actions/*`, `github/codeql-action/*`）
  - `@vX` 浮動メジャータグは使用しない
  - `@vX.Y.Z` の semver patch tag に固定する
  - Dependabot alerts / security updates / version updates を維持する
  - SHA pin はしない
- **Tier B: non-GitHub-owned actions**（`aws-actions/*`, `docker/*`, `hashicorp/*`, `aquasecurity/*`, `terraform-linters/*`, `micnncim/*`、その他 GitHub-owned でない外部 action）
  - `@vX` 浮動メジャータグは使用しない
  - `uses: owner/action@<full-length-sha> # vX.Y.Z` の形式で固定する
  - full-length SHA は、同一行コメントの `vX.Y.Z` tag が指す commit SHA と一致させる
  - Dependabot version updates で SHA と同一行コメントを更新する
  - Dependabot alerts が効かなくなる点を明示的に受容する

`@vX` メジャータグは原則使わない。**具体的な action の version / SHA は本 ADR では固定せず、後続の実装 PR で決定する。**

## 背景

- 現状は `.github/workflows` の多くの action が `@vX` 浮動メジャータグを使っている（例外として `aquasecurity/trivy-action` は既にフルパッチ tag で固定されている）。
- `@vX` は、workflow ファイルを変更しないまま実行される action の中身が変わる。実行内容の変化が PR の diff として可視化されない。
- GitHub Docs では、action を immutable release として使う唯一の方法は full-length commit SHA への pin だと説明されている。semver tag（`@vX` も `@vX.Y.Z` も）は可変参照であり、削除・再ポイントで移動され得る。2025 年の `tj-actions/changed-files` 事案は、広く使われた外部 action のタグが過去に遡って悪性 commit へ移動された例である。
- OpenSSF Scorecard の Pinned-Dependencies でも、GitHub Actions などの build dependency を hash / SHA で pin する方向が示されている。
- 一方で、GitHub Actions の Dependabot alerts は semantic versioning を使う action に対して生成され、SHA pin された action には生成されない。SHA pin は改ざん耐性を上げるが Dependabot alerts を失うトレードオフがある。
- `uses: owner/action@<full-length-sha> # vX.Y.Z` 形式にすれば、Dependabot version updates は SHA と同一行コメント上のバージョンを更新できる。version updates は定期更新であり脆弱性通知である alerts の代替ではないが、alert を失っても version drift を追従し続ける補完手段になる。
- 本判断は `docs/security/threat-model.md` の T10（supply chain / GitHub Action 依存の侵害）が予告した「改ざんリスクが高まった場合は SHA pin を検討する」というエスカレーション条件に対応する。
- `docs/operations/quality-gates.md` の「action バージョン管理方針」は本 ADR の方針に合わせて更新した。

## 検討した選択肢

### 全 action を `@vX` のまま維持する

- 長所: 運用が最も軽く、patch / minor を自動吸収できる
- 短所: 実行内容が PR なしに変わる。外部 action のタグ移動・改ざんに無防備で、threat-model T10 のエスカレーション条件に応えられない

### 全 action を `@vX.Y.Z` に固定する

- 長所: 実行内容のサイレント変化を止め、更新を Dependabot PR として可視化できる。全 action で Dependabot alerts を維持できる
- 短所: semver patch tag も可変参照であり immutable 参照ではないため、外部 action の改ざん耐性は本質的に高まらない。OpenSSF Scorecard Pinned-Dependencies も満たさない

### 全 action を SHA pin する

- 長所: 改ざん耐性が最も高く、OpenSSF Scorecard Pinned-Dependencies の方向性とも最も整合する
- 短所: GitHub-owned を含む全 action で Dependabot alerts を失う。trust boundary が最も高い GitHub-owned の alert（CodeQL を含む）まで捨てるのは過剰

### action ごとに個別判断する

- 長所: action の権限・信頼度に応じて最適化できる
- 短所: 「大手ベンダーだから semver」「権限が強いから SHA」などの判断が増え、action 追加時の運用負荷と判断ブレが大きい

### GitHub-owned / non-GitHub-owned の 2 tier 方針（採択）

- 長所: 「GitHub-owned 以外は SHA pin」という単純なルールで運用・レビュー・監査を簡潔にできる
- 長所: GitHub-owned は alert 価値が高く改ざん確率が低いため alerts を残し、外部 action は改ざん耐性を優先できる
- 長所: non-GitHub-owned actions について OpenSSF Scorecard の Pinned-Dependencies の方向性と整合しやすい
- 短所: 外部 action で Dependabot alerts を失う（補完策で対応する）

なお、信頼ベンダーを semver tag・小規模メンテナのみ SHA pin とする 3 tier も検討したが、(a) semver tag では大手ベンダーの改ざん耐性が上がらない、(b) 実害の出た攻撃は大手 org 寄りで発生している、(c)「ベンダー / コミュニティ / 個人」の境界が恣意的で運用判断がぶれる、ため採用しない。

## 採択理由

GitHub-owned actions は GitHub Actions platform に近い trust boundary として扱える。改ざん確率が相対的に低く、CodeQL を含め Dependabot alerts の価値が高いため、`@vX.Y.Z` で実行内容の変化を可視化しつつ alerts を残す方が合理的である。

一方、GitHub-owned でない action は、大手ベンダーであっても自リポジトリから見れば外部依存であり、cloud credentials、container build/push、Terraform、security scan、label sync など CI/CD の重要処理に関わる。これらは tier をまたいだ個別判断より「GitHub-owned 以外は SHA pin」という単純規則の方が、action 追加時の判断ブレと運用負荷を抑えられる。SHA pin で alerts を失う弱点は、Dependabot version updates・release notes・GitHub Advisory Database 確認・PR review で補完する。

`@vX.Y.Z` の semver tag 自体は immutable ではないが、Tier A では改ざん耐性ではなく「実行内容の変化を PR として可視化すること」と「alerts の維持」を主目的に置く。immutable 参照が必要な改ざん耐性は Tier B の SHA pin が担う、という役割分担とする。

## 影響

### メリット

- 実行される action の変更が PR の diff として可視化される
- non-GitHub-owned actions のタグ移動・改ざんリスクを下げられる
- action 追加時の判断ルールが「GitHub-owned か否か」に単純化される
- non-GitHub-owned actions について OpenSSF Scorecard の Pinned-Dependencies の方向性と整合しやすくなる

### デメリット

- non-GitHub-owned actions では Dependabot alerts が効かなくなる
- SHA とコメントのバージョン対応を誤ると、誤った commit を実行する危険がある
- 初回移行時に各 tag と SHA の対応確認コストが発生する
- `@vX.Y.Z` 化・SHA 化のいずれも `@vX` より Dependabot PR 数が増える（dependabot groups で緩和する）

### 補完策

- Dependabot version updates を継続し、SHA と `# vX.Y.Z` コメントを追従更新する
- PR review 時に release notes / GitHub Advisory Database を確認する
- SHA と `# vX.Y.Z` の対応検証を実装 PR の検証項目に入れる

### 後続タスク（実装 PR で実施）

- `.github/workflows` の `uses:` 一覧を棚卸しする
- 各 action を Tier A / Tier B に分類する
- Tier A を `@vX.Y.Z` に固定する
  - `git ls-remote <repo> refs/tags/vX 'refs/tags/vX^{}'` で floating major tag が現時点で指す commit SHA を取得する
  - その commit SHA に対応する semver patch tag を全タグの逆引き（`git ls-remote --tags <repo> | grep <sha>`）で確認し、その版を `@vX.Y.Z` として使用する
  - pin 先は「最新の patch version」ではなく「floating tag が今この瞬間に指している version」とし、pin 操作とバージョンアップを分離する
- Tier B を `@<full-length-sha> # vX.Y.Z` に固定する
  - Tier A と同じ手順で floating major tag が指す commit SHA を取得し、その SHA を `uses:` に記載する
  - 同一行コメントの `# vX.Y.Z` には、その commit に対応する semver patch tag を記載する
  - pin 先の根拠は floating tag の現在参照先であり、「最新版への更新」ではない
- `.github/dependabot.yml` の groups / open-pull-requests-limit を検討する
- `docs/operations/quality-gates.md` の action バージョン管理方針を本方針に更新する
- `docs/security/threat-model.md` の T10 を本方針に更新する
- actionlint / CI で検証する
- 移行後、Dependabot が SHA とコメントを更新する PR を作るか観測する

## 関連

- [Issue #351](https://github.com/kmryst/terraform-hannibal/issues/351) - 本 ADR
- [Issue #350](https://github.com/kmryst/terraform-hannibal/issues/350) - Renovate 導入検討。将来 Renovate を採る場合は本 ADR の Dependabot version updates 補完策を Renovate に読み替える
- [Threat Model](../security/threat-model.md) - T10 supply chain / GitHub Action 依存の侵害（本 ADR が対応するエスカレーション条件）
- [Quality Gates](../operations/quality-gates.md) - action バージョン管理方針
- [0012](./0012-consolidate-iac-security-scan-on-trivy-config.md) - PR 品質ゲートの security scan 方針
- [0013](./0013-promote-quality-checks-to-required-gradually.md) - 品質チェックの段階的 required 化
