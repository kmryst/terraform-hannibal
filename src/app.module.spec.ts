import { ApolloDriver } from '@nestjs/apollo';
import { AbstractGraphQLDriver } from '@nestjs/graphql';
import { createGraphqlModule, createGraphqlOptions } from './app.module';

describe('GraphQL runtime options', () => {
  it('configures the Apollo driver at the GraphQL module wrapper level', () => {
    expect(createGraphqlModule().providers).toContainEqual(
      expect.objectContaining({
        provide: AbstractGraphQLDriver,
        useClass: ApolloDriver,
      }),
    );
  });

  it('does not include driver in runtime options returned by the factory', () => {
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
