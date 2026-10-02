# V16 verification

Run:

```bash
npm run test:production
npm run build
```

The production test is dependency-free. A successful build still requires npm dependencies/network in the deployment environment.

Apply migrations in order:

1. `EDVORA_COMPLETE_SCHEMA_V15.sql` for a fresh database, or the existing V12/V13/V14/V15 upgrades as appropriate.
2. `EDVORA_V16_PRODUCTION_UPGRADE.sql`.

Do not mark provider integrations connected from the browser. V16 checks server-side environment configuration and records the observed state.
