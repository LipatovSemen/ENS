-- Start of DDL Script for Procedure GC.SDM$440P_ENS_CORR
-- Generated 21.09.2023 11:30:54 from GC@BANKNULL

CREATE OR REPLACE 
PROCEDURE sdm$440p_ens_corr
   ( vObjid in varchar2 --ID блокировки
     ,vSumLimit in number --Сумма поручения  
     ,vPaymentCondition in varchar2 --Резервное поле      
   )
   as

    pfbid            number;
    vDogID           varchar2(20);
    vComment         varchar(200);
    vCur             varchar2(3);
    vResolution      varchar2(80);
    vDate_R          date;
    vPosition        number;
    vIdDate          date;
    vUid             varchar2(25);
    vSaldo_ENS       number;
    vReserve_Number  varchar2(25);
    vDate_B          date;
    vDate_E          date;
    vPrcadd          number;
    vReason          varchar2(30);
    vSumm            number;
    vSummReserve     number;
    vId_Org          varchar2(2000);
    vid_ip_num       varchar2(100);
    vPurpose         varchar2(8);
    vLivingWage      varchar2(1);
    vLivingWageOktmoId varchar2(2000);
    vLivingWageWho   varchar2(30);
    vLivingWageSumm  number;
    vLivingWageSummDateEnd date;
    vGroupId         varchar2(25);
    vSumResolution   varchar2(1);
    vError           varchar2(2000);
    vREKV            varchar2(15);
    vREKV_NAL        varchar2(15); 
    vPriority_Old    number;
                    
BEGIN
GC.P_SUPPORT.ARM_START();



SELECT F.DOG_ID
      ,F.DATE_B
      ,F.DATE_E
      ,F.PRC_ADD
      ,F.RESOLUTION
      ,F.DATE_R
      ,F.REASON
      ,F.COMMENTS
      ,F.POSITION
      ,F.ID_ORG
      ,F.ID_IP_NUM
      ,F.ID_DATE
      ,F.PURPOSE
      ,F.LIVING_WAGE
      ,F.LIVING_WAGE_OKTMO_ID
      ,F.LIVING_WAGE_WHO
      ,F.LIVING_WAGE_SUMM
      ,F.LIVING_WAGE_SUMM_DATE_END
      ,F.GROUP_ID
      ,F.USE_SUM_RESOLUTION
      ,F.UUID
      ,D.CUR
      ,F.REKV
      ,F.REKV_NAL

INTO vDogID,vDate_B,vDate_E,vPrcadd,vResolution,vDate_R,vReason,vComment,vPosition,vId_Org,vid_ip_num,vIdDate,vPurpose,vLivingWage,vLivingWageOktmoId,vLivingWageWho,vLivingWageSumm,vLivingWageSummDateEnd,vGroupId,vSumResolution,vUid, vCur, vREKV, vREKV_NAL
 FROM GC.FUNDS_BLOCK F
     ,GC.DOG D
WHERE 1=1
  AND F.OBJID = vObjid
  AND D.OBJID = F.DOG_ID;

--Протоколируем действия
INSERT INTO GC.SDM$440P_ENS_PROTOCOL
SELECT sysdate,vDogID,vUid,'Корректировка','WAIT','' from dual;
COMMIT;

--Протоколируем действия
INSERT INTO GC.SDM$440P_ENS_PROTOCOL
SELECT sysdate,vDogID,vUid,'Параметры','vObjid',vObjid from dual;
COMMIT;

--Протоколируем действия
INSERT INTO GC.SDM$440P_ENS_PROTOCOL
SELECT sysdate,vDogID,vUid,'Параметры','vSumLimit',vSumLimit from dual;
COMMIT;

--Протоколируем действия
INSERT INTO GC.SDM$440P_ENS_PROTOCOL
SELECT sysdate,vDogID,vUid,'Параметры','vPaymentCondition',vPaymentCondition from dual;
COMMIT;

--Сумма резерва по блокировке
SELECT GC.DOG_RESERVE.GETFUNDSBLOCKSUMM(vObjid)
INTO vSummReserve
FROM DUAL;
dbms_output.put_line(vSummReserve);

--Проставим текущей блокировке дату окончания
UPDATE GC.FUNDS_BLOCK 
SET DATE_E = SYSDATE 
WHERE OBJID = vObjid;

--Отзовем резерв и изменим статус на "Разблокировано по истечении срока блокировки"
GC.DOG_RESERVE.DELFUNDSBLOCK(vObjid,'Корректировка инкассового по данным из ФНС',sysdate,'T');



--Полная сумма заблокированных средств
/*
SELECT GC.DOG_RESERVE.GETSUMFULL(vObjid,vSummReserve)
INTO vSumm
FROM DUAL;
dbms_output.put_line(vSumm);
*/

--Если сумма корректировки не ноль, то заведем новую
IF vSumLimit > 0 THEN
--Добавим новую блокировку с новой суммой
begin
  pfbid:=gc.dog_reserve.addfundsblock(pdogid => vDogID,
                                       pdateb => null,
                                       pdatee => null,
                                       psumm => vSummReserve,
                                       pprcadd => '100', --Процент поступающих средств
                                       pcur =>  vCur,
                                       pinitiator => 'FNS',
                                       presolution => vResolution,
                                       presdate => vDate_R,
                                       preason => 'PENALTY',
                                       pcomments => vComment,
                                       panswers => null,
                                       psumlimit => vSumLimit,
                                       pPosition => vPosition,
                                       pBlockType => 'E',
                                       pIdOrg => vId_Org,
                                       pIdIpNum => vid_ip_num,
                                       pIdDate => vIdDate,
                                       pPurpose => vPurpose,
                                       pLivingWage  => 'N',
                                       pLivingWageOktmoId  => vLivingWageOktmoId,
                                       pLivingWageWho => vLivingWageWho,
                                       pLivingWageSumm  => vLivingWageSumm,
                                       pLivingWageSummDateEnd  => vLivingWageSummDateEnd,
                                       pGroupId => vGroupId,
                                       pSumResolution => null,
                                       pAllDog => 'N',
                                       pAllSum => 'N',
                                       pAllDogCur => null,
                                       pUUID => vUid,
                                       pReserveNumber => vPaymentCondition,
                                       pSaldoEns => null                                       
                                       );                                       
EXCEPTION WHEN OTHERS THEN 
vERROR:=SQLERRM;   
UPDATE GC.SDM$440P_ENS_PROTOCOL
SET TEXT = vERROR
   ,STATUS = 'ERROR'
WHERE UUID = vUid
  AND DogID = vDogID
  AND Type_Oper = 'Корректировка'
  AND EVENT_DATE = (SELECT MAX(E.EVENT_DATE) 
                        FROM SDM$440P_ENS_PROTOCOL E
                       WHERE 1=1
                         AND E.UUID = vUid);                                   
  commit;
end;

--Реквизиты перенесем из старой блокировки
IF vERROR is null then
begin
  gc.dog_reserve.setrekvnal(pfbid => pfbid,
                            prekv => vREKV_NAL);
  commit;
end;


begin
  gc.dog_reserve.setrekv(pfbid => pfbid,
                         prekv => vREKV);
  commit;
end;  


--Ставим такой жи приоритет, как у прошлой блокировки, чтобы не влезли между блокировками такой же очередностью блокировки с другим УИД
BEGIN
FOR I IN (
SELECT PRIORITY 
FROM GC.FUNDS_BLOCK
WHERE 1=1
  AND OBJID = VOBJID
)
LOOP 
UPDATE GC.FUNDS_BLOCK
SET PRIORITY = i.PRIORITY
WHERE OBJID = pFBID;
END LOOP;
END;

END IF;


IF vERROR is null then
UPDATE GC.SDM$440P_ENS_PROTOCOL
SET TEXT = 'Блокировка ID '||vObjid||' отменена. Добавлена новая с корректировкой ID '||pfbid
   ,STATUS = 'SUCCESS'
WHERE UUID = vUid
  AND DogID = vDogID
  AND Type_Oper = 'Корректировка'
  AND EVENT_DATE = (SELECT MAX(E.EVENT_DATE) 
                        FROM SDM$440P_ENS_PROTOCOL E
                       WHERE 1=1
                         AND E.UUID = vUid);                                   
  commit;
END IF;



END IF;


IF vSumLimit = 0 then
UPDATE GC.SDM$440P_ENS_PROTOCOL
SET TEXT = 'Блокировка ID '||vObjid||' отменена. Новая не заводилась, т.к. корректировка на нулевую сумму.'
   ,STATUS = 'SUCCESS'
WHERE UUID = vUid
  AND DogID = vDogID
  AND Type_Oper = 'Корректировка'
  AND EVENT_DATE = (SELECT MAX(E.EVENT_DATE) 
                        FROM SDM$440P_ENS_PROTOCOL E
                       WHERE 1=1
                         AND E.UUID = vUid);                                   
  commit;
END IF;
/*begin
  gc.dog_reserve.updfundsblock(pfbid => vObjid,
                               pdateb => vDate_B,
                               pdatee => vDate_E,
                               psumm => to_number(vSumm),
                               pprcadd => vPrcadd,
                               pinitiator => 'FNS',
                               presolution => vResolution,
                               presdate => vDate_R,
                               preason => vReason,
                               pcomments => vComment,
                               panswers => null,
                               psumlimit => vSumLimit,
                               pPosition => vPosition,
                               pBlockType => 'E',
                               pIdOrg => vId_Org,
                               pIdIpNum => vid_ip_num,
                               pIdDate => vIdDate,
                               pPurpose => vPurpose,
                               pLivingWage  => vLivingWage,
                               pLivingWageOktmoId  => vLivingWageOktmoId,
                               pLivingWageWho => vLivingWageWho,
                               pLivingWageSumm  => vLivingWageSumm,
                               pLivingWageSummDateEnd  => vLivingWageSummDateEnd,
                               pGroupId => vGroupId,
                               pSumResolution => null,
                               pUUID => vUid,
                               pReserveNumber => vReserve_Number,
                               pSaldoEns => vSaldo_ENS
                               );                          
EXCEPTION WHEN OTHERS THEN 
vERROR:=SQLERRM;   
dbms_output.put_line(vERROR);
UPDATE GC.SDM$440P_ENS_PROTOCOL
SET TEXT = vERROR
   ,STATUS = 'ERROR'
WHERE UUID = vUid
  AND DogID = vDogID
  AND Type_Oper = 'Изменение суммы';                                   
  commit;
end;
*/

COMMIT;
END;
/



-- End of DDL Script for Procedure GC.SDM$440P_ENS_CORR
