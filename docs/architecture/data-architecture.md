# Data Architecture

## データアーキテクチャ概要

ハンニバルのアルプス越えルートデータを効率的に管理・配信するためのデータ設計

## データモデル設計（実装済み）

### 実装されているデータモデル

**TypeORM Entity: `src/entities/route.entity.ts`**

```typescript
@Entity('routes')
export class Route {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 255 })
  name: string;

  @Column('text')
  description: string;

  @Column('jsonb')
  coordinates: number[][];  // [[lng, lat], [lng, lat], ...]

  @Column({ length: 100, nullable: true })
  color?: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
```

**PostgreSQL テーブル定義:**

テーブルはアプリ起動時に TypeORM migrations で作られる（[ADR 0035](../adr/0035-adopt-typeorm-migrations-for-schema-management.md)）。
DDL の正本は `src/migrations/` のマイグレーションファイルで、以下は初回マイグレーション `src/migrations/1791279966870-InitialSchema.ts` の内容である。

```sql
CREATE TABLE "routes" (
    "id" SERIAL NOT NULL,
    "name" character varying(255) NOT NULL,
    "description" text NOT NULL,
    "coordinates" jsonb NOT NULL,  -- GeoJSON座標配列
    "color" character varying(100),
    "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
    "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT "PK_76100511cdfa1d013c859f01d8b" PRIMARY KEY ("id")
);
```

### データモデルの特徴

1. **JSONB型**: 座標データをPostgreSQLのJSONB型で保存
   - フレキシブルなデータ構造
   - インデックス可能（GIN/GiSTインデックス）
   - ネイティブJSON関数でクエリ最適化

2. **シンプル設計**: 複雑な正規化を避け、パフォーマンス重視
   - 座標は routes テーブルに直接保存
   - 別テーブル分割なし（データ量が小規模なため）

3. **TypeORM統合**: TypeScriptの型安全性を保持
   - GraphQL Code First と連携
   - スキーマは全環境で TypeORM migrations により管理（`synchronize` は全環境で無効。詳細は「スキーマ管理（TypeORM migrations）」）

### スキーマ管理（TypeORM migrations）

判断の背景と代替案は [ADR 0035](../adr/0035-adopt-typeorm-migrations-for-schema-management.md) を参照する。この節は手順の正本である。

#### 構成

| 項目 | 内容 |
|---|---|
| 接続設定 | `src/database/typeorm-options.ts` の `createTypeOrmOptions()`。アプリ（`TypeOrmModule.forRoot`）と CLI が共有する |
| CLI 用 DataSource | `src/database/data-source.ts`（本番イメージでは `dist/database/data-source.js`） |
| マイグレーション | `src/migrations/<timestamp>-<Name>.ts`。適用対象は `src/migrations/index.ts` で明示的に列挙する |
| 適用 | 全環境で起動時に `migrationsRun: true` で適用する。未適用分を 1 つのトランザクションで実行する（`migrationsTransactionMode: 'all'`） |
| 適用済みの記録 | `migrations` テーブル（`id` / `timestamp` / `name`） |
| `synchronize` | 全環境で無効 |

glob ではなくクラスを列挙するのは、ts（ts-node / ts-jest）と dist（`nest build` の出力。`declaration: true` で `.d.ts` も出力される）のどちらでも同じ解決にするためである。

#### エンティティを変更したとき（マイグレーションの作成）

1. ローカルの PostgreSQL を、現在のマイグレーションをすべて適用した状態にする（アプリを一度起動するか `npm run migration:run`）
2. エンティティを変更する
3. マイグレーションを生成する

   ```bash
   DATABASE_URL="postgresql://<user>:<password>@localhost:<port>/<db>?sslmode=disable" \
     npm run migration:generate -- src/migrations/<Name>
   ```

4. 生成された `up` / `down` の SQL をレビューする。CodeDeploy の Canary / Blue/Green では新旧のタスクが同じ DB を同時に使うため、1 つ前のバージョンのアプリでも動く後方互換な変更にする（列の削除・名前変更は expand and contract パターンで複数回のリリースに分ける）
5. `src/migrations/index.ts` の配列の末尾にクラスを追記する（追記しないと適用されない）
6. `npx prettier --write src/migrations` で整形する
7. 確認する

   ```bash
   npm run migration:run      # 適用
   npm run migration:revert   # 直前の 1 件を戻す（down）
   npm run migration:run      # 再適用
   # エンティティとスキーマが一致していれば、次は "No changes in database schema were found" で終了コード 1 になる
   npm run migration:generate -- src/migrations/Check
   npm run migration:show     # [X] が適用済み、[ ] が未適用
   ```

データ投入だけ、または SQL を手で書く場合は `npx typeorm migration:create src/migrations/<Name>` で空のマイグレーションを作る。

#### 以前 `synchronize` でテーブルを作ったローカル DB

Issue #674 より前のコードで起動したローカル DB には、`migrations` テーブルの記録がないまま `routes` テーブルがある。
この DB に起動すると初回マイグレーションが `relation "routes" already exists` で失敗する。DB を作り直すか、スキーマが初回マイグレーションと同じであることを確認したうえで、適用済みとして記録する。

```bash
DATABASE_URL="..." npm run migration:run -- --fake
```

AWS dev の RDS は provisioning のたびに空のため該当しない。

#### AWS 上での適用・確認・ロールバック

- 適用: `deploy.yml` でデプロイしたタスクが起動時に適用する。CloudWatch Logs（`/ecs/nestjs-hannibal-3-api-task`）に `Migration <Name> has been executed successfully.`（適用時）または `No migrations are pending`（適用済み）が出る
- 確認: Synthetics canary（`hannibal-canary`）の step `graphql-routes-query` が CloudFront 経由で GraphQL の `routes` を確認する。`deploy.yml` の `Verify deployment with Synthetics canary` step は、deploy 後に開始した canary の run が PASSED になるのを待つ
- ロールバック: [Runbook](../operations/runbook.md) の「スキーマ変更を含むデプロイの rollback」を参照する

### GraphQLスキーマ設計（実装済み）

**GraphQL Code First による自動生成スキーマ:**

```graphql
type Route {
  id: ID!
  name: String!
  description: String!
  coordinates: [[Float!]!]!  # JSONB形式の座標配列
  color: String
  createdAt: DateTime!
  updatedAt: DateTime!
}

# GeoJSON形式のクエリ
type Query {
  # 全ルート取得
  routes: [Route!]!
  
  # 特定ルート取得
  route(id: ID!): Route
  
  # GeoJSON形式のハンニバルルート
  hannibalRoute: HannibalRouteCollection!
  
  # GeoJSON形式のポイントルート
  pointRoute: PointRouteCollection!
}

# GeoJSON Collection型
type HannibalRouteCollection {
  type: String!
  features: [HannibalRouteFeature!]!
}

type HannibalRouteFeature {
  type: String!
  properties: HannibalRouteProperties!
  geometry: GeometryLineString!
}

type GeometryLineString {
  type: String!
  coordinates: [[Float!]!]!
}

type HannibalRouteProperties {
  name: String!
}
```

### 実装されているクエリ

```typescript
// src/modules/route/route.resolver.ts
@Resolver(() => Route)
export class RouteResolver {
  @Query(() => [Route])
  async routes(): Promise<Route[]> {
    return this.routeService.findAll();
  }

  @Query(() => Route, { nullable: true })
  async route(@Args('id', { type: () => Int }) id: number): Promise<Route> {
    return this.routeService.findOne(id);
  }

  @Query('hannibalRoute')
  async hannibalRoute() {
    return this.routeService.getHannibalRouteGeoJSON();
  }

  @Query('pointRoute')
  async pointRoute() {
    return this.routeService.getPointRouteGeoJSON();
  }
}
```

## データフロー設計

### リアルタイムデータフロー

```mermaid
graph TD
    A[Frontend Map Component] --> B[GraphQL Query]
    B --> C[NestJS Resolver]
    C --> D[Service Layer]
    D --> E[Repository Layer]
    E --> F[PostgreSQL]
    
    F --> G[PostgreSQL SELECT with JSONB coordinates]
    G --> I[Results]
    I --> J[GraphQL Response]
    J --> K[Frontend Rendering]
```

### バッチデータ処理

```mermaid
graph LR
    A[Historical Data Sources] --> B[ETL Pipeline]
    B --> C[Data Validation]
    C --> D[PostgreSQL Insert]
    D --> F[Cache Invalidation]
```

## データクエリ（実装済み）

### JSONB型の活用

座標は `@Column('jsonb')` で保持し、`find()` / `findOne()` による全件取得・ID 検索で参照する。現状は JSONB operator（`@>`、`jsonb_array_length()` 等）は使っていない。

**実装済みクエリ（TypeORM）:**

```typescript
// 全件取得
this.routeRepository.find();

// ID 検索
this.routeRepository.findOne({ where: { id } });
```

**座標検索が要件化した場合の候補（未実装）:**

```sql
-- JSONB operator による座標検索
SELECT id, name, 
       jsonb_array_length(coordinates) as point_count
FROM routes
WHERE coordinates @> '[[7.0, 46.0]]';

-- GIN インデックス（座標検索が要件化したときに追加する候補）
CREATE INDEX idx_routes_coordinates 
ON routes USING GIN (coordinates);
```

> JSONB operator クエリと GIN index はいずれも未実装。現在のルート数では不要で、座標検索が機能要件として発生したときに初めて追加する。判断の正本は [ADR 0016](../adr/0016-adopt-rds-postgresql-jsonb-over-aurora-and-postgis.md)。

### TypeORMによるクエリ最適化

```typescript
// src/modules/route/route.service.ts
@Injectable()
export class RouteService {
  constructor(
    @InjectRepository(Route)
    private routeRepository: Repository<Route>,
  ) {}

  async findAll(): Promise<Route[]> {
    // シンプルなSELECT文（全カラム取得）
    return this.routeRepository.find({
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: number): Promise<Route> {
    return this.routeRepository.findOne({
      where: { id },
    });
  }

  // GeoJSON形式への変換
  async getHannibalRouteGeoJSON() {
    const routes = await this.findAll();
    return {
      type: 'FeatureCollection',
      features: routes.map(route => ({
        type: 'Feature',
        properties: { name: route.name },
        geometry: {
          type: 'LineString',
          coordinates: route.coordinates,
        },
      })),
    };
  }
}
```

## スコープ外とした最適化

### PostGIS拡張機能（スコープ外・未実装）

- 空間インデックス（GIST/GIN）
- 地理的範囲検索（ST_Within、ST_DWithin）
- ルート計算（ST_Length、ST_Distance）

### スコープ外とする理由

- 現在のデータ量では不要（ルート数が少ない）
- JSONB型で十分なパフォーマンス
- 本プロジェクトの規模では採用しない。地理的範囲検索・距離計算が機能要件化したときに初めて再検討するが、demo / portfolio 用途でその要件が発生する想定はない。判断の正本は [ADR 0016](../adr/0016-adopt-rds-postgresql-jsonb-over-aurora-and-postgis.md)

## キャッシュ戦略（部分実装）

### 実装済みキャッシュ

#### CloudFront CDN キャッシュ

```hcl
# terraform/modules/cdn/cloudfront/main.tf
resource "aws_cloudfront_distribution" "main" {
  default_cache_behavior {
    default_ttl = 86400    # 1日
    max_ttl     = 31536000 # 1年
    min_ttl     = 0
  }
}
```

**特徴:**

- 静的コンテンツ（React ビルド成果物）をグローバルキャッシュ
- エッジロケーションでの高速配信
- オリジン（S3/ALB）への負荷軽減

### 将来実装予定のキャッシュ

#### Redis キャッシュ（未実装）

```typescript
// 将来実装予定
@Injectable()
export class RouteService {
  constructor(
    private routeRepository: Repository<Route>,
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {}

  async getRoute(id: number): Promise<Route> {
    const cacheKey = `route:${id}`;
    
    // L1: Redisキャッシュ
    let route = await this.cacheManager.get<Route>(cacheKey);
    
    if (!route) {
      // L2: PostgreSQL
      route = await this.routeRepository.findOne({ where: { id } });
      
      // キャッシュに保存 (TTL: 1時間)
      await this.cacheManager.set(cacheKey, route, 3600);
    }
    
    return route;
  }
}
```

#### DataLoader による N+1 問題解決（未実装）

```typescript
// 将来実装予定
@Injectable()
export class RouteLoader {
  private readonly loader = new DataLoader<number, Route>(
    async (ids: number[]) => {
      const routes = await this.routeRepository
        .findByIds(ids);
      
      return ids.map(id => 
        routes.find(route => route.id === id)
      );
    }
  );

  async load(id: number): Promise<Route> {
    return this.loader.load(id);
  }
}
```

### 未実装の理由

- **データ量が少ない**: ルート数が限定的（キャッシュ不要）
- **コスト最適化**: Redis/ElastiCache の追加コストを回避
- **シンプル設計**: PostgreSQL JSONB で十分なパフォーマンス

## データ品質管理

### バリデーション設計

```typescript
// 座標データバリデーション
@Entity()
export class RouteCoordinate {
  @Column('decimal', { precision: 10, scale: 8 })
  @IsLatitude()
  @Min(-90)
  @Max(90)
  latitude: number;

  @Column('decimal', { precision: 11, scale: 8 })
  @IsLongitude()
  @Min(-180)
  @Max(180)
  longitude: number;

  @Column('integer', { nullable: true })
  @IsOptional()
  @Min(-500) // 海面下500m
  @Max(9000) // エベレスト級
  elevationM?: number;
}
```

### データ整合性チェック

```sql
-- 座標順序整合性チェック
CREATE OR REPLACE FUNCTION validate_coordinate_sequence()
RETURNS TRIGGER AS $$
BEGIN
  -- 同一ルート内での順序重複チェック
  IF EXISTS (
    SELECT 1 FROM route_coordinates 
    WHERE route_id = NEW.route_id 
    AND sequence_order = NEW.sequence_order 
    AND id != NEW.id
  ) THEN
    RAISE EXCEPTION 'Duplicate sequence order for route %', NEW.route_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER coordinate_sequence_check
  BEFORE INSERT OR UPDATE ON route_coordinates
  FOR EACH ROW EXECUTE FUNCTION validate_coordinate_sequence();
```

## パフォーマンス最適化

### データベース最適化

```sql
-- 複合インデックス作成
CREATE INDEX idx_route_coordinates_route_sequence 
ON route_coordinates (route_id, sequence_order);

-- 部分インデックス (アクティブルートのみ)
CREATE INDEX idx_active_routes 
ON routes (created_at) 
WHERE deleted_at IS NULL;

-- 統計情報更新
ANALYZE route_coordinates;
ANALYZE routes;
```

### クエリ最適化

```typescript
// DataLoader による N+1 問題解決
@Injectable()
export class CoordinateLoader {
  private readonly loader = new DataLoader<string, RouteCoordinate[]>(
    async (routeIds: string[]) => {
      const coordinates = await this.coordinateRepository
        .createQueryBuilder('coord')
        .where('coord.routeId IN (:...routeIds)', { routeIds })
        .orderBy('coord.sequenceOrder', 'ASC')
        .getMany();

      return routeIds.map(routeId =>
        coordinates.filter(coord => coord.routeId === routeId)
      );
    }
  );

  async loadByRouteId(routeId: string): Promise<RouteCoordinate[]> {
    return this.loader.load(routeId);
  }
}
```

## データ移行・バックアップ

### 移行戦略

```sql
-- 段階的データ移行
BEGIN;

-- 1. 新テーブル作成
CREATE TABLE routes_new (LIKE routes INCLUDING ALL);

-- 2. データ変換・移行
INSERT INTO routes_new (name, description, difficulty_level)
SELECT 
  route_name,
  route_desc,
  CASE 
    WHEN difficulty = 'easy' THEN 1
    WHEN difficulty = 'moderate' THEN 3
    WHEN difficulty = 'hard' THEN 5
  END
FROM legacy_routes;

-- 3. テーブル切り替え
ALTER TABLE routes RENAME TO routes_old;
ALTER TABLE routes_new RENAME TO routes;

COMMIT;
```

### バックアップ設定

```bash
#!/bin/bash
# 自動バックアップスクリプト

# 地理データの完全バックアップ
pg_dump \
  --host=$DB_HOST \
  --username=$DB_USER \
  --format=custom \
  --compress=9 \
  --file="hannibal_backup_$(date +%Y%m%d_%H%M%S).dump" \
  hannibal_db

# S3へのアップロード
aws s3 cp hannibal_backup_*.dump s3://nestjs-hannibal-3-backups/database/
```

## 監視・メトリクス

### データベース監視

```sql
-- クエリパフォーマンス監視
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  rows
FROM pg_stat_statements 
WHERE query LIKE '%route%'
ORDER BY total_time DESC
LIMIT 10;
```

### アプリケーションメトリクス

```typescript
// Prometheus メトリクス
@Injectable()
export class MetricsService {
  private readonly queryDuration = new Histogram({
    name: 'graphql_query_duration_seconds',
    help: 'GraphQL query duration',
    labelNames: ['operation', 'status'],
  });

  recordQueryDuration(operation: string, duration: number, status: string) {
    this.queryDuration.labels(operation, status).observe(duration);
  }
}
```

---
**最終更新**: 2025年10月12日  
**データモデル**: シンプル設計（Route Entity のみ、JSONB型座標）  
**実装状況**: TypeORM + PostgreSQL 15 + GraphQL Code First
