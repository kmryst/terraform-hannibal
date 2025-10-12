## 🧪 テスト戦略

### Backend (NestJS)

```typescript
// Unit Test例: route.service.spec.ts
describe('RouteService', () => {
  it('should return all routes', async () => {
    const routes = await service.findAll();
    expect(routes).toBeDefined();
  });
});

// E2E Test例: app.e2e-spec.ts
it('/graphql (POST) - query routes', () => {
  return request(app.getHttpServer())
    .post('/graphql')
    .send({ query: '{ routes { id name } }' })
    .expect(200);
});
```

**テスト実行:**
```bash
npm test              # Jest Unit Tests
npm run test:e2e      # E2E Tests
npm run test:cov      # Coverage Report
```

### Infrastructure (Terraform)

```bash
# 構文チェック
terraform validate

# セキュリティスキャン
tfsec terraform/

# 変更プレビュー（破壊的変更の確認）
terraform plan -out=tfplan
```

---
