WITH user_activity AS (
    SELECT
        kuserId,
        COUNT(DISTINCT partition_date) AS active_days
    FROM nvp1.ovp_raw.application_events
    WHERE partition_date >= CURRENT_DATE - INTERVAL '31 days'
        AND kalturaApplication = 'Avatar Videos'
        AND kuserId != 'Unknown'
    GROUP BY 1
)
SELECT
    COUNT(DISTINCT kuserId) AS total_unique_users,
    COUNT(DISTINCT CASE WHEN active_days >= 2 THEN kuserId END) AS returning_users,
    (COUNT(DISTINCT CASE WHEN active_days >= 2 THEN kuserId END) * 100.0) / COUNT(DISTINCT kuserId) AS returning_user_percentage
FROM user_activity;
