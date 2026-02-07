with customers as (

    select * from {{ ref('stg_bootcamp__raw_customers') }}

)

select
    customer_id
    , age
    , gender
    , email
from customers
