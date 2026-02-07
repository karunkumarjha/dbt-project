with haunted_houses as (

    select * from {{ ref('stg_bootcamp__raw_haunted_houses') }}

)

select
    haunted_house_id
    , house_name
    , park_area
    , theme
    , fear_level
    , house_size
from haunted_houses
