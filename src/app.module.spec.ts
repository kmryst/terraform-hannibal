import { createGraphqlOptions } from './app.module';

describe('GraphQL runtime options', () => {
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
