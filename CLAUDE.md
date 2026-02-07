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

### 5. Generate marts models (dim/fct) using codegen

Marts complete the lineage and are a required part of the pipeline. Use codegen to scaffold them too.

**5a. Create a temporary staging source.** Since `generate_base_model` only works with sources, temporarily define the staging views as a source so codegen can introspect their columns:

```bash
dbt --quiet run-operation generate_source \
  --args '{
    "name": "staging",
    "schema_name": "<YOUR_SCHEMA>",
    "database_name": "<DATABASE>",
    "table_names": ["stg_<SOURCE_NAME>__<TABLE_1>", "stg_<SOURCE_NAME>__<TABLE_2>"],
    "generate_columns": true,
    "include_descriptions": true,
    "include_data_types": true,
    "include_database": true,
    "include_schema": true
  }' > models/marts/_staging_source.yml
```

**5b. Generate base models from the staging source:**

```bash
dbt --quiet run-operation generate_base_model \
  --args '{
    "source_name": "staging",
    "table_name": "stg_<SOURCE_NAME>__<TABLE_NAME>",
    "leading_commas": true
  }' > models/marts/dim_<NAME>.sql
```

Run this for every dim and fct model.

**5c. Swap `source()` to `ref()`.** In each generated mart file, replace:
```
{{ source('staging', 'stg_<SOURCE_NAME>__<TABLE_NAME>') }}
```
with:
```
{{ ref('stg_<SOURCE_NAME>__<TABLE_NAME>') }}
```

**5d. For fct models** that join multiple staging tables, add additional CTEs and a join. Codegen gives you the column list — you add the join logic.

**5e. Delete the temporary source file:**
```bash
rm models/marts/_staging_source.yml
```

**5f. Run the marts:**
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
