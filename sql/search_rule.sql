SELECT  ISNULL(max(mex_id), 0) AS mex_id
FROM    t_mex_type
WHERE   mex_type    = #{mex_type}
AND     version_id  = #{version_id};
