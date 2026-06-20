import { createGraphqlOptions } from './app.module';

describe('GraphQL runtime options', () => {
  it('keeps the Apollo driver configured by the GraphQL module wrapper', () => {
    expect(createGraphqlOptions('development')).not.toHaveProperty('driver');
  });

  it('enables GraphiQL and introspection only outside production', () => {
    expect(createGraphqlOptions('development')).toMatchObject({
      csrfPrevention: true,
      graphiql: true,
      introspection: true,
    });

    expect(createGraphqlOptions('production')).toMatchObject({
      csrfPrevention: true,
      graphiql: false,
      introspection: false,
    });
  });
});
