USE sdm72dev
go
REVOKE EXECUTE ON dbo.GetDocOrderParam_Custom_440_YS FROM public
go
IF OBJECT_ID('dbo.GetDocOrderParam_Custom_440_YS') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.GetDocOrderParam_Custom_440_YS
    IF OBJECT_ID('dbo.GetDocOrderParam_Custom_440_YS') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.GetDocOrderParam_Custom_440_YS >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.GetDocOrderParam_Custom_440_YS >>>'
END
go
SET ANSI_NULLS ON
go
CREATE PROC [dbo].[GetDocOrderParam_Custom_440_YS]
            @SwiftID          DSIDENTIFIER        
           ,@DocID            DSIDENTIFIER        
           ,@DocRest          DSMONEY             output
as
--Процедура работет в связке с RecallOrder_Custom_440_YS
--Запрашивает сумму остатка инкассового по ID блокировки в РБС
--Если сумма больше нуля, то запускается процедура RecallOrder_Custom_440_YS, которая в свою очередь отменяет блокировку в РБС
--Липатов Семен

declare @FundBlockState   VARCHAR(1)  
       ,@FundBlockReserve NUMERIC(18,2)
       ,@FundBlockTransf  NUMERIC(18,2)
       ,@FundBlockSum     NUMERIC(18,2)
       ,@SQLStr           NVARCHAR(4000)
       ,@Params           NVARCHAR(400)

--Найдем статус блокировки
--@FundBlockState = 'S' взыскано в полном объеме
--@FundBlockState = 'D' удалена
--@FundBlockState = 'N' ничего не взыскано, но может быть зарезервировано. Документов по перечислению не было
--@FundBlockState = 'P' частично взыскано. Были документы по перечислению
begin 
        select @SQLStr = N' select @FundBlockState = State
                                from openquery(' + dbo.sdm_GetRBSDB() + ',' + char(34) + 'select f.state
                                                                       from gc.funds_block f                                                                    
                                                                    where 1=1 
                                                                      and f.objid = ' + char(39) +convert(varchar,@DocID)+ char(39) +' 
                                                                      '+char(34)+')'
End                                                                  
        select @Params = N'@FundBlockState varchar(1) output'
    
        exec sp_executesql @stmp     = @SQLStr                  
                          ,@Params   = @Params
                          ,@FundBlockState = @FundBlockState output 
                          
--Если ничего не взыскано, то проверим сумму инкассового
IF @FundBlockState = 'N' 
begin 
        select @SQLStr = N' select @FundBlockSum = sum_limit
                                from openquery(' + dbo.sdm_GetRBSDB() + ',' + char(34) + 'select 
                                                                 f.sum_limit 
                                                                       from gc.funds_block f                                                                    
                                                                    where 1=1 
                                                                      and f.objid = ' + char(39) +convert(varchar,@DocID)+ char(39) +' 
                                                                      '+char(34)+')'
                                                                 
        select @Params = N'@FundBlockSum     NUMERIC(18,2) output'
    
        exec sp_executesql @stmp     = @SQLStr                  
                          ,@Params   = @Params
                          ,@FundBlockSum = @FundBlockSum output

select @DocRest = @FundBlockSum

End --@FundBlockState = 'N' 

--Если взыскано в полном объеме
IF @FundBlockState = 'S'
begin
select @DocRest = 0                         
end 
                          
--Если частично взыскано
IF @FundBlockState = 'P'
begin
        select @SQLStr = N' select  @FundBlockSum = sum_limit
                                   ,@FundBlockReserve = reserve_block
                                   ,@FundBlockTransf = block_transfer
                                from openquery(' + dbo.sdm_GetRBSDB() + ',' + char(34) + 'select f.sum_limit 
                                                                              ,gc.dog_reserve.getfundsblocksumm(' + char(39) +convert(varchar,@DocID)+ char(39) +') reserve_block
                                                                              ,gc.dog_reserve.GETTRANSFERREDSUM(' + char(39) +convert(varchar,@DocID)+ char(39) +','+ char(39) + 'Y' + char(39) + ') block_transfer
                                                                       from gc.funds_block f                                                                    
                                                                    where 1=1 
                                                                      and f.objid = ' + char(39) +convert(varchar,@DocID)+ char(39) +' 
                                                                      '+char(34)+')'
                                                                 
        select @Params = N'@FundBlockSum     NUMERIC(18,2) output
                          ,@FundBlockReserve NUMERIC(18,2) output
                          ,@FundBlockTransf  NUMERIC(18,2) output'
    
        exec sp_executesql @stmp     = @SQLStr                  
                          ,@Params   = @Params
                          ,@FundBlockSum = @FundBlockSum output
                          ,@FundBlockReserve = @FundBlockReserve output
                          ,@FundBlockTransf = @FundBlockTransf output
                          
select @DocRest = @FundBlockSum-@FundBlockTransf
end 

--При других статусах ставим по умолчанию 0 (это либо отменена либо удалена)
IF @FundBlockState not in ('N','S','P')
begin
select @DocRest = 0
end
go
SET ANSI_NULLS OFF
go
IF OBJECT_ID('dbo.GetDocOrderParam_Custom_440_YS') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.GetDocOrderParam_Custom_440_YS >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.GetDocOrderParam_Custom_440_YS >>>'
go
GRANT EXECUTE ON dbo.GetDocOrderParam_Custom_440_YS TO public
go
