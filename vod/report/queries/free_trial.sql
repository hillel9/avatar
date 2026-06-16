SELECT
nvp1.ovp_raw.partner.partner_name AS pid_name,
`urlParts.domain` AS domain,
COUNT(DISTINCT `kuserId`) AS active_monthly_users,
COUNT(DISTINCT `customId1`) AS avatar_videos_projects
FROM nvp1.ovp_raw.application_events
INNER JOIN nvp1.ovp_raw.partner ON partnerId = Id

WHERE partition_date >= CURRENT_DATE - INTERVAL '92 days'
AND nvp1.ovp_raw.application_events.partnerId IN (2167581,2189801,3193793,4170533)
AND kalturaApplication = 'Avatar Videos'

GROUP BY 1, 2
ORDER BY active_monthly_users DESC
