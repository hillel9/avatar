WITH active_users AS (
    SELECT
        nvp1.ovp_raw.partner.partner_name AS pid_name,
        kuserId,
        COUNT(DISTINCT partition_date) AS active_days
    FROM nvp1.ovp_raw.application_events
    INNER JOIN nvp1.ovp_raw.partner ON partnerId = Id

    WHERE partition_date >= CURRENT_DATE - INTERVAL '92 days'
    AND nvp1.ovp_raw.application_events.partnerId IN (21428242,5877472,2213002,2503612,4733002,1038472,2213002,1428242,5644772,1921661)
    AND kalturaApplication = 'Avatar Videos'

    GROUP BY 1, 2
)

SELECT
    pid_name,
    ROUND((COUNT(DISTINCT CASE WHEN active_days >= 2 THEN kuserId END) * 100.0) / COUNT(DISTINCT kuserId)) AS returning_user_percentage
FROM active_users

GROUP BY 1
ORDER BY 2 DESC
