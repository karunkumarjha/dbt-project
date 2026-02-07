

with source as (

    select * from {{ ref('stg_bootcamp__raw_customers') }}

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

