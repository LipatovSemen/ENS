USE sdm72dev
go
REVOKE EXECUTE ON dbo.GenDocTransferCustom_440_YS FROM public
go
IF OBJECT_ID('dbo.GenDocTransferCustom_440_YS') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.GenDocTransferCustom_440_YS
    IF OBJECT_ID('dbo.GenDocTransferCustom_440_YS') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.GenDocTransferCustom_440_YS >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.GenDocTransferCustom_440_YS >>>'
END
go
SET ANSI_NULLS ON
go
CREATE PROC [dbo].[GenDocTransferCustom_440_YS]
            @SwiftID          DSIDENTIFIER        
           ,@AccountFromID    DSIDENTIFIER        
           ,@QtyToPay         DSMONEY             
           ,@ParentDocID      DSIDENTIFIER        
as

--Процедура добавляет инкассовое в РБС или корректирует сумму текущего инкассового
--Вызывается из модуля 440 П при переходе по стадиям
--Автор Липатов С.
--Сам вызов разрабатывался YS

declare @DateOper         DSOPERDAY --Операционная дата
       ,@OpCode           DSIDENTIFIER --Вид операции в бухгалтерском документе
       ,@StatusSostavText DSCOMMENT -- Статус составителя налогового платежа
       ,@KBK              DSCOMMENT -- КБК
       ,@OKATO            DSCOMMENT -- ОКАТО/ОКТМО  
       ,@DocNumber        DSCOMMENT -- Номер документа ФНС
       ,@DocDate          DSOPERDAY -- Дата документа ФНС   
       ,@CommingDate      DSOPERDAY -- Дата поступления в банк
       ,@Purpose          DSCOMMENT -- Назначение платежа
       ,@TaxBase          DSCOMMENT -- Налоговая база
       ,@TaxNumberDoc     DSCOMMENT -- Номер налогового документа
       ,@TaxPeriod        DSCOMMENT -- Налоговый период
       ,@TaxDate          DSCOMMENT -- Налоговая дата
       ,@TaxType          DSCOMMENT -- Тип налогового платежа
       ,@UniqueCode       DSCOMMENT -- УИД начисления. УИД используется для поиска ранее созданных платежей
       ,@PayerBankBIC     DSCOMMENT -- Плательщик. БИК банка
       ,@PayerName        DSCOMMENT -- Плательщик. Наименование
       ,@PayerINN         DSCOMMENT -- Плательщик. ИНН
       ,@PayerKPP         DSCOMMENT -- Плательщик. КПП
       ,@PayeeBankBIC     DSCOMMENT -- Получатель. БИК банка
       ,@PayeeBankAccount DSCOMMENT -- Получатель. Корсчёт
       ,@PayeeName        DSCOMMENT -- Получатель. Наименование
       ,@PayeeINN         DSCOMMENT -- Получатель. ИНН
       ,@PayeeKPP         DSCOMMENT -- Получатель. КПП
       ,@PayeeAccount     DSCOMMENT -- Получатель. Счёт в балансе банка получателя
       ,@PaymentCondition DSCOMMENT -- Резервное поле
       ,@PriorityForPay   DSIDENTIFIER -- Приоритет формируемого документа
       ,@BatchID          DSIDENTIFIER -- ИД пачки в Диасофт
       ,@PayerAccount     VARCHAR(20) --Счет плательщика
       ,@DogID            VARCHAR(15) --ID договора в РБС
       ,@SQLStr           NVARCHAR(4000)
       ,@Params           NVARCHAR(400)
       ,@Cur              VARCHAR(3)
       ,@FundBlockID      VARCHAR(15)
       ,@FundsBlockCnt    INT
       
       
       
select @DateOper = DateOper
      ,@OpCode = OpCode
      ,@StatusSostavText = StatusSostavText
      ,@KBK = KBK            
      ,@OKATO = OKATO          
      ,@DocNumber = DocNumber      
      ,@DocDate = DocDate        
      ,@CommingDate = CommingDate    
      ,@Purpose = Purpose        
      ,@TaxBase = TaxBase        
      ,@TaxNumberDoc = TaxNumberDoc   
      ,@TaxPeriod = TaxPeriod      
      ,@TaxDate = TaxDate        
      ,@TaxType = TaxType        
      ,@UniqueCode = UniqueCode      
      ,@PayerBankBIC = PayerBankBIC    
      ,@PayerName = PayerName       
      ,@PayerINN = PayerINN        
      ,@PayerKPP = PayerKPP        
      ,@PayeeBankBIC = PayeeBankBIC    
      ,@PayeeBankAccount = PayeeBankAccount
      ,@PayeeName = PayeeName       
      ,@PayeeINN = PayeeINN        
      ,@PayeeKPP = PayeeKPP        
      ,@PayeeAccount = PayeeAccount    
      ,@PriorityForPay = PriorityForPay  
      ,@BatchID = BatchID        
      ,@PaymentCondition = PaymentCondition      
      from pDocParam_440_YS
where 1=1
  and spid = @@SPID       


--Начитаем из тэгов номер счета плательщика, т.е. счет из РБС
select @PayerAccount = TextLine
         from tSwiftLine WITH (NOLOCK INDEX = XPKtSwiftLine)
where 1=1
  and SwiftID = @SwiftID
  and Tag = 'НомСчПл'
 

--Найдем ID договора из РБС  
begin 
        select @SQLStr = N' select @DogID = DogID
                                from openquery(' + dbo.sdm_GetRBSDB() + ',' + char(34) + 'select d.objid DogId
                                                                       from gc.nns_list n
                                                                           ,gc.dog d                                                                       
                                                                    where 1=1 
                                                                      and n.nns = ' + char(39) +@PayerAccount+ char(39) +' 
                                                                      and n.enddat = TO_DATE(' + CHAR(39) + '31/12/4712' + CHAR(39) + ',' + CHAR(39) + 'DD/MM/YYYY' + CHAR(39) + ')
                                                                      and d.s = n.s
                                                                      '+char(34)+')'
End                                                                  
        select @Params = N'@DogID varchar(15) output'
    
        exec sp_executesql @stmp     = @SQLStr                  
                          ,@Params   = @Params
                          ,@DogID    = @DogID output  
                          
                          
--Если передан параметр @ParentDocID, то значит корректируется уже существующая блокировка 
begin 
        select @SQLStr = N' select @FundsBlockCnt = Cnt
                                from openquery(' + dbo.sdm_GetRBSDB() + ',' + char(34) + 'select count(*) Cnt
                                                                       from gc.funds_block f                                                                                      
                                                                    where 1=1 
                                                                      and f.objid = ' + char(39) +convert(varchar,@ParentDocID)+ char(39) +' 
                                                                      
                                                                      '+char(34)+')'
End                                                                  
        select @Params = N'@FundsBlockCnt int output'
    
        exec sp_executesql @stmp     = @SQLStr                  
                          ,@Params   = @Params
                          ,@FundsBlockCnt    = @FundsBlockCnt output                            




--Если по родительскому документу нашли блокировку в РБС, то выполним корректировку. Старую блокировку завершаем и добавляем новую с новой суммой
IF @FundsBlockCnt = 1
begin 
select @SQLStr = N'EXECUTE (' + char(39) + 'BEGIN GC.SDM$440P_ENS_CORR(?,?,?); END;' + char(39) + '
                                                ,'+ char(39) +convert(varchar,@ParentDocID)+ char(39) + '
                                                ,' + char(39) + convert(varchar(30),@QtyToPay) + char(39) + '                                            
                                                ,'+ char(39) + @PaymentCondition + char(39) + '                                                
                                                ) at ' + dbo.sdm_GetRBSDB() + ''

                                
        exec sp_executesql @stmp = @SQLStr    
end



--Если договор найден и это не корректировка, то запустим процедуру в РБС, которая добавляет блокировку
IF @DogID is not null and (@ParentDocID = 0 or @ParentDocID is null)
begin
select @Cur = substring(@PayerAccount,6,3)
        select @SQLStr = N'EXECUTE (' + char(39) + 'BEGIN GC.SDM$440P_ENS(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?); END;' + char(39) + '
                                                ,'+ char(39) + @DogID + char(39) + '
                                                ,' + char(39) + convert(varchar(30),@QtyToPay) + char(39) + '
                                                ,'+ char(39) + @DocNumber + char(39) + '
                                                ,'+ char(39) + convert(varchar,@DocDate,104) + char(39) + '
                                                ,'+ char(39) + convert(varchar,@CommingDate,104) + char(39) + '   
                                                ,'+ char(39) + @UniqueCode + char(39) + '
                                                ,'+ char(39) + @Cur + char(39) + '
                                                ,'+ char(39) + '3' + char(39) + '
                                                ,'+ char(39) + @PayeeBankBIC + char(39) + '
                                                ,'+ char(39) + @PayeeBankAccount + char(39) + '
                                                ,'+ char(39) + @PayeeName + char(39) + '
                                                ,'+ char(39) + @PayeeINN + char(39) + '
                                                ,'+ char(39) + @PayeeKPP + char(39) + '
                                                ,'+ char(39) + @PayeeAccount + char(39) + '
                                                ,'+ char(39) + @StatusSostavText + char(39) + '
                                                ,'+ char(39) + @KBK + char(39) + '
                                                ,'+ char(39) + @TaxBase + char(39) + '
                                                ,'+ char(39) + @TaxPeriod + char(39) + '
                                                ,'+ char(39) + @TaxNumberDoc + char(39) + '
                                                ,'+ char(39) + @TaxDate + char(39) + '
                                                ,'+ char(39) + @PayerINN + char(39) + '
                                                ,'+ char(39) + @PayerKPP + char(39) + '
                                                ,'+ char(39) + @OKATO + char(39) + '
                                                ) at ' + dbo.sdm_GetRBSDB() + ''

                                
        exec sp_executesql @stmp = @SQLStr    
end
        
--Заберем ID блокировки  
begin 
        select @SQLStr = N' select @FundBlockID = ObjID
                                from openquery(' + dbo.sdm_GetRBSDB() + ',' + char(34) + 'select max(f.ObjID) ObjID 
                                                                       from gc.funds_block f                                                              
                                                                    where 1=1 
                                                                      and f.uuid = ' + char(39) +@UniqueCode+ char(39) +' 
                                                                      and f.state not in (' + char(39) +'T'+ char(39) +',' + char(39) +'D'+ char(39) +')
                                                                      '+char(34)+')'
End                                                                  
        select @Params = N'@FundBlockID varchar(15) output'
    
        exec sp_executesql @stmp     = @SQLStr                  
                          ,@Params   = @Params
                          ,@FundBlockID    = @FundBlockID output

IF @FundBlockID is not null
begin
insert pGenPayDoc_440_YS (SPID, IsExternal, DocID, AccountID, IsMain) 
select @@SPID, 1, @FundBlockID, @AccountFromID, 1
end
go
SET ANSI_NULLS OFF
go
IF OBJECT_ID('dbo.GenDocTransferCustom_440_YS') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.GenDocTransferCustom_440_YS >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.GenDocTransferCustom_440_YS >>>'
go
GRANT EXECUTE ON dbo.GenDocTransferCustom_440_YS TO public
go
