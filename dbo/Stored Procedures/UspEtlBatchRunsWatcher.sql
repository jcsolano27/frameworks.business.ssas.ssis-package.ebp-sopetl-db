----/*********************************************************************************        
             
----    Purpose:	TERMINATING BATCH RUNS THAT ARE BEING EXECUTED FOR LONGER THAN ONE
----    			HOUR AND ALERTING THE DEVELOPERS' TEAM ABOUT THE ISSUE VIA E-MAIL
      
----    SourceTables: [dbo].[EtlBatchRuns]
        
----    Date			User            Description        
----***********************************************************************************        
----	2023-02-20		caiosanx		INITIAL RELEASE      
----***********************************************************************************/      

CREATE   PROC dbo.UspEtlBatchRunsWatcher
WITH EXEC AS OWNER
AS

SET NOCOUNT ON

DECLARE @TestTable TABLE
(
    BatchRunId INT,
    TableList VARCHAR(MAX),
	StartedOn DATETIME,
	RunningTime INT,
	[Status] TINYINT
);

INSERT @TestTable
(
    BatchRunId,
    TableList,
    StartedOn,
    RunningTime,
	[Status]
)
SELECT DISTINCT
       BatchRunId,
       T.value TableList,
	   COALESCE(BatchStartedOn, CreatedOn) StartedOn,
	   DATEDIFF(MINUTE, COALESCE(BatchStartedOn, CreatedOn), GETDATE())RunningTime,
	   BatchRunStatusId
FROM dbo.EtlBatchRuns
CROSS APPLY STRING_SPLIT(TableList, '|') T
WHERE BatchRunStatusId IN ( 2, 3 )
      AND DATEDIFF(MINUTE, COALESCE(BatchStartedOn, CreatedOn), GETDATE()) > 60
      AND TestFlag = 0;

IF
(
    SELECT COUNT(*)FROM @TestTable
) > 0
BEGIN
    DECLARE @SUBJECT VARCHAR(1000)
        = (CONCAT(CASE @@SERVERNAME WHEN 'D1OR1SQL104\SQL01' THEN 'DEV ENVIRONMENT' WHEN 'D1OR1SQL110\SQL01' THEN 'QA ENVIRONMENT' WHEN 'd1fm1sql331\SQL01' THEN 'BENCH ENVIRONMENT' WHEN 'p1fm1sql393\SQL01' THEN 'PRODUCTION ENVIRONMENT' END, ' - EtlBatchRuns PROCESSING ERROR ON ', @@SERVERNAME, ' - ', 'SVD Database - ',CAST(GETDATE() AS DATE)));

    DECLARE @CMD NVARCHAR(MAX)
        =
            (
                SELECT DISTINCT
                       CONCAT(	 'UPDATE dbo.EtlBatchRuns SET BatchRunStatusId = 5 WHERE BatchRunId = ',
                                 BatchRunId,
                                 '; '
                             )
                FROM @TestTable
                FOR XML PATH('')
            );

    EXEC (@CMD);

DECLARE @BODY NVARCHAR(MAX) =  
	N'<HEAD>'+
	N'	<STYLE>'+
	N'		table, th, td 	{'+
	N'						border: 1px solid black;'+
	N'						border-collapse: collapse;'+
	N'						text-align: center;'+
	N'						font-size: 10pt;'+
	N'						}'+
	N'						.no-border-forced { border: 0px !important; }?'+
	N'	</STYLE>'+
	N'</HEAD>'+
	N'<BODY>'+
	N'<TABLE  class=''no-border-forced'' style="width: 623px;" border=0><TR class=''no-border-forced''><TD  class=''no-border-forced'' STYLE="width: 100%; text-align: center;"><P><STRONG><CENTER>Please, <font color="red">do not reply</font> this message.</CENTER></STRONG></P></TD></TR></TABLE>'+
	N'<TABLE  class=''no-border-forced'' STYLE="width: 623px;" border="0" cellspacing="0" cellpadding="0"><TBODY><TR class=''no-border-forced''><TD  class=''no-border-forced'' STYLE="width: 100%; text-align: center;">'+
	N'<img src="data:image/jpeg;base64,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">'+
	N'</TD></TR></TBODT></TABLE>'+
	N'<TABLE  class=''no-border-forced'' style="width: 623px;" border=0><TR class=''no-border-forced''><TD  class=''no-border-forced'' STYLE="width: 100%; text-align: center;"><P>'+
	CASE WHEN (SELECT COUNT(*) FROM @TestTable) = 1 THEN 'There was a batch with status 2, or 3 on [EtlBatchRuns] for longer than one hour and were automatically terminated. The issue happened on the following item on instance ' + @@SERVERNAME + ':' ELSE 'There were batches with status 2, or 3 on [EtlBatchRuns] for longer than one hour and were automatically terminated. The issue happened on the following items on instance ' + @@SERVERNAME + ':' END+
	'</P></TD></TR></TABLE></TABLE><BR><BR>'+
	
	N'<TABLE style="width: 623px;">'+
	N'	<TR>'+
	N'		<TH STYLE=''BACKGROUND: #0070c0; COLOR: #FFFFFF''>BatchRunId</TH>'+
	N'		<TH STYLE=''BACKGROUND: #0070c0; COLOR: #FFFFFF''>TableName</TH>'+
	N'		<TH STYLE=''BACKGROUND: #0070c0; COLOR: #FFFFFF''>StartedOn</TH>'+
	N'		<TH STYLE=''BACKGROUND: #0070c0; COLOR: #FFFFFF''>RunningTime</TH>'+
	N'		<TH STYLE=''BACKGROUND: #0070c0; COLOR: #FFFFFF''>Status</TH>'+
	N'	</TR>'+
	CAST(
	(SELECT	F.BatchRunId TD,
	'',
	F.TableList TD,
	'',
	F.StartedOn TD,
	'',
	CONCAT(F.RunningTime, ' MINUTES') TD,
	'',
	F.Status TD
	FROM @TestTable F
	ORDER BY F.BatchRunId
	FOR XML PATH('TR'),TYPE)
	AS NVARCHAR(MAX))+
	N'</TABLE>'+
	N'<BR/>'+
	N'<table style="height: 100px; width: 623px; border-collapse: collapse; background-color: #0070c0;" border="0" cellspacing="0" cellpadding="0"><tbody><tr><td style="width: 100%; text-align: center;">'+
	N'<p style="text-align: center; margin: 0in; font-size: 11pt; font-family: Calibri, sans-serif;"><span class="MsoFootnoteReference"><span style="font-size: 8pt; font-family: &#39;Intel Clear&#39;, sans-serif; color: white;">Intel Confidential – internal use only.</span></span></p>'+
	N'<p style="text-align: center; margin: 0in; font-size: 11pt; font-family: Calibri, sans-serif;"><span style="color: #ffffff;"><a style="color: #ffffff; text-decoration: underline;" title="Legal notices" href="https://www.intel.com/content/www/us/en/legal/trademarks.html?iid&#61;CorporateV3&#43;Foote" rel="nofollow"><span class="MsoFootnoteReference"><span style="font-size: 8pt; font-family: &#39;Intel Clear&#39;, sans-serif;">Legal </span></span><span style="font-size: 8pt; font-family: &#39;Intel Clear&#39;, sans-serif;">n<span class="MsoFootnoteReference"><span style="font-family: &#39;Intel Clear&#39;, sans-serif;">otices</span></span></span></a></span></p>'+
	N'	</TR>'+
	N'	</TBODY>'+
	N'</TABLE>'+
	N'<HR/>'+
	N'<BR><SMALL>Intel and the Intel logo are trademarks of Intel Corporation or its subsidiaries in the U.S. and/or other countries.<SMALL>';

EXEC MSDB.DBO.SP_SEND_DBMAIL
	@PROFILE_NAME = 'dBaas',
	@RECIPIENTS='snop.ninjas@intel.com; lucas.borges.de.sousa@intel.com',
	@SUBJECT = @SUBJECT,
	@BODY = @BODY,
	@BODY_FORMAT = 'HTML',
	@IMPORTANCE = 'HIGH',
	@SENSITIVITY = 'CONFIDENTIAL'  
END;