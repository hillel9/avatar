SELECT
nvp1.ovp_raw.partner.partner_name AS pid_name,
COUNT(DISTINCT `kuserId`) AS total_users
FROM nvp1.ovp_raw.application_events
INNER JOIN nvp1.ovp_raw.partner ON partnerId = Id

WHERE partition_date >= CURRENT_DATE - INTERVAL '92 days'
AND nvp1.ovp_raw.application_events.partnerId IN (2167581,2189801,3193793,4170533,2314871,1714341,1889041,2167551,1315742)
AND kalturaApplication = 'In-App Messaging'
AND customId1 = 'a88d6006-4cd4-453c-99b4-aa5979d30d5a 😺 Avatar Videos Beta Program - Annouce'

GROUP BY 1
ORDER BY 2 DESC
