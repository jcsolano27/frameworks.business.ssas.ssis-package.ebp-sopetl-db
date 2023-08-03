CREATE PROC [dbo].[UspMPSReconSendEmail]

(@EmailBody NVARCHAR(MAX),
 @EmailFrom VARCHAR(255) = 'powerninjas@intel.com',
 @EmailTo VARCHAR(255) = 'powerninjas@intel.com',
 @EmailCC VARCHAR(255) = 'powerninjas@intel.com',
 @EmailSubject NVARCHAR(255)
)
AS
/************************************************************************************************
This sproc emails 
************************************************************************************************/
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

	SET @EmailTo = 'snop.ninjas@intel.com' 
	SET @EmailCC = 'snop.ninjas@intel.com' 


	IF (HOST_NAME() = 'JCSOLANO-MOBL') 
	BEGIN 
		SET @EmailTo = 'juan.solano.florez@intel.com' 
		SET @EmailCC = 'juan.solano.florez@intel.com' 
	END
	
	IF (HOST_NAME() = 'SLIU5-MOBL') 
	BEGIN 
		SET @EmailTo = 'shaobin.liu@intel.com' 
		SET @EmailCC = 'shaobin.liu@intel.com' 
	END

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
