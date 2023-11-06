USE sdm72dev
go
REVOKE EXECUTE ON dbo.GetDocStatusCustom_440_YS FROM public
go
IF OBJECT_ID('dbo.GetDocStatusCustom_440_YS') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.GetDocStatusCustom_440_YS
    IF OBJECT_ID('dbo.GetDocStatusCustom_440_YS') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.GetDocStatusCustom_440_YS >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.GetDocStatusCustom_440_YS >>>'
END
go
SET ANSI_NULLS ON
go
CREATE PROC [dbo].[GetDocStatusCustom_440_YS]
            @SPID DSSPID
as
--Процедура уточняет статус инкассового в РБС
--Автор Липатов С.
--Сам вызов разрабатывался YS

declare @FundBlockID      DSIDENTIFIER
       ,@FundBlockState   VARCHAR(1)  
       ,@FundBlockReserve NUMERIC(18,2)
       ,@FundBlockTransf  NUMERIC(18,2)
       ,@FundBlockSum     NUMERIC(18,2)
       ,@SQLStr           NVARCHAR(4000)
       ,@Params           NVARCHAR(400)


declare cur cursor for select distinct DocID from pDocStatusCustom_440_YS where SPID = @SPID
    
    open cur
    fetch next from cur into @FundBlockID
    
    WHILE @@FETCH_STATUS = 0
    BEGIN  


    


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
                                                                      and f.objid = ' + char(39) +convert(varchar,@FundBlockID)+ char(39) +' 
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
                                                                      and f.objid = ' + char(39) +convert(varchar,@FundBlockID)+ char(39) +' 
                                                                      '+char(34)+')'
                                                                 
        select @Params = N'@FundBlockSum     NUMERIC(18,2) output'
    
        exec sp_executesql @stmp     = @SQLStr                  
                          ,@Params   = @Params
                          ,@FundBlockSum = @FundBlockSum output
--IF @FundBlockReserve = 0
--begin
update pDocStatusCustom_440_YS
set DocRest = @FundBlockSum
   ,DocQty = @FundBlockSum
   ,Confirmed = 1
   ,CodePartPlat = 1
where spid = @SPID
  and DocID = @FundBlockID   
--end

--Нужно понять учитываем ли мы резерв?
/*IF @FundBlockReserve > 0
begin
update pDocStatusCustom_440_YS
set DocRest = @FundBlockSum-@FundBlockReserve
   ,DocQty = @FundBlockSum
   ,Confirmed = 0
   ,CodePartPlat = 1
where spid = @@SPID
  and DocID = @FundBlockID
End */

End --@FundBlockState = 'N' 

--Если взыскано в полном объеме
IF @FundBlockState = 'S'
begin
        select @SQLStr = N' select  @FundBlockSum = sum_limit
                                from openquery(' + dbo.sdm_GetRBSDB() + ',' + char(34) + 'select f.sum_limit 
                                                                       from gc.funds_block f                                                                    
                                                                    where 1=1 
                                                                      and f.objid = ' + char(39) +convert(varchar,@FundBlockID)+ char(39) +' 
                                                                      '+char(34)+')'
                                                                 
        select @Params = N'@FundBlockSum     NUMERIC(18,2) output'
    
        exec sp_executesql @stmp     = @SQLStr                  
                          ,@Params   = @Params
                          ,@FundBlockSum = @FundBlockSum output
                          
update pDocStatusCustom_440_YS
set DocRest = 0
   ,DocQty = @FundBlockSum
   ,Confirmed = 1
where spid = @SPID
  and DocID = @FundBlockID

                          
end --@FundBlockState = 'S'


--Если частично взыскано
IF @FundBlockState = 'P'
begin
        select @SQLStr = N' select  @FundBlockSum = sum_limit
                                   ,@FundBlockReserve = reserve_block
                                   ,@FundBlockTransf = block_transfer
                                from openquery(' + dbo.sdm_GetRBSDB() + ',' + char(34) + 'select f.sum_limit 
                                                                              ,gc.dog_reserve.getfundsblocksumm(' + char(39) +convert(varchar,@FundBlockID)+ char(39) +') reserve_block
                                                                              ,gc.dog_reserve.GETTRANSFERREDSUM(' + char(39) +convert(varchar,@FundBlockID)+ char(39) +','+ char(39) + 'Y' + char(39) + ') block_transfer
                                                                       from gc.funds_block f                                                                    
                                                                    where 1=1 
                                                                      and f.objid = ' + char(39) +convert(varchar,@FundBlockID)+ char(39) +' 
                                                                      '+char(34)+')'
                                                                 
        select @Params = N'@FundBlockSum     NUMERIC(18,2) output
                          ,@FundBlockReserve NUMERIC(18,2) output
                          ,@FundBlockTransf  NUMERIC(18,2) output'
    
        exec sp_executesql @stmp     = @SQLStr                  
                          ,@Params   = @Params
                          ,@FundBlockSum = @FundBlockSum output
                          ,@FundBlockReserve = @FundBlockReserve output
                          ,@FundBlockTransf = @FundBlockTransf output
                          
update pDocStatusCustom_440_YS
set DocRest = @FundBlockSum-@FundBlockTransf---@FundBlockReserve 
   ,DocQty = @FundBlockSum
   ,Confirmed = 1
   ,CodePartPlat = 1
where spid = @SPID
  and DocID = @FundBlockID
end --@FundBlockState = 'P'



IF @FundBlockState = 'D'
--Если отменен, то по умолчанию ставим Сумму остатка = Сумма инкассового и причину отмены "Нет денег" CodePartPlat = 2
begin 
        select @SQLStr = N' select  @FundBlockSum = sum_limit
                                from openquery(' + dbo.sdm_GetRBSDB() + ',' + char(34) + 'select f.sum_limit 
                                                                       from gc.funds_block f                                                                    
                                                                    where 1=1 
                                                                      and f.objid = ' + char(39) +convert(varchar,@FundBlockID)+ char(39) +' 
                                                                      '+char(34)+')'
                                                                 
        select @Params = N'@FundBlockSum     NUMERIC(18,2) output'
    
        exec sp_executesql @stmp     = @SQLStr                  
                          ,@Params   = @Params
                          ,@FundBlockSum = @FundBlockSum output
update pDocStatusCustom_440_YS
set DocRest = @FundBlockSum
   ,DocQty = @FundBlockSum
   ,Confirmed = 101
   ,CodePartPlat = 2
where spid = @SPID
  and DocID = @FundBlockID                          
                          
end

fetch next from cur into @FundBlockID 
end
    close cur
    deallocate cur


 --@FundBlockState = 'D'
go
SET ANSI_NULLS OFF
go
IF OBJECT_ID('dbo.GetDocStatusCustom_440_YS') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.GetDocStatusCustom_440_YS >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.GetDocStatusCustom_440_YS >>>'
go
GRANT EXECUTE ON dbo.GetDocStatusCustom_440_YS TO public
go
