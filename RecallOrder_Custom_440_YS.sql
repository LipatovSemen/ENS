USE sdm72dev
go
REVOKE EXECUTE ON dbo.RecallOrder_Custom_440_YS FROM public
go
IF OBJECT_ID('dbo.RecallOrder_Custom_440_YS') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.RecallOrder_Custom_440_YS
    IF OBJECT_ID('dbo.RecallOrder_Custom_440_YS') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.RecallOrder_Custom_440_YS >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.RecallOrder_Custom_440_YS >>>'
END
go
SET ANSI_NULLS ON
go
CREATE PROC [dbo].[RecallOrder_Custom_440_YS]
            @SwiftID          DSIDENTIFIER        
           ,@DocID            DSIDENTIFIER        
           ,@QtyOtz           DSMONEY             
           ,@NewDocID         DSIDENTIFIER output 
as


declare @SQLStr NVARCHAR(4000)       

--Процедура отзыва блокировки. Ставится дата окончания и меняется статус в РБС
begin 
select @SQLStr = N'EXECUTE (' + char(39) + 'BEGIN GC.SDM$440P_ENS_RECALL(?,?); END;' + char(39) + '
                                                ,'+ char(39) +convert(varchar,@DocID)+ char(39) + '
                                                ,'+ char(39) + convert(varchar(30),@QtyOtz) + char(39) + '
                                                ) at ' + dbo.sdm_GetRBSDB() + ''

                                
        exec sp_executesql @stmp = @SQLStr    
end

select @NewDocID = @DocID
go
SET ANSI_NULLS OFF
go
IF OBJECT_ID('dbo.RecallOrder_Custom_440_YS') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.RecallOrder_Custom_440_YS >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.RecallOrder_Custom_440_YS >>>'
go
GRANT EXECUTE ON dbo.RecallOrder_Custom_440_YS TO public
go
