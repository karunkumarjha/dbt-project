# CLAUDE.md — dbt Codegen Automation

This file gives Claude Code all the context it needs to scaffold a full dbt pipeline from Snowflake sources using the `dbt-labs/codegen` package.

## Project context

- **dbt project name**: `dbt_portfolio`
- **Profile**: `jaffle_shop` (defined in `profiles.yml`)
- **Warehouse**: Snowflake
- **Python venv**: `venv/` — always activate with `source venv/bin/activate` before running dbt commands
- **Packages**: codegen 0.12.1, dbt_utils 1.1.1, dbt_expectations 0.10.3 (see `packages.yml`)

## Conventions

- **Staging models**: `models/staging/stg_{source_name}__{table_name}.sql`
- **Staging YAML**: `models/staging/stg_{source_name}__{table_name}.yml`
- **Sources file**: `models/staging/_sources.yml`
- **Marts models**: `models/marts/dim_*.sql` or `models/marts/fct_*.sql`
- **Marts YAML**: `models/marts/dim_*.yml` or `models/marts/fct_*.yml`
- **Leading commas** in SQL select statements
- **Materialization**: staging = `table`, marts = `table` (set in `dbt_project.yml`)

## How to generate a full pipeline from a Snowflake source

When the user asks to generate models from a source, follow these steps in order:

### 1. Generate sources YAML

```bash
source venv/bin/activate && dbt --quiet run-operation generate_source \
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
source venv/bin/activate && dbt --quiet run-operation generate_base_model \
  --args '{
    "source_name": "<SOURCE_NAME>",
    "table_name": "<TABLE_NAME>",
    "materialized": "table",
    "leading_commas": true
  }' > models/staging/stg_<SOURCE_NAME>__<TABLE_NAME>.sql
```

Run this for **every table** in the source. Do them in parallel if possible.

### 3. Materialize staging models

```bash
source venv/bin/activate && dbt run --select staging
```

This must succeed before step 4 — codegen needs the materialized tables to generate YAML.

### 4. Generate staging YAML (one per model)

```bash
source venv/bin/activate && dbt --quiet run-operation generate_model_yaml \
  --args '{"model_names": ["stg_<SOURCE_NAME>__<TABLE_NAME>"]}' \
  > models/staging/stg_<SOURCE_NAME>__<TABLE_NAME>.yml
```

Run this for **every staging model**.

### 5. (Optional) Build marts models

If the user asks for dim/fct models, write them in `models/marts/` referencing staging via `{{ ref('stg_...') }}`. Then:

```bash
source venv/bin/activate && dbt run --select marts
source venv/bin/activate && dbt --quiet run-operation generate_model_yaml \
  --args '{"model_names": ["dim_<NAME>"]}' > models/marts/dim_<NAME>.yml
```

## Important notes

- Always activate the venv before dbt commands: `source venv/bin/activate`
- Always use `dbt --quiet` when redirecting output to files (suppresses logs)
- Run `dbt deps` if `dbt_packages/` is missing
- Run `dbt debug` to verify the Snowflake connection before generating anything
- The `>` redirect overwrites the file — this is intentional for codegen output
- If `dbt run` fails, fix the model SQL before attempting YAML generation
