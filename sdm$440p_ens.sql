-- Start of DDL Script for Procedure GC.SDM$440P_ENS
-- Generated 21.09.2023 11:30:44 from GC@BANKNULL

CREATE OR REPLACE 
PROCEDURE sdm$440p_ens
   ( vDogID in varchar2 --Номер договора, на который ставим блокировку
     ,vSumLimit in number --Сумма поручения
     ,vResolution in varchar2 --Номер постановления
     ,vDate_R in varchar2 --Дата постановления         
     ,vIdDate in varchar2 --Дата выдачи
     ,vUid in varchar2 --Уникальный идентификатор
     ,vCur in varchar2 --Валюта блокировки 
     ,vPosition in varchar2 --Очередность платежа
     ,vPayeeBankBIC in varchar2 --Получатель. БИК банка
     ,vPayeeBankAccount in varchar2 -- Получатель. Корсчёт     
     ,vPayeeName in varchar2 -- Получатель. Наименование
     ,vPayeeINN in varchar2 -- Получатель. ИНН
     ,vPayeeKPP in varchar2 -- Получатель. КПП
     ,vPayeeAccount in varchar2 --Получатель. Счёт в балансе банка получателя
     ,vStatusSostavText in varchar2 -- Статус составителя налогового платежа
     ,vKBK in varchar2 --КБК  
     ,vTaxBase in varchar --Показатель основания платежа        
     ,vTaxPeriod in varchar --Налоговый период
     ,vDocNumber in varchar --Номер налогового документа ФНС
     ,vDocDate in varchar2 --Дата документа ФНС
     ,vPayerINN in varchar2 --Плательщик ИНН
     ,vPayerKPP in varchar2 --Плательщик КПП
     ,vOkato in varchar --ОКАТО

          
   )
   as

    pfbid            number;
    vComment         varchar(100);
    
    p_mfo            varchar2(100);
    p_ks             varchar2(20);
    p_mfo_rkc        varchar2(9);
    p_namep          varchar2(100);
    p_nnp            varchar2(100);
    p_regional       varchar2(20);
    p_message        varchar2(100);
    p_bank_id        varchar2(15);
    p_rkc_bank_name  varchar2(150);
    p_rkc_bank_gorod varchar2(150);
    vRes             number;
    pfrombik         number;
    vUnoRekv         varchar2(15); 
    vRez             number;   
    
    vErrMsg          varchar2(255);
    chkNullUin       number;  
    pRekvDocUno      varchar2(15);
    vASK             varchar2(1);  
    vUnoRekv_nal     varchar2(15);
    T_KBK_ID         VARCHAR2(15);
    T_RES            VARCHAR2(20);
    T_TYPE_KBK       VARCHAR2(1)  := CHR(96);  
    
    vERROR           VARCHAR2(2000);  
                    
BEGIN
GC.P_SUPPORT.ARM_START();

--Протоколируем действия
INSERT INTO GC.SDM$440P_ENS_PROTOCOL
SELECT sysdate,vDogID,vUid,'Добавление блокировки','WAIT','' from dual;
COMMIT;

vComment:='По решению о взыскании от '||vDate_R||' № '||vResolution||' по ст.46 НК РФ';

begin
  pfbid:=gc.dog_reserve.addfundsblock(pdogid => vDogID,
                                       pdateb => null,
                                       pdatee => null,
                                       psumm => 0,
                                       pprcadd => '100', --Процент поступающих средств
                                       pcur =>  vCur,
                                       pinitiator => 'FNS',
                                       presolution => vResolution,
                                       presdate => to_date(vDate_R,'DD/MM/YYYY'),
                                       preason => 'PENALTY',
                                       pcomments => vComment,
                                       panswers => null,
                                       psumlimit => vSumLimit,
                                       pPosition => vPosition,
                                       pBlockType => 'E',
                                       pIdOrg => null,
                                       pIdIpNum => null,
                                       pIdDate => to_date(vIdDate,'DD/MM/YYYY'),
                                       pPurpose => null,
                                       pLivingWage  => 'N',
                                       pLivingWageOktmoId  => null,
                                       pLivingWageWho => 'WORKING',
                                       pLivingWageSumm  => 0,
                                       pLivingWageSummDateEnd  => null,
                                       pGroupId => null,
                                       pSumResolution => null,
                                       pAllDog => 'N',
                                       pAllSum => 'N',
                                       pAllDogCur => null,
                                       pUUID => vUid,
                                       pReserveNumber => 0,
                                       pSaldoEns => null
                                       );                                       
EXCEPTION WHEN OTHERS THEN 
vERROR:=SQLERRM;   
UPDATE GC.SDM$440P_ENS_PROTOCOL
SET TEXT = vERROR
   ,STATUS = 'ERROR'
WHERE UUID = vUid
  AND DogID = vDogID
  AND Type_Oper = 'Добавление блокировки';                                   
  commit;
end;

IF vERROR is null then
UPDATE GC.SDM$440P_ENS_PROTOCOL
SET TEXT = vERROR
   ,STATUS = 'SUCCESS'
WHERE UUID = vUid
  AND DogID = vDogID
  AND Type_Oper = 'Добавление блокировки';                                   
  commit;
END IF;  


--Внешние реквизиты
begin   
vERROR := null;

--Протоколируем действия
INSERT INTO GC.SDM$440P_ENS_PROTOCOL
SELECT sysdate,vDogID,vUid,'Внешние реквизиты','WAIT','' from dual;
COMMIT;

--Найдем данные по БИКу        
BEGIN
     vres :=   gc.bik$p_arm.fcheckrekvbycb (vPayeeBankBIC
        ,p_mfo
        ,p_ks
        ,p_mfo_rkc
        ,p_namep
        ,p_nnp
        ,p_regional
        ,p_message
        ,p_bank_id
        ,p_rkc_bank_name
        ,p_rkc_bank_gorod
        ,pfrombik => pfrombik = -1);
END;

        SELECT -GC.SEQ_DOC.NEXTVAL 
             INTO vUnoRekv 
             FROM dual;
          
      GC.SET_REKV2(V_S=>''
                  ,V_CUR=>''
                  ,V_MFO=>vPayeeBankBIC
                  ,V_KS=>vPayeeBankAccount
                  ,V_RS=>vPayeeAccount
                  ,V_NAME=>vPayeeName
                  ,V_BANK=>p_namep
                  ,V_GOROD=>p_nnp
                  ,V_UNO=>vUnoRekv
                  ,V_BANK_ID=>null--p_bank_id
                  ,V_UNB=>null
                  ,V_TEXT=>null
                  ,V_IDN=>vPayeeINN
                  ,V_IS_BS=>null
                  ,V_OCHEREDN=>vPosition
                  ,V_PLATDAT=>null
                  ,V_COPYDIR=>'0'
                  ,V_ORG_ID=>''
                  ,P_ISRKC=>''                 
                  ,flVNBAL=>''
                  ,V_REZ=>vREZ              
                  ,V_DIR=>'0'
                  ,V_KPP=>vPayeeKPP           
                  );             
EXCEPTION WHEN OTHERS THEN 
vERROR:=SQLERRM;   
UPDATE GC.SDM$440P_ENS_PROTOCOL
SET TEXT = vERROR
   ,STATUS = 'ERROR'
WHERE UUID = vUid
  AND DogID = vDogID
  AND Type_Oper = 'Внешние реквизиты';                                   
  commit;
end;       


IF vERROR is null then
UPDATE GC.SDM$440P_ENS_PROTOCOL
SET TEXT = vERROR
   ,STATUS = 'SUCCESS'
WHERE UUID = vUid
  AND DogID = vDogID
  AND Type_Oper = 'Внешние реквизиты';                                   
  commit;
END IF;


begin
  gc.dog_reserve.setrekv(pfbid => pfbid,
                         prekv => vUnoRekv);
  commit;
end;

--Конец внешних реквизитов



--Реквизиты для налогового платежа
begin

vERROR := null;

--Протоколируем действия
INSERT INTO GC.SDM$440P_ENS_PROTOCOL
SELECT sysdate,vDogID,vUid,'Налоговые реквизиты','WAIT','' from dual;
COMMIT;

        SELECT GC.SEQ_DOC.NEXTVAL 
             INTO pRekvDocUno 
             FROM dual;                      
             
--Найдем КБК из справочника. Если не нашли, то добавим             
T_KBK_ID := GC.SPRAV_NAME2ID(vKBK,T_TYPE_KBK);
IF T_KBK_ID IS NULL THEN
                T_RES := GC.INS_SPRAV_ADVANCED ( T_KBK_ID
                        ,V_SPRAV_ID_OR_NAME  => vKBK
                        ,V_TYPE              => T_TYPE_KBK
                        );
END IF;
                         
/*--ОКАТО       
        IF LENGTH(V_REGION_CODE) >= 2 THEN
          DECLARE
            VSPRAVVAL SPRAV$VALUES%ROWTYPE;
          BEGIN
            FOR SEARCHOKTMO IN (SELECT S.ID
                                FROM   SPRAV$TYPES S
                                WHERE  S.NAME = 'OKTMO') LOOP

               VSPRAVVAL := SPRAV_VALUE_FIND(SEARCHOKTMO.ID, V_REGION_CODE, F_RETURN_NULL => TRUE);
               IF VSPRAVVAL.ID IS NULL THEN
                 IF SPRAV_VALUE_ADD(SEARCHOKTMO.ID, V_REGION_CODE, '', '', '', 'N').ID IS NULL THEN
                   NULL;
                 END IF;
               END IF;
            END LOOP;
          END;
        END IF;
*/        
                       
      
gc.p_doc.checkDocNalForGisGmp(pErrMsg           => vErrMsg,
                                    pAsk              => vASK,
                                    ObjId             => pRekvDocUno,
                                    pStatus_Id        => vStatusSostavText,
                                    pKpp_Pol          => vPayeeKPP,
                                    pKbk_Id           => T_KBK_ID,
                                    pRegion_Code      => vOkato,
                                    pBase_Id          => 0,
                                    pPeriod_Str       => vTaxPeriod,
                                    pDoc_Num          => trim(vDocNumber),
                                    pSupplier_Bill_Id => vUid,
                                    pDocPeriodDate    => to_date(vDocDate,'DD/MM/YYYY'),
                                    pAccPayee         => null,
                                    pCorresBankAcc    => null,
                                    pApp              => TRUE,
                                    pAccPayeeFull     => 0,
                                    pRekvDocUno       => vUnoRekv, 
                                    pChkNullUin       => chkNullUin = 1);
end;

begin
gc.p_doc.INS_DOC_NAL(pRekvDocUno
                    ,vStatusSostavText
                    ,0
                    ,vPayeeKPP
                    ,T_KBK_ID
                    ,vOkato
                    ,vTaxBase
                    ,null
                    ,null
                    ,vTaxPeriod
                    ,trim(vDocNumber)
                    ,to_date(vDocDate,'DD/MM/YYYY')
                    ,null
                    ,V_DOG_ID=>null
                    ,V_REKV_TYPE => 'N'
                    ,V_SUPPLIER_BILL_ID => vUid
                    ,V_INN_PL => vPayerINN);
EXCEPTION WHEN OTHERS THEN 
vERROR:=SQLERRM;   
UPDATE GC.SDM$440P_ENS_PROTOCOL
SET TEXT = vERROR
   ,STATUS = 'ERROR'
WHERE UUID = vUid
  AND DogID = vDogID
  AND Type_Oper = 'Налоговые реквизиты';                                   
  commit;
end;       


IF vERROR is null then
UPDATE GC.SDM$440P_ENS_PROTOCOL
SET TEXT = vERROR
   ,STATUS = 'SUCCESS'
WHERE UUID = vUid
  AND DogID = vDogID
  AND Type_Oper = 'Налоговые реквизиты';                                   
  commit;
END IF;                   



begin
  gc.dog_reserve.setrekvnal(pfbid => pfbid,
                            prekv => pRekvDocUno);
  commit;
end;
commit;

END;
/



-- End of DDL Script for Procedure GC.SDM$440P_ENS
