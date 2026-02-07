# CLAUDE.md — dbt Codegen Automation

This file gives Claude Code all the context it needs to scaffold a full dbt pipeline from Snowflake sources using the `dbt-labs/codegen` package.

## Project context

- **dbt project name**: `dbt_portfolio`
- **Profile**: `jaffle_shop` (defined in `profiles.yml`)
- **Warehouse**: Snowflake
- **Python venv**: `venv/` — activate once at the start of a session with `source venv/bin/activate`
- **Packages**: codegen 0.12.1, dbt_utils 1.1.1, dbt_expectations 0.10.3 (see `packages.yml`)

## Conventions

- **Staging models**: `models/staging/stg_{source_name}__{table_name}.sql`
- **Staging YAML**: `models/staging/stg_{source_name}__{table_name}.yml`
- **Sources file**: `models/staging/_sources.yml`
- **Marts models**: `models/marts/dim_*.sql` or `models/marts/fct_*.sql`
- **Marts YAML**: `models/marts/dim_*.yml` or `models/marts/fct_*.yml`
- **Leading commas** in SQL select statements
- **Materialization**: staging = `view`, marts = `table` (set in `dbt_project.yml`)

## How to generate a full pipeline from a Snowflake source

When the user asks to generate models from a source, follow these steps in order. Activate the venv once at the start — no need to repeat it for every command.

```bash
source venv/bin/activate
```

### 1. Generate sources YAML

```bash
dbt --quiet run-operation generate_source \
  --args '{
    "name": "<SOURCE_NAME>",
    "schema_name": "<SCHEMA>",
    "database_name": "<DATABASE>",
    "table_names": ["<TABLE_1>", "<TABLE_2>"],
    "generate_columns": true,
    "include_descriptions": true,
    "include_data_types": true,
    "include_database": true,
    "include_schema": true
  }' > models/staging/_sources.yml
```

### 2. Generate staging SQL (one per table)

```bash
dbt --quiet run-operation generate_base_model \
  --args '{
    "source_name": "<SOURCE_NAME>",
    "table_name": "<TABLE_NAME>",
    "materialized": "view",
    "leading_commas": true
  }' > models/staging/stg_<SOURCE_NAME>__<TABLE_NAME>.sql
```

Run this for **every table** in the source. Do them in parallel if possible.

### 3. Materialize staging models

```bash
dbt run --select staging
```

This must succeed before step 4 — codegen needs the materialized views to generate YAML.

### 4. Generate staging YAML (one per model)

```bash
dbt --quiet run-operation generate_model_yaml \
  --args '{"model_names": ["stg_<SOURCE_NAME>__<TABLE_NAME>"]}' \
  > models/staging/stg_<SOURCE_NAME>__<TABLE_NAME>.yml
```

Run this for **every staging model**.

### 5. Build marts models (dim/fct)

Marts complete the lineage and are a required part of the pipeline. Write dimensional models in `models/marts/` referencing staging via `{{ ref('stg_...') }}`.

Guidelines for marts:
- **dim_** models: one per entity (customers, haunted_houses, etc.) — select columns from a single staging model
- **fct_** models: represent events/transactions — join multiple staging models to build the fact (e.g., tickets joined with feedbacks)
- Use CTEs for each staging ref, then join/select in the final query
- Leading commas, same as staging

After writing the SQL:

```bash
dbt run --select marts
```

### 6. Generate marts YAML

```bash
dbt --quiet run-operation generate_model_yaml \
  --args '{"model_names": ["dim_<NAME>"]}' > models/marts/dim_<NAME>.yml
```

Run this for **every mart model** (both dim and fct).

## Important notes

- Activate the venv once per session — not before every command
- Always use `dbt --quiet` when redirecting output to files (suppresses logs)
- Run `dbt deps` if `dbt_packages/` is missing
- Run `dbt debug` to verify the Snowflake connection before generating anything
- The `>` redirect overwrites the file — this is intentional for codegen output
- If `dbt run` fails, fix the model SQL before attempting YAML generation
