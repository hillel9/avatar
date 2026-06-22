SELECT
COUNT(DISTINCT kuserId)
FROM nvp1.ovp_raw.application_events
INNER JOIN nvp1.ovp_raw.partner ON partnerId = Id

WHERE partition_date >= CURRENT_DATE - INTERVAL '31 days'
AND kalturaApplication = 'Avatar Videos'
