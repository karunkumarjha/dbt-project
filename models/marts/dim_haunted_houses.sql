

with source as (

    select * from {{ ref('stg_bootcamp__raw_haunted_houses') }}

),

renamed as (

    select
        haunted_house_id
        , house_name
        , park_area
        , theme
        , fear_level
        , house_size

    from source

)

select * from renamed

