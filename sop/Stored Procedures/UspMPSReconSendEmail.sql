
CREATE PROC [sop].[UspMPSReconSendEmail]  
  
(@EmailBody NVARCHAR(MAX),  
 @EmailFrom VARCHAR(255) = 'snop.ninjas@intel.com',  
 @EmailTo VARCHAR(255) = 'snop.ninjas@intel.com',  
 @EmailCC VARCHAR(255) = 'snop.ninjas@intel.com',  
 @EmailSubject NVARCHAR(255)  
)  
AS  
----/*********************************************************************************
----	Purpose: This sproc emails  

----    Date        User            Description
----***************************************************************************-
----    2023-06-16	atairumx        Initial Release

----*********************************************************************************/
BEGIN  
    SET NOCOUNT ON  
  
    /*-- START TEST HARNESS  
    --EXEC dbo.UspMPSReconSendEmail @EmailBody='This is a testing of dbmail from dbaas server, please ignore',  @EmailCC='',@EmailSubject='Test Email- please ignore -'  
     -- END TEST HARNESS */  
  
    -- Variables  
    SET @EmailBody = @EmailBody + '<BR><BR>'   
        + '<BR>Job kicked off from:   ' + HOST_NAME()   
        + '<BR>User IDSID:            ' + SYSTEM_USER  
        + '<BR>Completion time (PST): ' + CONVERT(VARCHAR(30), GETDATE(), 121)  
  
 SET @EmailSubject= @EmailSubject+ ' from Server: ' + @@SERVERNAME + ' Database: ' + DB_NAME()  
  
 SET @EmailTo = 'ana.paulax.tairum@intel.com'   
 SET @EmailCC = 'ana.paulax.tairum@intel.com'    
  
 --IF (HOST_NAME() = 'ATAIRUMX-MOBL')   
 --BEGIN   
 -- SET @EmailTo = 'ana.paulax.tairum@intel.com'   
 -- SET @EmailCC = 'ana.paulax.tairum@intel.com'     
 --END  

    -- Send the Email  
    EXEC msdb.dbo.sp_send_dbmail  
        @profile_name = 'dbaas'  
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