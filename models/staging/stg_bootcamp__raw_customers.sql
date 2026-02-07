{{ config(materialized='table') }}

with source as (

    select * from {{ source('bootcamp', 'raw_customers') }}

),

renamed as (

    select
        customer_id
        , age
        , gender
        , email

    from source

)

select * from renamed

