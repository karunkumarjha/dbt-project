{{ config(materialized='table') }}

with source as (

    select * from {{ source('bootcamp', 'raw_customer_feedbacks') }}

),

renamed as (

    select
        feedback_id
        , ticket_id
        , rating
        , comments

    from source

)

select * from renamed

