-- Variables
DECLARE @mex_id INT
-- Select business rule ID
SELECT  @mex_id     = max(mex_id)
FROM    t_mex_type
WHERE   mex_type    = #{mex_type}
AND     version_id  = #{version_id}
-- Check that business rule exists
IF @mex_id IS NOT NULL
BEGIN
	-- Build business rule
	EXECUTE p_mex_gen_cluster
		@mex_id
END
