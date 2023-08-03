CREATE PROC dbo.UspSendEmail  
(
	@EmailBody NVARCHAR(MAX),  
	@EmailFrom VARCHAR(255) = 'dBaas',
	@EmailTo VARCHAR(255) = 'shaobin.liu@intel.com',  --Need a PDL
	@EmailCC VARCHAR(255) = NULL,  
	@EmailSubject NVARCHAR(255)  
)  
AS  
/************************************************************************************************  
This sproc emails   
************************************************************************************************/  
BEGIN  
    SET NOCOUNT ON  
   
/*-- START TEST HARNESS  
    EXEC dbo.UspSendEmail @EmailBody='Success', @EmailFrom ='dBaas', @EmailSubject='Test Email'  
-- END TEST HARNESS */  
  
    -- Variables  
    SET @EmailBody = @EmailBody + '<BR><BR>'   
        + '<BR>Job kicked off from:   ' + HOST_NAME()   
        + '<BR>User IDSID:            ' + SYSTEM_USER  
        + '<BR>Completion time (PST): ' + CONVERT(VARCHAR(30), GETDATE(), 121)  
  
	SET @EmailSubject= @EmailSubject+ ' on Server: ' + @@SERVERNAME + ' Database: ' + DB_NAME()  
  
    -- Send the Email  
    EXEC msdb.dbo.sp_send_dbmail  
		@profile_name = @EmailFrom  
		, @recipients = @EmailTo  
		, @copy_recipients = @EmailCC  
		, @subject = @EmailSubject  
		, @body = @EmailBody  
		, @body_format = 'HTML'  
		, @importance = 'High'  
		, @sensitivity = 'Confidential'  
		, @query_no_truncate = 1  
  
    SET NOCOUNT OFF  
END  