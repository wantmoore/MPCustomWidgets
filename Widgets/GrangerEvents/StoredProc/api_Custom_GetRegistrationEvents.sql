USE [MinistryPlatform]
GO

/****** Object:  StoredProcedure [dbo].[api_Custom_GetRegistrationEvents]    Script Date: 4/2/2026 3:38:39 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[api_Custom_GetRegistrationEvents]
	@DomainID int,
	@Username nvarchar(75) = null,
	@CongregationID INT = NULL,
	@MinistryID INT = NULL,
	@ProgramID INT = NULL,
	@Featured bit = 0, --0 means all
	@Keyword Nvarchar(100) = NULL, 
	@Reduceseriesto INT = 0

AS
BEGIN


	DECLARE @DomainTimeZone dp_TimeZone
	SELECT @DomainTimeZone = Time_Zone FROM dp_Domains WHERE Domain_ID = @DomainID

	DECLARE @DomainTime datetime
	SELECT @DomainTime = dbo.dp_ToLocalTime(GETUTCDATE(), @DomainTimeZone)

	/*
	EXEC [dbo].[api_Custom_GetRegistrationEvents]
	@DomainID =1,
	@Username ='kevmccord@gmail.com',
	@CongregationID = NULL,
	@MinistryID = NULL,
	@ProgramID = NULL,
	@Featured = 0, --0 means all
	@Keyword = NULL, 
	@Reduceseriesto = 3 --not yet operational
	*/


	--TBD @reduceseriesto logic needed  I did add "sequence_order" below.

	--Temp table to scope the events and get anything relevant to registration status.
	CREATE TABLE #RegEvents (Event_ID INT, Event_Start_Date DATETIME, Show_Registration_From DATETIME, Show_Registration_To DATETIME, Registration_Active BIT, Online_Registration_Product INT, External_Registration_URL Nvarchar(2048))
	INSERT INTO #RegEvents 
	SELECT E.Event_ID, E.Event_Start_Date
	/* the two dates here will determine if we are in the registration time frame*/
	, Show_Registration_From = COALESCE(E.Registration_Start, GETDATE())
	, Show_Registration_To = COALESCE(E.Registration_Hidden,E.Registration_End, E.Event_Start_Date)
	/*the follwoing values determine if registration is active/configured*/
	, E.Registration_Active, E.Online_Registration_Product, E.External_Registration_URL
	FROM Events E
	 INNER JOIN Programs Prog ON Prog.Program_ID = E.Program_ID 
	WHERE E.Event_End_Date >= @DomainTime --simplified from below, but could be problematic if an event is set to end well into the future.
	AND E.Cancelled = 0 
	AND E._Approved = 1 
	AND E._Web_Approved = 1
	AND E.Visibility_Level_ID = 4 /*TBD do we want staff/church for registration testing?*/
	AND E.Event_Type_ID IN (1,2,13,14,15,41,43) 	--TBD we shouldn't have hard coded event types.
	AND E.Congregation_ID = ISNULL(@CongregationID,E.Congregation_ID)
	AND E.Program_ID = ISNULL(@ProgramID,E.Program_ID)
	AND Prog.Ministry_ID = ISNULL(@MinistryID,Prog.Ministry_ID)
	AND (@Featured = 0 OR (E.Featured_On_Calendar = 1 AND @Featured = 1))
	ORDER BY E.Event_Start_Date ASC

	--TBD could introduce temp table index on event_ID

	CREATE TABLE #KeywordEvents (Event_ID INT)
	IF @Keyword IS NOT NULL
		BEGIN

		--build a list of events with the keyword
		INSERT INTO #KeywordEvents
		SELECT E.Event_ID 
		FROM Events E 
		INNER JOIN #RegEvents R ON R.Event_ID = E.Event_ID 
		WHERE  E.Event_Title LIKE '%' + @Keyword + '%'
		 OR E.Description LIKE '%' + @Keyword + '%'
		 OR E.Additional_Description LIKE '%' + @Keyword + '%'
		--TBD any more test strings to search?
	 
		--remove those without the keyword from scope
		DELETE FROM #RegEvents WHERE NOT EXISTS (SELECT 1 FROM #KeywordEvents K WHERE K.Event_ID = #RegEvents.Event_ID)

		END

	--This table does the work of checking if events in scope are in a series and whether registration option should be shown
	CREATE TABLE #RegEventsStatus (Event_ID INT, Show_Registration BIT, Registration_Message Nvarchar(100), Sequence_ID INT, Record_ID INT, Sequence_Order INT)
	INSERT INTO #RegEventsStatus 
	SELECT Event_ID
	 , Show_Registration = CASE WHEN RE.Registration_Active = 1 
										AND (RE.Online_Registration_Product IS NOT NULL OR RE.External_Registration_URL IS NOT NULL)
										AND GETDATE() BETWEEN Show_Registration_From AND Show_Registration_To 
								THEN 1
								ELSE 0 
								END
	, Registration_Message = CASE WHEN Online_Registration_Product IS NULL AND External_Registration_URL IS NULL THEN 'Registration not configured'
								WHEN Show_Registration_From > GETDATE() THEN 'Registration is not yet open'
								WHEN Show_Registration_To < GETDATE() THEN 'Registration has closed'
								WHEN Registration_Active = 0 THEN 'Registration is not active'
								ELSE NULL END
	 , SR.Sequence_ID, SR.Record_ID, Sequence_Order = CASE WHEN SR.Sequence_ID IS NULL THEN 1 ELSE  ROW_NUMBER() OVER (PARTITION BY SR.Sequence_ID ORDER BY RE.Event_Start_Date) END
	FROM #RegEvents RE
	LEFT JOIN dp_Sequence_Records SR ON RE.Event_ID = SR.Record_ID AND SR.Table_Name = 'Events'

	--TBD could introduce temp table index on event_ID

--Output from sproc goes here:

SELECT E.Event_ID, E.Event_Title, E.Event_Start_Date, E.Event_End_Date, RES.Sequence_ID, RES.Record_ID AS Sequence_Record_ID, RES.Sequence_Order, L.Location_Name, RES.Show_Registration, RES.Registration_Message, E.Registration_Active, E.Description, E.Additional_Description, E.Event_Type_ID,
/* CONCAT(E.Description,
    CASE 
        WHEN E.Description IS NOT NULL 
         AND E.Additional_Description IS NOT NULL 
        THEN '<br /><br />'
        ELSE '' 
    END,
    E.Additional_Description
) AS Description, */
P.Program_Name, C.Congregation_Name, E.Featured_On_Calendar, E.Program_ID, E.Congregation_ID, E.Registration_Active AS Show_Registration, E.Registration_Start, E.Registration_Hidden, E.Registration_End,Image_GUID = EF.Unique_Name,File_URL = CONCAT('https://', D.External_Server_Name, '/ministryplatformapi/files/')
FROM Events E
INNER JOIN #RegEventsStatus RES ON RES.Event_ID = E.Event_ID 
INNER JOIN Event_Types ET ON ET.Event_Type_ID = E.Event_Type_ID
INNER JOIN Programs P ON P.Program_ID = E.Program_ID
INNER JOIN Congregations C ON C.Congregation_ID = E.Congregation_ID
INNER JOIN dp_Domains D ON D.Domain_ID = @DomainID
LEFT JOIN Locations L ON L.Location_ID = E.Location_ID
LEFT OUTER JOIN dp_Files EF ON EF.Table_Name='Events' AND EF.Record_ID=E.Event_ID AND EF.Default_Image = 1 --probably needs default image handling if no file exists. roll up to program?
--ORDER BY E.Event_Start_Date ASC --not best practice, app should sort.

DROP TABLE #RegEvents 
DROP TABLE #RegEventsStatus 
DROP TABLE #KeywordEvents 






END
GO
