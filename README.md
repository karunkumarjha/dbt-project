# dbt Codegen Portfolio

A minimal dbt project demonstrating how to scaffold a full **source → staging → marts** pipeline using the [dbt-labs/codegen](https://github.com/dbt-labs/codegen) package — with nearly zero hand-written SQL.

The idea is simple: point codegen at your Snowflake tables, let it generate the boilerplate, then review and ship. Pair it with Claude Code (see [CLAUDE.md](CLAUDE.md)) and the entire process becomes a single prompt.

## What's in this repo

```
models/
  staging/
    _sources.yml                                  # generated source definitions
    stg_bootcamp__raw_customers.sql / .yml        # generated staging views + schema
    stg_bootcamp__raw_customer_feedbacks.sql / .yml
    stg_bootcamp__raw_haunted_houses.sql / .yml
    stg_bootcamp__raw_haunted_house_tickets.sql / .yml
  marts/
    dim_customers.sql / .yml                      # dimension: customer attributes
    dim_haunted_houses.sql / .yml                 # dimension: haunted house attributes
    fct_visits.sql / .yml                         # fact: tickets joined with feedbacks
```

Everything was scaffolded with codegen — staging models directly, and marts by temporarily defining staging views as a source for codegen to introspect, then swapping `source()` to `ref()`. The only hand-written part is join logic in fact models.

## Prerequisites

- Python 3.9+
- Snowflake account with access to your source tables
- Environment variables: `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`, `STUDENT_SCHEMA`

## Setup

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r dbt-requirements.txt
cp profiles.example.yml profiles.yml  # then fill in your env vars
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
    "materialized": "view",
    "leading_commas": true
  }' > models/staging/stg_bootcamp__raw_customers.sql
```

Repeat for each table (or automate with a loop / Claude Code).

### Step 3: Materialize staging models

Run the staging views so codegen can introspect them for YAML generation:

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

### Step 5: Generate marts (dim/fct) using codegen

Since `generate_base_model` only works with `source()`, temporarily define the staging views as a source:

```bash
dbt --quiet run-operation generate_source \
  --args '{
    "name": "staging",
    "schema_name": "<your_schema>",
    "database_name": "<your_database>",
    "table_names": ["stg_bootcamp__raw_customers", "stg_bootcamp__raw_haunted_houses", "stg_bootcamp__raw_haunted_house_tickets", "stg_bootcamp__raw_customer_feedbacks"],
    "generate_columns": true,
    "include_descriptions": true,
    "include_data_types": true,
    "include_database": true,
    "include_schema": true
  }' > models/marts/_staging_source.yml
```

Then generate base models from it:

```bash
dbt --quiet run-operation generate_base_model \
  --args '{"source_name": "staging", "table_name": "stg_bootcamp__raw_customers", "leading_commas": true}' \
  > models/marts/dim_customers.sql
```

After generating, make two edits:
1. Replace `{{ source('staging', '...') }}` with `{{ ref('...') }}` in each file
2. For fact models, add CTEs and joins for additional staging tables (codegen provides the column lists, you add the join logic)

Then delete the temporary source and run:

```bash
rm models/marts/_staging_source.yml
dbt run --select marts
```

### Step 6: Generate marts YAML

Same codegen command, pointed at the mart models:

```bash
dbt --quiet run-operation generate_model_yaml \
  --args '{"model_names": ["dim_customers"]}' \
  > models/marts/dim_customers.yml
```

## Automate with Claude Code

See [CLAUDE.md](CLAUDE.md) for instructions that let Claude Code handle this entire workflow from a single prompt. All you need to do is review the output.
