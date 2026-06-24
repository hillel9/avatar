WITH active_users AS (
    SELECT
        nvp1.ovp_raw.partner.partner_name AS pid_name,
        kuserId,
        COUNT(DISTINCT partition_date) AS active_days
    FROM nvp1.ovp_raw.application_events
    INNER JOIN nvp1.ovp_raw.partner ON partnerId = Id

    WHERE partition_date >= CURRENT_DATE - INTERVAL '92 days'
    AND nvp1.ovp_raw.application_events.partnerId IN (2167581,2189801,3193793,4170533,2314871,1714341,1889041,2167551,1315742)
    AND kalturaApplication = 'Avatar Videos'

    GROUP BY 1, 2
)

SELECT
    pid_name,
    ROUND((COUNT(DISTINCT CASE WHEN active_days >= 2 THEN kuserId END) * 100.0) / COUNT(DISTINCT kuserId)) AS returning_user_percentage
FROM active_users

GROUP BY 1
ORDER BY 2 DESC
