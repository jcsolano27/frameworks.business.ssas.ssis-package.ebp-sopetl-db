


CREATE PROCEDURE [dbo].[UspGuiEsdFetchLoadStatusByTableLoadGroup](@EsdVersionId INT, @TableLoadGroupId INT)
AS
--DECLARE @EsdVersionId INT = 23
--DECLARE @TableLoadGroupId INT = 5
/*  Test Harness
	 dbo.[UspGuiEsdFetchLoadStatusByTableLoadGroup] 150, 13

*/
DECLARE @EsdVersionCreateDate DATETIME, @TableLoadGroupName VARCHAR(100)

SELECT @EsdVersionCreateDate = CreatedOn FROM dbo.EsdVersions WHERE EsdVersionId = @EsdVersionId;
SELECT @TableLoadGroupName =  TableLoadGroupName FROM [dbo].[EtlTableLoadGroups] WHERE TableLoadGroupId = @TableLoadGroupId;

--------------------------------------------- Pull Tables/Apps associated with Table Load Group
IF OBJECT_ID('tempdb..#tmpTablesByTableLoadGroup') IS NOT NULL DROP TABLE #tmpTablesByTableLoadGroup
CREATE TABLE #tmpTablesByTableLoadGroup(RowNumber INT IDENTITY(1,1), TableName VARCHAR(100), SourceApplicationId INT)

	INSERT INTO #tmpTablesByTableLoadGroup(TableName,SourceApplicationId)

	SELECT Distinct TableName,SourceApplicationId FROM(
		SELECT 
			TLG.TableLoadGroupId
			,TLG.TableLoadGroupName
			,GM.TableId
			,TB.TableName
			,TB.SourceApplicationId
			,SA.SourceApplicationName
		FROM [dbo].[EtlTableLoadGroups] TLG
		JOIN [dbo].[EtlTableLoadGroupMap] GM
			ON GM.TableLoadGroupId = TLG.TableLoadGroupId
		JOIN [dbo].[EtlTables] TB
			ON TB.TableId = GM.TableId
		JOIN [dbo].[EtlSourceApplications] SA
			ON SA.SourceApplicationId = TB.SourceApplicationId
		WHERE TLG.GroupType = 'ESD'
			AND TLG.TableLoadGroupId = @TableLoadGroupId
			AND TB.Active=1
			AND TB.TableName NOT IN ('dbo.ActualFgMovements','dbo.ActualSupply')
		) T
	
DECLARE @TableColumnMap TABLE(RowNum INT IDENTITY(1,1), ColumnName VARCHAR(100),TableName VARCHAR(100), AppId INT);
DECLARE @ThisTable VARCHAR(100);
DECLARE @ThisAppId INT;
DECLARE @ThisColumnIndicator VARCHAR(100);
DECLARE @CursorTbl TABLE(TableName VARCHAR(100), SourceApplicationId INT);
Declare @SqlStmt NVARCHAR(MAX);
DECLARE @ThisRow INT;
--SELECT * FROM #tmpTablesByTableLoadGroup  TBL

DECLARE cur CURSOR LOCAL FOR
(
	SELECT RowNumber FROM #tmpTablesByTableLoadGroup --TableName, SourceApplicationId FROM #tmpTablesByTableLoadGroup
)
	OPEN cur
			FETCH NEXT FROM cur INTO @ThisRow
			WHILE @@FETCH_STATUS = 0 BEGIN
				SELECT @ThisTable = TableName FROM #tmpTablesByTableLoadGroup WHERE RowNumber = @ThisRow;
				SELECT @ThisAppId = SourceApplicationId FROM #tmpTablesByTableLoadGroup  WHERE RowNumber = @ThisRow;
					INSERT INTO @TableColumnMap (ColumnName,TableName,AppId)
					SELECT ColumnName, TableName,ApplicationId 
						FROM(
							SELECT      c.name  AS 'ColumnName'
										,@ThisTable AS 'TableName' --t.name AS 'TableName'
										,@ThisAppId AS ApplicationId
										,RANK() OVER(PARTITION BY t.Name,@ThisAppId ORDER BY c.name DESC) AS RANKING --Column Name Descending so that EsdVersionId Trumps CreatedOn
							FROM        sys.columns c
							JOIN        sys.tables  t   ON c.object_id = t.object_id
							WHERE       c.name IN ('EsdVersionId','CreatedOn')
								AND t.name = RIGHT(@ThisTable,LEN(@ThisTable)-4)
						)  T1
					WHERE Ranking = 1
				FETCH NEXT FROM cur INTO @ThisRow
			END
	CLOSE cur
----------------------------------------------------------------------------------------------------------------------
-- Next, User Cursor to write SQL Statements for each table to find out if it has been loaded
DECLARE @SqlRow INT;
DECLARE @ThisColumn VARCHAR(100);
DECLARE @OutputTable TABLE(TableName VARCHAR(100),ApplicationId INT,LoadedForVersion BIT, LastUploadDate DATETIME);

DECLARE CurSQLWrite CURSOR LOCAL FOR
(
	SELECT RowNum FROM @TableColumnMap
)
	OPEN CurSQLWrite

			FETCH NEXT FROM CurSQLWrite INTO @SqlRow
			WHILE @@FETCH_STATUS = 0 BEGIN
				SELECT @ThisTable = TableName FROM @TableColumnMap WHERE RowNum = @SqlRow;
				SELECT @ThisAppId = AppId FROM @TableColumnMap  WHERE RowNum = @SqlRow;
				SELECT @ThisColumn = ColumnName FROM @TableColumnMap WHERE RowNum = @SqlRow;
				
			IF @ThisColumn = 'EsdVersionId'
				BEGIN
					SET @SqlStmt = 'SELECT TOP(1) TableName, '''+CAST(@ThisAppId AS VARCHAR)+''' 
									AS SourceApplicationId, CASE WHEN BS.EsdVersionId IS NULL THEN 0 ELSE 1 END AS Loaded, CreatedOn AS LastUploadDate
									FROM (SELECT '''+@ThisTable + ''' AS TableName) T1
									LEFT OUTER JOIN '+@ThisTable+' BS 
									ON EsdVersionId = '+CAST(@EsdVersionId AS VARCHAR)+' '
				
				END
			ELSE IF @ThisColumn = 'CreatedOn'
				BEGIN
					SET @SqlStmt = 'SELECT TOP(1)  T1.TableName, '''+CAST(@ThisAppId AS VARCHAR)+''' 
									AS SourceApplicationId, CASE WHEN BS.CreatedOn IS NULL THEN 0 ELSE 1 END AS Loaded, CreatedOn AS LastUploadDate
									FROM (SELECT '''+@ThisTable + ''' AS TableName) T1
									LEFT OUTER JOIN '+@ThisTable+' BS 
									ON CreatedOn >= '''+CAST(@EsdVersionCreateDate AS VARCHAR)+''' '
				END

				INSERT INTO @OutputTable
				EXEC(@SqlStmt);
					
				FETCH NEXT FROM CurSQLWrite INTO @SqlRow
			END
	CLOSE CurSQLWrite		

	DECLARE @NumOutputRows INT, @NumLoadedRows INT, @AllLoaded BIT
	
	SELECT @NumOutputRows = COUNT(1)  FROM @OutputTable
	SELECT @NumLoadedRows = COUNT(1) FROM @OutputTable WHERE LoadedForVersion =1 
	SELECT @AllLoaded = CASE WHEN @NumOutputRows = @NumLoadedRows THEN 1 ELSE 0 END

	-------------- Return Data
	SELECT DISTINCT
		@TableLoadGroupId AS TableLoadGroupId, 
		@TableLoadGroupName AS TableLoadGroupName,
		TableName ,
		SA.SourceApplicationName ,
		LoadedForVersion AS IsLoadedForVersion , 
		LastUploadDate AS LastLoadedDate, 
		@AllLoaded AS IsVersionLoadComplete 
	FROM @OutputTable OT
	JOIN [dbo].[EtlSourceApplications] SA
		ON OT.ApplicationId = SA.SourceApplicationId
	ORDER BY TableName ASC





