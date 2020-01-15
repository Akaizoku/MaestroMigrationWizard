-- Variables
DECLARE @status   INT
DECLARE @deleted  INT
DECLARE @mex_id   INT
-- Initialise output
SET @deleted = 0
-- Select business rule ID
SELECT  @mex_id     = max(mex_id)
FROM    t_mex_type
WHERE   mex_type    = #{mex_type}
AND     version_id  = #{version_id}
-- Check that business rule exists
IF @mex_id IS NOT NULL
BEGIN
  -- Remove business rule
  EXEC @status = p_mex_del_type
    @mex_id,
    @purge    = 1,
    @deleted  = @deleted OUTPUT
END
-- Result
SELECT [deleted] = @deleted
