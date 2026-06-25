SELECT
nvp1.ovp_raw.partner.partner_name AS pid_name,
nvp1.ovp_raw.application_events.`urlParts.domain` AS domain,
COUNT(DISTINCT `kuserId`) AS potential_creators
FROM nvp1.ovp_raw.application_events
INNER JOIN nvp1.ovp_raw.partner ON partnerId = Id

WHERE partition_date >= CURRENT_DATE - INTERVAL '92 days'
AND `urlParts.domain` IN ('mediaspace.ccu.edu','videos.saskpolytech.ca','video.uark.edu','mediaspace.ccu.edu','csulb.mediaspace.kaltura.com','video.olivet.edu','video.maine.edu','media1.allspringglobal.com','video.square.com','watch.liberty.edu','video.maine.edu')
AND kalturaApplication = 'KMS'
AND eventVar2 in (
    'My Media',
    'Add - Upload',
    'Add - Capture',
    'Launch Editor - Media edit page',
    'Add - Youtube',
    'Replace Media',
    'Create - Header',
    'My-Media Create - Header',
    'Header Menu - My Media',
    'My Media - DS',
    'Entry Edit'
    )

GROUP BY 1, 2
ORDER BY 3 DESC
