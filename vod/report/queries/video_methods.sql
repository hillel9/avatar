SELECT
eventVar3,
COUNT(*)
FROM nvp1.ovp_raw.application_events
INNER JOIN nvp1.ovp_raw.partner ON partnerId = Id

WHERE partition_date >= CURRENT_DATE - INTERVAL '31 days'
AND kalturaApplication = 'Avatar Videos'
AND eventVar2 = 'Select avatar video type'

GROUP BY eventVar3
