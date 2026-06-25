SELECT
irp2.ovp_raw.partner.partner_name AS pid_name,
`urlParts.domain` AS domain,
COUNT(DISTINCT `kuserId`) AS active_monthly_users,
COUNT(DISTINCT `customId1`) AS avatar_videos_projects,
MAX(partition_date) AS last_partition_date
FROM irp2.ovp_raw.application_events
INNER JOIN irp2.ovp_raw.partner ON partnerId = Id

WHERE partition_date >= CURRENT_DATE - INTERVAL '92 days'
AND irp2.ovp_raw.application_events.partnerId IN (683)
AND kalturaApplication = 'Avatar Videos'

GROUP BY 1, 2
ORDER BY active_monthly_users DESC
