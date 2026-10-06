import { MigrationInterface, QueryRunner } from 'typeorm';

export class InitialSchema1791279966870 implements MigrationInterface {
  name = 'InitialSchema1791279966870';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TABLE "routes" ("id" SERIAL NOT NULL, "name" character varying(255) NOT NULL, "description" text NOT NULL, "coordinates" jsonb NOT NULL, "color" character varying(100), "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_76100511cdfa1d013c859f01d8b" PRIMARY KEY ("id"))`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "routes"`);
  }
}
