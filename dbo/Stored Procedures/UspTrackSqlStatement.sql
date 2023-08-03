----/*********************************************************************************

----    Purpose:        The objective here is helping developers to track the object dependency inside the SVD database

----    Called by:      Manual

----    Result sets:    List of scripts that use the searched object
----					List of text objects that use the searched object

----	Parameters

----			@Help				-> Users can get use examples for the procedure
----			@TableName			-> Name of the table that the user needs to alter
----			@SearchTerm1		-> Fine tune the search by using more details than only the table name
----			@SearchTerm2		-> Fine tune the search by using more details than only the table name

----    Date        User            Description
----***************************************************************************-
----	2023-05-19	caiosanx		Initial Release
----*********************************************************************************/

CREATE   PROC [dbo].[UspTrackSqlStatement]
    @Help BIT = 0,
    @TableName NVARCHAR(256) = 'NO VALUE SET BY USER',
    @SearchTerm1 NVARCHAR(256) = 'NO VALUE SET BY USER',
    @SearchTerm2 NVARCHAR(256) = 'NO VALUE SET BY USER'
WITH EXEC AS OWNER
AS
SET NOCOUNT ON;

IF @Help = 0
BEGIN
    DECLARE @WHERE NVARCHAR(4000)
        = CONCAT('WHERE ParameterTable.RefferenceTableName LIKE CONCAT(''%'', ''', @TableName, ''', ''%'')');

    IF @SearchTerm1 <> 'NO VALUE SET BY USER'
       AND @SearchTerm2 = 'NO VALUE SET BY USER'
        SET @WHERE
            = CONCAT(
                        'WHERE ParameterTable.RefferenceTableName LIKE CONCAT(''%'', ''',
                        @TableName,
                        ''',''%'') AND ParameterTable.SqlStatement LIKE CONCAT(''%'', ''',
                        @SearchTerm1,
                        ''',''%'')'
                    );
    IF @SearchTerm1 <> 'NO VALUE SET BY USER'
       AND @SearchTerm2 <> 'NO VALUE SET BY USER'
        SET @WHERE
            = CONCAT(
                        'WHERE ParameterTable.RefferenceTableName LIKE CONCAT(''%'', ''',
                        @TableName,
                        ''',''%'') AND ParameterTable.SqlStatement LIKE CONCAT(''%'', ''',
                        @SearchTerm1,
                        ''',''%'') AND ParameterTable.SqlStatement LIKE CONCAT(''%'', ''',
                        @SearchTerm2,
                        ''',''%'');'
                    );

    DECLARE @CMD NVARCHAR(MAX)
        = CONCAT(
                    'SELECT ParameterTable.ParameterTableName,
				   ParameterTable.ParameterTableColumnName,
				   ParameterTable.ParameterTablePrimaryKeyName,
				   ParameterTable.ParameterTablePrimaryKeyValue,
				   ParameterTable.RefferenceTableName,
				   ParameterTable.SqlStatement
			FROM
			(
				SELECT ''[dq].[CheckParameter]'' ParameterTableName,
					   ''[SourceMainScript]'' ParameterTableColumnName,
					   ''[CheckParameterId]'' ParameterTablePrimaryKeyName,
					   CheckParameterId ParameterTablePrimaryKeyValue,
					   CONCAT(SourceTableName, '' | '', DestinationTableName) RefferenceTableName,
					   SourceMainScript SqlStatement
				FROM dq.CheckParameter
				UNION
				SELECT ''[dq].[CheckParameter]'' ParameterTableName,
					   ''[SourceDetailedScript]'' ParameterColumnName,
					   ''[CheckParameterId]'' ParameterTablePrimaryKeyName,
					   CheckParameterId ParameterTablePrimaryKey,
					   CONCAT(SourceTableName, '' | '', DestinationTableName) RefferenceTableName,
					   SourceDetailedScript
				FROM dq.CheckParameter
				UNION
				SELECT ''[dq].[CheckParameter]'' ParameterTableName,
					   ''[DestinationMainScript]'' ParameterColumnName,
					   ''[CheckParameterId]'' ParameterTablePrimaryKeyName,
					   CheckParameterId ParameterTablePrimaryKey,
					   CONCAT(SourceTableName, '' | '', DestinationTableName) RefferenceTableName,
					   DestinationMainScript
				FROM dq.CheckParameter
				UNION
				SELECT ''[dq].[CheckParameter]'' ParameterTableName,
					   ''[DestinationDetailedScript]'' ParameterColumnName,
					   ''[CheckParameterId]'' ParameterTablePrimaryKeyName,
					   CheckParameterId ParameterTablePrimaryKey,
					   CONCAT(SourceTableName, '' | '', DestinationTableName) RefferenceTableName,
					   DestinationDetailedScript
				FROM dq.CheckParameter
				UNION
				SELECT ''[dbo].[EtlTables]'' ParameterTableName,
					   ''[PurgeScript]'' ParameterColumnName,
					   ''[TableId]'' ParameterTablePrimaryKeyName,
					   TableId ParameterTablePrimaryKey,
					   CONCAT(TableName, '' | '', StagingTables) RefferenceTableName,
					   PurgeScript
				FROM dbo.EtlTables
			) ParameterTable ',
                    @WHERE
                );

    EXEC (@CMD);

    SET @WHERE = CONCAT('AND M.DEFINITION LIKE ''%'' + ''', @TableName, '''+''%''');

    IF @SearchTerm1 <> 'NO VALUE SET BY USER'
       AND @SearchTerm2 = 'NO VALUE SET BY USER'
        SET @WHERE
            = CONCAT(
                        'AND M.DEFINITION LIKE ''%'' + ''',
                        @TableName,
                        '''+''%''',
                        'AND M.DEFINITION LIKE ''%'' + ''',
                        @SearchTerm1,
                        '''+''%'''
                    );

    IF @SearchTerm1 <> 'NO VALUE SET BY USER'
       AND @SearchTerm2 <> 'NO VALUE SET BY USER'
        SET @WHERE
            = CONCAT(
                        'AND M.DEFINITION LIKE ''%'' + ''',
                        @TableName,
                        '''+''%''',
                        'AND M.DEFINITION LIKE ''%'' + ''',
                        @SearchTerm1,
                        '''+''%''',
                        'AND M.DEFINITION LIKE ''%'' + ''',
                        @SearchTerm2,
                        '''+''%'''
                    );

    SET @CMD
        = CONCAT(
                    'SELECT SCHEMA_NAME(O.schema_id) SchemaName,
					O.name ObjectName,
					O.type_desc ObjectType
			FROM sys.sql_modules M
				JOIN sys.objects O
					ON O.object_id = M.object_id WHERE O.name <> ''UspTrackSqlStatement''',
                    @WHERE
                );

    EXEC (@CMD);
END;

IF @Help = 1
BEGIN
    PRINT 'THIS STORED PROCEDURE WAS DESIGNED TO HELP DEVELOPERS TRACK THE USAGE OF SPECIFIC OBJECTS ON CODE THAT''S STORED AS DATA ON PARAMETER TABLES AND TRACK WHICH TEXT OBJECTS MIGHT BE USING THE SEARCHED OBJECTS.

BEFORE MAKING CHANGES ON THE STRUCTURE OF OBJECTS, SUCH AS CHANGING TABLE/COLUMN NAMES OR DROPPING TABLES AND COLUMNS, THIS PROCEDURE MUST BE EXECUTED TO MAKE SURE THE USERS CHANGES WILL NOT AFFECT ANY EXISTING PROCESSES AND HELP THEM MAP OTHER PLACES WHERE CHANGES MIGHT BE NECESSARY.

STORED PROCEDURE PARAMETERS

	@Help:				IGNORE THIS PARAMETER UNLESS YOU WANT TO READ THE HELP TEXT. FOR DISPLAYING HELP OPTIONS, THE PROC MUST BE EXECUTED USING -> EXEC [dbo].[UspTrackSqlStatement] @Help = 1
	@TableName:			NAME OF THE TABLE THE DEVELOPER PLANS TO ALTER. DON''T USE TEXT QUALIFIERS SUCH AS QUOTE MARKS OR BRACKETS, TEXT ONLY. DON''T USE SCHEMA NAMES. IT WILL WORK EVEN WHEN ONLY PART OF THE TABLE NAME IS TYPED. -> EXEC [dbo].[UspTrackSqlStatement] @TableName = ''TableName''
	@SearchTerm1:		ANY TERM THE DEVELOPER IS LOOKING FOR ON THE CODE STORED AS PARAMETERS. DON''T USE TEXT QUALIFIERS SUCH AS QUOTE MARKS OR BRACKETS, TEXT ONLY. IT WILL WORK EVEN WHEN ONLY PART OF THE TABLE NAME IS TYPED. -> EXEC [dbo].[UspTrackSqlStatement] @SearchTerm1 = ''Anything you are looking for''
	@SearchTerm2:		ANY TERM THE DEVELOPER IS LOOKING FOR ON THE CODE STORED AS PARAMETERS. DON''T USE TEXT QUALIFIERS SUCH AS QUOTE MARKS OR BRACKETS, TEXT ONLY. IT WILL WORK EVEN WHEN ONLY PART OF THE TABLE NAME IS TYPED. -> EXEC [dbo].[UspTrackSqlStatement] @SearchTerm2 = ''Anything you are looking for''

DEVELOPERS MUST USE AT LEAST ONE OF THE VARIABLES TO GET A USEFUL RESULT SET. IT''S POSSIBLE TO USE ALL VARIABLES AT THE SAME TIME TO FINE TUNE THE RESULTS:

EXEC [dbo].[UspTrackSqlStatement] @TableName = ''TableName'',
                                  @SearchTerm1 = ''Anything you are looking for'',
                                  @SearchTerm2 = ''Anything you are looking for'';

THERE ARE TWO RESULT SETS FOR THIS STORED PROCEDURE.

THE FIRST RESULT SET WILL DISPLAY THE FOLLOWING INFORMATION REGARDING SQL STATEMENTS THAT ARE STORED AS STRING ON PARAMETER TABLES:

	ParameterTableName:					NAME OF THE TABLE WHERE SQL STATEMENTS USING YOUR SEARCH TERMS IS STORED. DISPLAYED AS [Schema].[Table].
	ParameterTableColumnName:			NAME OF THE COLUMN WHERE SQL STATEMENTS USING YOUR SEARCH TERMS IS STORED. DISPLAYED AS [ColumnName].
	ParameterTablePrimaryKeyName:		NAME OF THE PRIMARY KEY COLUMN (OR COLUMNS FOR COMPOSITE PRIMARY KEYS) OF THE TABLE WHERE SQL STATEMENTS USING YOUR SEARCH TERMS IS STORED.
	ParameterTablePrimaryKeyValue:		VALUE OF THE PRIMARY KEY FOR THAT SPECIFIC ROW IN THE RESULTSET.
	RefferenceTableName:				NAME OF TABLES THE DEVELOPER IS CHANGING.
	SqlStatement:						THE COMPLETE SQL STATEMENT THAT USES THE DEVELOPER SEARCH TERMS.

THE SECOND RESULT SET WILL DISPLAY THE FOLLOWING INFORMATION REGARDING TEXT OBJECTS (VIEWS, PROCEDURES, TRIGGERS, FUNCTIONS) THAT MIGHT USE THE OBJECTS THE DEVELOPER IS CHANGING:

	SchemaName:							NAME OF THE SCHEMA FOR THE OBJECT
	ObjectName:							NAME OF THE OBJECT
	ObjectType:							TYPE OF THE OBJECT
'   ;
END;