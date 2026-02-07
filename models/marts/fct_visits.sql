

with tickets as (

    select * from {{ ref('stg_bootcamp__raw_haunted_house_tickets') }}

),

feedbacks as (

    select * from {{ ref('stg_bootcamp__raw_customer_feedbacks') }}

),

renamed as (

    select
        tickets.ticket_id
        , tickets.customer_id
        , tickets.haunted_house_id
        , tickets.purchase_date
        , tickets.visit_date
        , tickets.ticket_type
        , tickets.ticket_price
        , feedbacks.feedback_id
        , feedbacks.rating
        , feedbacks.comments

    from tickets
    left join feedbacks
        on tickets.ticket_id = feedbacks.ticket_id

)

select * from renamed
