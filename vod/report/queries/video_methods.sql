SELECT
eventVar3,
COUNT(*)
FROM nvp1.ovp_raw.application_events
INNER JOIN nvp1.ovp_raw.partner ON partnerId = Id

WHERE partition_date >= CURRENT_DATE - INTERVAL '31 days'
AND kalturaApplication = 'Avatar Videos'
AND eventVar2 = 'Select avatar video type'
AND nvp1.ovp_raw.application_events.partnerId IN (2167581,2189801,3193793,4170533,2314871,1714341,1889041,2167551,1315742,21428242,5877472,2213002,2503612,4733002,1038472,2213002,1428242,5644772,1921661)

GROUP BY eventVar3
