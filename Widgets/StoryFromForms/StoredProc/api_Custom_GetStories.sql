USE [MinistryPlatform]
GO
/****** Object:  StoredProcedure [dbo].[api_Custom_GetStories]    Script Date: 9/27/2024 10:22:59 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[api_Custom_GetStories]
  @DomainID int
, @Username nvarchar(75) 

AS
BEGIN

--Kevin McCord
--2024-07-25
--Return "stories" or "prayer requests" from a custom form to a custom widget.

--TBD: show all stories?  Immediately?  Do some need approval? All need approval?
--TBD: Show all stories to all visitors? Do we hide some stories from anonymous visitors? Show some only to staff?

DECLARE @DefaultContactID INT = 2

DECLARE @FormID INT = 202 --Form_ID of the Form you want responses from
DECLARE @StoryFieldID INT = 3290 --The field ID from the form above that holds the long-form text of the story
DECLARE @Top INT = 3 --how many stories to return in the dataset
DECLARE @Since DateTime = GETDATE() - 120 --only get responses from past 120 days

SELECT Top (@Top) FR.Form_Response_ID, FR.Response_Date
--, ISNULL(FR.First_Name,'Anonymous') AS First_Name, FR.Last_Name
--, Short_Name = ISNULL(FR.First_Name + SPACE(1) + LEFT(Fr.Last_Name,1),'Anonymous')
, Response
, Case WHEN U.User_Name = @UserName THEN 1 ELSE 0 END AS User_Is_Story_Author 
FROM Form_Responses FR 
 INNER JOIN Contacts C ON C.Contact_ID = FR.Contact_ID AND C.Contact_ID NOT IN (@DefaultContactID)
 INNER JOIN Form_Response_Answers Story ON Story.Form_Response_ID = FR.Form_Response_ID AND Story.Form_Field_ID = @StoryFieldID
 LEFT OUTER JOIN dp_Users U ON U.User_ID = C.User_Account 
WHERE FR.Form_ID = @FormID 
 AND Response IS NOT NULL
 AND FR.Response_Date >= @Since
ORDER BY NEWID()
--AND Fr.Request_Approved = 1 --TBD how to set entires to 1? --TBD add a way to filter based on a custom approved field

END
