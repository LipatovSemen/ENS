-- Start of DDL Script for Function GC.SDM$DOC_IS_FBLOCK
-- Generated 21.09.2023 11:29:39 from GC@RBSDEV

CREATE OR REPLACE 
FUNCTION sdm$doc_is_fblock(vUNO IN exp$oper.uno%type) 
return number
is
vCNT number;
 BEGIN
 
 
  BEGIN
  SELECT COUNT(1) -- ДОКУМЕНТ СФОРМИРОВАН ЧЕРЕЗ ФУНКЦИОНАЛ АРЕСТОВ
  INTO vCNT
  FROM GC.FUNDS_BLOCK_DOCS
  WHERE UNO = vUNO
    AND OPER_TYPE = 'TRANSFER';        
  EXCEPTION
    WHEN NO_DATA_FOUND THEN 
    vCNT := 0; --ВЫГРУЖАЕМ КАК ОБЫЧНО
  END; 
            
       RETURN vCNT;    
    END;
/



-- End of DDL Script for Function GC.SDM$DOC_IS_FBLOCK
