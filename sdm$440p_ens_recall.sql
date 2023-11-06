-- Start of DDL Script for Procedure GC.SDM$440P_ENS_RECALL
-- Generated 21.09.2023 11:31:04 from GC@BANKNULL

CREATE OR REPLACE 
PROCEDURE sdm$440p_ens_recall
   ( vObjid in varchar2 --ID блокировки
     ,vSumQtyOtz in number --Сумма отзыва        
   )
   as

    pfbid            number;
    vDogID           varchar2(20);   
    vUid             varchar2(25);
    vSumm            number;
    vSummReserve     number;
    vError           varchar2(2000);
                    
BEGIN
GC.P_SUPPORT.ARM_START();

--ПРОЦЕДУРА ВЫЗЫВАЕТСЯ ИЗ ДИАСОФТА--
--RecallOrder_Custom_440_YS--

SELECT F.DOG_ID
      ,F.UUID
INTO vDogID,vUid
 FROM GC.FUNDS_BLOCK F
     ,GC.DOG D
WHERE 1=1
  AND F.OBJID = vObjid
  AND D.OBJID = F.DOG_ID;


--Протоколируем действия
INSERT INTO GC.SDM$440P_ENS_PROTOCOL
SELECT sysdate,vDogID,vUid,'Отзыв','WAIT','' from dual;
COMMIT;

--Сумма резерва по блокировке
SELECT GC.DOG_RESERVE.GETFUNDSBLOCKSUMM(vObjid)
INTO vSummReserve
FROM DUAL;

--Проставим текущей блокировке дату окончания
UPDATE GC.FUNDS_BLOCK 
SET DATE_E = SYSDATE 
WHERE OBJID = vObjid;

--Если корректировка на 0, то меняем статус, но резерв оставляем (Требование Тереховой)
UPDATE GC.FUNDS_BLOCK 
SET STATE = 'T' 
WHERE OBJID = vObjid;


UPDATE GC.SDM$440P_ENS_PROTOCOL
SET TEXT = 'Блокировка ID '||vObjid||' переведена в статус разблокирована, проставлена дата окончания.'
   ,STATUS = 'SUCCESS'
WHERE UUID = vUid
  AND DogID = vDogID
  AND Type_Oper = 'Отзыв'
  AND EVENT_DATE = (SELECT MAX(E.EVENT_DATE) 
                        FROM SDM$440P_ENS_PROTOCOL E
                       WHERE 1=1
                         AND E.UUID = vUid
                         AND Type_Oper = 'Отзыв');                                   
  commit;

COMMIT;
END;
/



-- End of DDL Script for Procedure GC.SDM$440P_ENS_RECALL
