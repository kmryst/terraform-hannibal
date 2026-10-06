# 0033. idp-golden-path ADR 0008 の期限付き例外方式を採用し、braces の advisory を root の Dependency Audit で期限付き例外にする

## ステータス

Accepted

## 日付

2026-10-06

## 決定内容

root（NestJS backend）の `root / Dependency Audit` では、idp-golden-path の reusable workflow（`dependency-audit.yml@v1`）に `npm-audit-exceptions` input を渡し、braces の high advisory [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) を期限付き例外にする。
例外の契約は idp-golden-path [ADR 0008](https://github.com/kmryst/idp-golden-path/blob/main/docs/adr/0008-ci-guardrails-as-reusable-workflows-with-tag-pinning.md) の追記（2026-07-28）にそのまま従う。

- 宣言場所は `.github/workflows/dependency-audit.yml` の root job の `with:` とする。client job には追加しない（client では braces が検出されないため）
- 例外 1 件は `id`（GHSA ID）、`expires`（UTC の日付）、`tracking`（GitHub Issue の URL）の 3 フィールドだけで書く。今回は `expires: 2026-12-31`、`tracking: #655`
- `expires` は登録日から最大 90 日とする。期限は、同じ GHSA を追跡している idp-golden-path [#297](https://github.com/kmryst/idp-golden-path/issues/297) と同じ 2026-12-31 に揃え、2 リポジトリの見直し時期を合わせる
- 解除条件（braces 3.0.4 以上の公開、または `micromatch` / `markdownlint-cli2` の braces 依存解消）は追跡 Issue [#655](https://github.com/kmryst/terraform-hannibal/issues/655) で追う
- 不要になった例外を撤去する PR は自動では作らない。追跡 Issue、Job Summary の stale 警告、期限切れによる fail closed で気づく運用とする

運用手順（期限の更新・解除）の正本は [Dependency Management](../operations/dependency-management.md) の「Audit Scope」節とする。

## 背景

`root / Dependency Audit`（`npm audit --audit-level=high`）は 2026-09-07 から fail し続けている。PR #652（Issue #651）で lockfile の更新により直せる advisory を解消したが、lockfile の更新では直せない high が 2 件残った。

| advisory | package | 依存区分 | 修正版 |
|---|---|---|---|
| GHSA-vfj7-8cjw-p6xm | `braces@3.0.3`（`<= 3.0.3`） | devDependency のみ。`markdownlint-cli2` → `micromatch@4.0.8` → `braces`、および `markdownlint-cli2` → `globby` → `fast-glob` → `micromatch` | なし（最新は 3.0.3） |
| GHSA-7mx3-vvmw-hjmv | `@graphql-tools/utils@12.0.0`（`<= 12.0.0`） | 本番依存。`@nestjs/graphql` / `@nestjs/apollo` 13.x 経由 | 12.0.3。ただし `@nestjs/graphql@13.4.5` が 12.0.0 を完全一致で固定しているため lockfile の更新では取り込めない |

`@graphql-tools/utils` は本番依存のため、期限付き例外の対象にできない（評価器は本番依存を例外なしで判定する）。こちらは PR #659（Issue #658）で `overrides` により修正版 12.0.3 に固定して解消した。この ADR が扱うのは、修正版のない braces だけである。

この状態では、PR が何を変えても Dependency Audit は fail する。常に fail しているゲートは誰も見なくなり（alert fatigue）、新しい advisory が増えても気づけない。idp-golden-path は同じ braces の advisory で同じ状況になり、ADR 0008 の追記（2026-07-28、2026-10-05）で期限付き例外の仕組みを reusable workflow に用意した。この仕組みは `@v1` に含まれており、caller 側で input を渡すだけで使える。

braces の advisory は、深く入れ子にしたブレースパターンを渡すとコールスタックを使い切る DoS である。本リポジトリで braces にパターンを渡すのは、`markdownlint-cli2` が Markdown ファイルを探すための glob だけである。glob はリポジトリ内の設定とコマンドライン引数が与えるもので、外部の利用者が入力する経路はない。本番イメージは `npm ci --omit=dev` で作るため、braces は入らない。

## 検討した選択肢

### idp-golden-path ADR 0008 の期限付き例外を caller から使う（採択）

- 利点: 評価器（`scripts/ci/npm-audit-policy.mjs`）は idp-golden-path で実装・テスト済みで、`@v1` と同じ commit から取得されるため、本リポジトリでは実装も保守もしない
- 利点: 例外は GHSA 単位なので、braces 以外の high はこれまでどおり fail する。`via` の連鎖を根本の advisory までたどって判定するため、`micromatch` / `fast-glob` / `globby` / `markdownlint-cli2` のように braces が原因で high になっているものも、まとめて braces の例外として扱われる
- 利点: 本番依存（`--omit=dev`）の audit は例外なしで判定される。critical は例外にできず、期限切れや書式の誤りは fail closed になる。例外は最長 90 日で、気づかないうちに恒久化することはない
- トレードオフ: 90 日ごとに、露出を評価し直したうえで期限を更新する PR が要る
- トレードオフ: 本番依存に high が 1 件でもあると、評価器は例外を適用する前の本番依存の判定で fail closed になり、Job Summary にも例外の適用状況の表ではなくエラーだけが出る。例外が効くのは、本番依存の audit が 0 件のときに限られる（#659 で `@graphql-tools/utils` を解消した後の状態がこれにあたる）

### 修正版が出るまで待つ

- 利点: 変更が要らない
- トレードオフ: braces 3.0.3 は 2024-09 から更新がなく、修正版がいつ出るか分からない。それまで Dependency Audit は fail し続け、新しい high（他のパッケージの advisory）が増えても fail の内容が変わらないので気づけない。Dependabot PR も全件 fail のままになる
- 不採用理由: ゲートが検出の役目を果たさない状態が無期限に続く

### `overrides` で braces を差し替える

- 利点: 本リポジトリの `package.json` だけで完結する
- トレードオフ: braces には修正版がないので、`overrides` で指定できる安全なバージョンが存在しない。fork や別パッケージへ差し替えると、`micromatch` の API 互換性をこちらで保証しなければならず、上流が修正版を出した後に `overrides` を外し忘れる危険もある（ADR 0016 の自動撤去は消費側に効かない）
- 不採用理由: 解消する手段にならない

### audit の閾値を下げる（`--audit-level=critical` にする、または devDependency を audit から外す）

- 利点: すぐに緑にできる
- トレードオフ: GHSA 単位ではなく severity や依存区分単位で検出をやめることになり、これから出る high や、CI で実行されるツールチェーンの advisory もすべて見逃す。期限もないので恒久化する。reusable workflow の閾値は idp-golden-path 側の契約で、caller が変えられる input もない
- 不採用理由: 検出範囲を広く失うわりに、得られるものが braces 1 件分しかない

### `markdownlint-cli2` を別の linter に置き換える

- 利点: `markdownlint-cli`（0.49.1 で確認）は braces に依存しないため、advisory そのものが依存グラフから消える
- トレードオフ: 設定ファイルの形式（`.markdownlint-cli2.jsonc`）と glob・ignore の書き方が変わり、Markdown Lint の設定を idp-golden-path と揃えて管理できなくなる。reusable workflow の `markdown-lint.yml@v1` は `npm run lint:md` を呼ぶだけなので CI は変えずに済むが、ツールの乗り換えは「Dependency Audit を緑に戻す」という目的に対して変更範囲が大きい。他の依存が今後 `micromatch` などを経由して braces を引き込めば、同じ問題がまた起きる
- 不採用理由: 目的に対して変更範囲が大きく、idp-golden-path との設定の共通化を失う。braces の修正版がずっと出ない場合の再検討候補として残す

### 自動の撤去 PR を作る / 作らない

idp-golden-path ADR 0016 は、不要になった回避策・例外を撤去する PR を自動で作る仕組みである。ただし判定は idp-golden-path 自身の schedule / workflow_dispatch の実行に限っており、reusable workflow の消費側（`workflow_call`）は対象外としている。消費側へ広げる [kmryst/idp-golden-path#310](https://github.com/kmryst/idp-golden-path/issues/310) も未実装である。

本リポジトリだけで同じ仕組みを作ると、idp-golden-path と並行する実装になり、判定条件がずれる。そこで、自動の撤去 PR は作らない（採択）。代わりに、次の 3 つで不要になった例外に気づく。

- 追跡 Issue #655 を OPEN のままにし、解除条件を書いておく
- 例外の GHSA が検出されなくなると、評価器は pass したうえで Job Summary に stale 警告（`not detected (remove the stale exception)`）を出す
- 期限（最長 90 日）を過ぎると fail closed になり、更新するか削除するかの判断を必ず求められる

## 採択理由

1. 検出能力を保ったまま、修正できない 1 件だけを期限付きで外せる。閾値を下げる案は検出範囲を広く失い、待つ案はゲートが検出の役目を果たさない状態を無期限に続ける
2. 仕組みは idp-golden-path で実装・テスト済みで、caller に input を足すだけで使える。`overrides` や linter の置き換えは、本リポジトリで保守するものを増やす
3. 露出が小さい。braces は devDependency だけで本番イメージに入らず、外部入力のパターンが渡る経路もない
4. 期限、追跡 Issue、critical 不可、本番依存の別判定が評価器で強制される。「例外を入れたまま忘れる」ことが仕組みの上で起きない

## 影響

- `root / Dependency Audit` の判定は「例外なしの `npm audit --audit-level=high`」から「本番依存の例外なし判定 + full audit への例外適用」に変わる。本番依存の `@graphql-tools/utils`（GHSA-7mx3-vvmw-hjmv）は #659 で解消済みのため、braces の例外が効き、他に high がなければ緑になる
- `root / Dependency Audit` は required status check ではないため、branch protection の変更は不要
- client job の判定は変わらない
- 2026-12-31 までに #655 の解除条件が揃わなければ、2027-01-01（UTC）以降の実行で Dependency Audit は fail closed になる。更新する場合は、露出を評価し直したうえで新しい期限（その日から最大 90 日）にする PR を出す
- [Dependency Management](../operations/dependency-management.md) の Audit Scope に、期限付き例外と「root は `npm audit` 0 件を維持する」という基準との関係を追記する

## 再検討条件

- braces 3.0.4 以上が公開された、または `micromatch` / `markdownlint-cli2` の braces 依存がなくなった → 例外を削除する（#655 を close）
- idp-golden-path#310 が実装され、消費側にも撤去 PR が作られるようになった → 運用を見直す
- 期限の更新を 2 回以上繰り返しても修正版が出ない → `markdownlint-cli2` の置き換えを再検討する
- 本番依存で修正版のない high が出て、例外にするかを判断する必要が出た → 本 ADR の対象（devDependency の braces）とは露出が違うため、個別に判断する

## 関連

- Issue: [#656](https://github.com/kmryst/terraform-hannibal/issues/656)（作業）、[#655](https://github.com/kmryst/terraform-hannibal/issues/655)（解除条件の追跡）、[#651](https://github.com/kmryst/terraform-hannibal/issues/651)（lockfile で直せる advisory の解消）、[#658](https://github.com/kmryst/terraform-hannibal/issues/658)（`@graphql-tools/utils` を `overrides` で解消）
- idp-golden-path: [ADR 0008](https://github.com/kmryst/idp-golden-path/blob/main/docs/adr/0008-ci-guardrails-as-reusable-workflows-with-tag-pinning.md)（追記 2026-07-28 / 2026-10-05）、[ADR 0016](https://github.com/kmryst/idp-golden-path/blob/main/docs/adr/0016-automated-removal-pr-for-dependency-workarounds.md)、[#297](https://github.com/kmryst/idp-golden-path/issues/297)、[#310](https://github.com/kmryst/idp-golden-path/issues/310)、`scripts/ci/npm-audit-policy.mjs`、`docs/operations/security-scanning.md`
- [Dependency Management](../operations/dependency-management.md)
- [ADR 0032](./0032-keep-dependabot-and-do-not-adopt-renovate.md)
