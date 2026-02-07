# dbt Codegen Portfolio

A minimal dbt project demonstrating how to scaffold a full **source → staging → marts** pipeline using the [dbt-labs/codegen](https://github.com/dbt-labs/codegen) package — with nearly zero hand-written SQL.

The idea is simple: point codegen at your Snowflake tables, let it generate the boilerplate, then review and ship. Pair it with Claude Code (see [CLAUDE.md](CLAUDE.md)) and the entire process becomes a single prompt.

## What's in this repo

```
models/
  staging/
    _sources.yml                                  # generated source definitions
    stg_bootcamp__raw_customers.sql / .yml        # generated staging models + schema
    stg_bootcamp__raw_customer_feedbacks.sql / .yml
    stg_bootcamp__raw_haunted_houses.sql / .yml
    stg_bootcamp__raw_haunted_house_tickets.sql / .yml
  marts/
    (add dim_* and fct_* models here)
```

Everything under `staging/` was generated with `dbt run-operation` — no manual SQL.

## Prerequisites

- Python 3.9+
- Snowflake account with access to your source tables
- Environment variables: `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`, `STUDENT_SCHEMA`

## Setup

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r dbt-requirements.txt
dbt deps
dbt debug  # verify connection
```

## The Codegen Workflow

### Step 1: Generate sources

Introspect your Snowflake schema and generate `_sources.yml` with columns and data types:

```bash
dbt --quiet run-operation generate_source \
  --args '{
    "name": "bootcamp",
    "schema_name": "bootcamp",
    "database_name": "dataexpert_student",
    "table_names": ["raw_customers", "raw_customer_feedbacks", "raw_haunted_houses", "raw_haunted_house_tickets"],
    "generate_columns": true,
    "include_descriptions": true,
    "include_data_types": true,
    "include_database": true,
    "include_schema": true
  }' > models/staging/_sources.yml
```

### Step 2: Generate staging models

For each source table, generate a base model with a CTE structure:

```bash
dbt --quiet run-operation generate_base_model \
  --args '{
    "source_name": "bootcamp",
    "table_name": "raw_customers",
    "materialized": "table",
    "leading_commas": true
  }' > models/staging/stg_bootcamp__raw_customers.sql
```

Repeat for each table (or automate with a loop / Claude Code).

### Step 3: Materialize staging models

Run the staging models so codegen can introspect them for YAML generation:

```bash
dbt run --select staging
```

### Step 4: Generate model YAML (schema files)

Generate column-level documentation for each staging model:

```bash
dbt --quiet run-operation generate_model_yaml \
  --args '{"model_names": ["stg_bootcamp__raw_customers"]}' \
  > models/staging/stg_bootcamp__raw_customers.yml
```

### Step 5: Build marts (dim/fct) on top

Write your dimensional models in `models/marts/` referencing the staging layer:

```sql
-- models/marts/dim_customers.sql
select
    customer_id
    , age
    , gender
    , email
from {{ ref('stg_bootcamp__raw_customers') }}
```

Then generate YAML for marts the same way:

```bash
dbt run --select marts
dbt --quiet run-operation generate_model_yaml \
  --args '{"model_names": ["dim_customers"]}' \
  > models/marts/dim_customers.yml
```

## Automate with Claude Code

See [CLAUDE.md](CLAUDE.md) for instructions that let Claude Code handle this entire workflow from a single prompt. All you need to do is review the output.
