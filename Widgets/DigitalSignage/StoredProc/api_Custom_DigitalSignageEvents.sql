USE [MinistryPlatform]
GO
/****** Object:  StoredProcedure [dbo].[api_Custom_DigitalSignageEvents]    Script Date: 8/22/2024 10:18:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[api_Custom_DigitalSignageEvents]
	@DomainID int
	,@Username nvarchar(75) = NULL
    ,@LocationID int = NULL
AS
BEGIN

--TBD Filter on Location ID

SELECT E.Event_ID, E.Event_Title, E.Event_Start_Date, ET.Event_Type AS Event_Type
, ISNULL('Offsite', L.Location_Name) AS Location_Name
, ISNULL('None', R.Room_Name) AS Room_Name
, ISNULL('TBD', BF.Floor_Name) AS Floor_Name

FROM Events E
LEFT JOIN Locations L ON L.Location_ID = E.Location_ID
LEFT JOIN Event_Types ET ON ET.Event_Type_ID = E.Event_Type_ID
INNER JOIN Programs P ON P.Program_ID = E.Program_ID
LEFT JOIN Event_Rooms ER ON E.Event_ID = ER.Room_ID --AND ER.__Primary_Reservation = 1
LEFT JOIN Rooms R ON R.Room_ID = ER.Room_ID
LEFT JOIN Building_Floors BF ON BF.Building_Floor_ID = R.Building_Floor_ID

WHERE E.Event_Start_Date BETWEEN DATEADD(MINUTE, -60, GETDATE()) AND DATEADD(MINUTE, 1180, GETDATE())
AND E.Location_ID = @LocationID
AND E.Cancelled <> 1 
AND E._Approved <> 0 
--AND E.Event_Type_ID NOT IN (38)

--SELECT * FROM Event_Types

END
