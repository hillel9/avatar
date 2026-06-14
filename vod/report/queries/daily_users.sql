SELECT
date_trunc('DD', partition_date) as truncated_date,
COUNT(DISTINCT kuserId)
FROM nvp1.ovp_raw.application_events

WHERE partition_date >= CURRENT_DATE - INTERVAL '31 days'
AND kalturaApplication = 'Avatar Videos'

GROUP BY date_trunc('DD', partition_date)
ORDER BY truncated_date
