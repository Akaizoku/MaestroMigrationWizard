USE master
GO
DECLARE @sql		varchar(max)
DECLARE @new_db varchar(500)
SELECT	@new_db = '#{Database}'

-- drop p_z_mex and p_z_srp procedures on financial studio database
SELECT @sql = '
	USE ' + @new_db + '
	DECLARE @proc_name VARCHAR(1000)
	DECLARE @sql2 VARCHAR(2000)
	-- declare and fill the cursor
	DECLARE c_drop_mex_procs CURSOR LOCAL FAST_FORWARD READ_ONLY FOR SELECT name FROM sysobjects WHERE (name LIKE ''p_z_mex%'' OR name LIKE ''p_z_srp%'')
	-- open the cursor and load the first record into variables
	OPEN c_drop_mex_procs
	FETCH NEXT FROM c_drop_mex_procs INTO @proc_name
	-- run through the cursor
	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		IF (@@FETCH_STATUS <> -2)
		BEGIN
			SELECT @sql2 = ''DROP PROCEDURE [''+ @proc_name + '']''
			EXEC (@sql2)
		END -- IF
		FETCH NEXT FROM c_drop_mex_procs INTO @proc_name
	END -- WHILE
	CLOSE c_drop_mex_procs
	DEALLOCATE c_drop_mex_procs'
EXEC (@sql)

--rebuild all maestro rules
SELECT @sql = '
	USE ' + @new_db + '
	DECLARE @mexid d_id
	DECLARE mexid CURSOR FAST_FORWARD READ_ONLY FOR SELECT mex_id FROM t_mex_type WHERE is_current = 1
	OPEN mexid
	FETCH NEXT FROM mexid INTO @mexid
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXECUTE p_mex_gen_cluster
					@mex_id = @mexid,
					@cluster_id = NULL,
					@debug = 0,
					-- @use_encryption = 1,
					@use_cursor = default
		FETCH NEXT FROM mexid INTO @mexid
	END
	CLOSE mexid
	DEALLOCATE mexid'
EXEC (@sql)
