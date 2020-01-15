SELECT    mex_type    AS 'Type',
          version_id  AS 'Version'
FROM      t_mex_type
WHERE     is_current = 1
ORDER BY  mex_type ASC;
