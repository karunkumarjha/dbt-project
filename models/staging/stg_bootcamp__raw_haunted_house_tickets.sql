{{ config(materialized='view') }}

with source as (

    select * from {{ source('bootcamp', 'raw_haunted_house_tickets') }}

),

renamed as (

    select
        ticket_id
        , customer_id
        , haunted_house_id
        , purchase_date
        , visit_date
        , ticket_type
        , ticket_price

    from source

)

select * from renamed

