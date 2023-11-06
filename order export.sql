-- Start of DDL Script for Function GC.SDM_ORDER_EXPORT
-- Generated 21.09.2023 11:29:57 from GC@RBSDEV

CREATE OR REPLACE 
FUNCTION sdm_order_export(
--  $Archive: /SCRPT_UT/SDM/f_ordexp.sql $
--  $Revision: 20 $
  pOrderId number
) return boolean is
  cNlsLang constant varchar2(16):= 'RU8PC866';
  cDirOut constant varchar2(128):= '/u/sdm';
  cTexTabStrLen constant binary_integer := 80;
  --
  vDedt varchar2(20);
  vKred varchar2(20);
  vTipO varchar2(2);
  vSimKas varchar2(3);
  vKorr varchar2(20);
  vDirOut varchar2(128);
  vSep varchar2(1);
  vResult boolean;
  vOrder EXP$VW$ORDERS%rowtype;
  vOrder2 EXP$VW$ORDERS%rowtype;
  vMarginOrder EXP$VW$ORDERS%rowtype;
  vMarginUno exp$oper.uno%type;
  vMarginDeltaDt number;
  vMarginDeltaKt number;
  vCompAccNum varchar2(25);
  vCompCur varchar2(3);
  v613 varchar2(20);
  v614 varchar2(20);
  vOpRate number;
  vFilial EXP$VW$ORDERS.filial%type;
  vNatAccNum varchar2(25);
  vFileName varchar2(82);
  vFileText exp$files.file_text%type;
  vFile utl_file.file_type;
  vFileS utl_file.file_type;
  vFileP utl_file.file_type;
  vFileV utl_file.file_type;
  vLen binary_integer := 10;
  vPS_Dt PS.PS%type;
  vPS_Kt PS.PS%type;
  dExportDate date;
  n integer;
  vAmountSum2 number;
  vAmountSum1 number;
  vRate number;
  vOperation varchar2(2);
  vFilialName varchar2(40);
  vOPNum varchar2(1);
  vCountNal int;
  vCountUIP int;
  vCountZORG int; --mishkov

  vStatusSost varchar2(2);
  vKPPPOL varchar2(20);
  vKPPPLAT varchar2(20);
  vKBK varchar2(20);
  vOKTMO varchar2(20);    --- 107Н
  vOSNNPP varchar2(20);
  vNALPER varchar2(20);
  vNOMND varchar2(20);
  vDATAND varchar2(20);
  vTypeNP varchar2(20);
  vUIP varchar2(50);
  vUIPF varchar2(50); --УИП из Фактуры 31/01/2023
  VKPP varchar(10);  -- KANTEROV 22/05/2018
  vOCHEREDN varchar(2); --KANTEROV 22/05/2018
  vKS varchar2(20); --LIPATOV ВЫГРУЖАТЬ ЕКС
  vINN_PL varchar(15);
  vNumPP varchar(15); --KANTEROV 13/05/2022 для Фактурных МБ документов выгружать реальный номер из ПП.

  vODCLOSE int; ----08/08/2022 Выгружаем эквайринг по определенным счетам раз в день
  vAGREGATE_NNS int; ----08/08/2022 Выгружаем эквайринг по определенным счетам раз в день


  vExCur varchar2(10);                                         --## mishkov 03/02/2016
    vKodVidDoh  varchar2(2);   --- ###mishkov 21/05/2020  --- Код вида дохода поле income_type_code в main

  --
  type t_StrTab is table of varchar2(2000) index by binary_integer;
  vTexTab t_StrTab;
  --
  procedure AddLine2FileText(
    pLine varchar2
  ) is
  begin
    vFileText:= substr(vFileText||vSep||pLine,1,4000);
    vSep:= chr(10);
  end;
  --
  procedure PutLine(
    pParam1 varchar2,
    pParam2 varchar2
  ) is
    vLine varchar2(2000);
  begin
    vLine:= gc.GenText('%1:%2',rpad(pParam1,vLen),pParam2);
    AddLine2FileText(vLine);
    utl_file.put_line(vFile,convert(vLine,cNlsLang));
  end;
  --
  procedure Tex2StrTab(
    pStrTab in out t_StrTab,
    pTex varchar2,
    pLen binary_integer
  ) is
    i binary_integer;
    n binary_integer;
  begin
    n:= length(pTex);
    i:= 1;
    while i <= n loop         -----------------------------  mishkov 10/06/2014 hd90158
      pStrTab(pStrTab.count):= substr(pTex,i,pLen);
      i:= i + pLen;
    end loop;
  end;

   function isCloseDay(vOD gc.OdMap.DComp%Type) RETURN int
    is
    vRes int;
    begin
        begin
             select count(1) --ДЕНЬ НЕ ЗАКРЫТ
               into vRes
              from gc.odmap o
             where o.dcomp = vOD
               and o.dreal = to_date('31/12/4012','dd/mm/yyyy');
            exception
                 when no_data_found then
                 vRes := 0; --ДЕНЬ ЗАКРЫТ
            end;
  RETURN vRes;

  END;

  --
begin
  tpipe.send('sdm_order_export start $Revision: 20 $');
  vResult:= false;
  vINN_PL:=' ';
  --
  select * into vOrder from EXP$VW$ORDERS where id = pOrderId;
  --
  vOrder.Tex:=trim(replace(replace(substr(vOrder.Tex,1,254),chr(10),' '),chr(13))); -------Подавление ENTER


  begin
  select count(1) --выгружать раз в день
  into vAGREGATE_NNS
  from gc.sprav$values sv
  where sv.id_type = '2665802262'
    and sv.value1  = vOrder.RCP_LS;
   --Счета для ежедневной выгрузки по эквайрингу
  exception
    when no_data_found then
    vAGREGATE_NNS := 0; --выгружаем как обычно
  end;

  if vAGREGATE_NNS > 0 and substr(vOrder.pyr_ls,1,5) = '30233' THEN
       vODCLOSE:= isCloseDay(vOrder.OD);
       IF  vODCLOSE > 0 THEN
       update exp$orders set status = '1' where id = vOrder.id;
       return false;
       END IF;
  end if;

  update exp$orders set status = '2' where id = vOrder.id; -- kanterov 26/08/2013

  if vOrder.Grp = '99999' then
    -- Не выгружаем док-т с номером пачки 99999.
    return true;
  end if;



------------------------------------------------------------------- +mishkov 30/08/2013 + изм 29/11/2013
   IF vOrder.fin_op_id='215' or vOrder.fin_op_id='119' THEN
        vOrder.Tex:=a_NNS_TEX(vOrder.NUM);
    END IF;
-------------------------------------------------------------------------------------

  ---KANTEROV FAKTURA 13/05/2022
   vNumPP:=null;
  if LENGTH(vOrder.Num)<6 and vOrder.fin_op_id='147' THEN
     vNumPP :=vOrder.Num;
     select e.UNO
       into vOrder.Num
       from exp$oper e
      where e.order_id=vOrder.id;
  end if;

    --KANTEROV
  if vOrder.fin_op_id=19
  THEN

  vOrder.Tex:=vOrder.Tex||gc.SDM$NAZ_PLAT_EQ(vOrder.Pyr_Ls,vOrder.Rcp_Ls);

  IF gc.sdm$Summ_eq(vOrder.ID)<>0 THEN
      vOrder.Tex:=vOrder.Tex||' '||'Комиссия Банка '||gc.sdm$Summ_eq(vOrder.ID)||' руб. НДС не облагается.';

  END IF;
  END IF;

  IF vOrder.fin_op_id=80  --KANTEROV 22/03/2017
  THEN
  IF gc.sdm$Summ_eq_ext(vOrder.ID)<>0 THEN
      vOrder.Tex:=vOrder.Tex||' '||'Комиссия Банка '||gc.sdm$Summ_eq_ext(vOrder.ID)||' руб. НДС не облагается.';
  END IF;
  END IF;
  --
  begin
    -- Это курсовая разница?
    select o.* into vOrder2
      from exp$oper op1,convops c,exp$oper op2,exp$vw$orders o
      where op1.order_id = vOrder.Id
        and c.marg_uno = op1.uno
        and op2.uno = c.dt_uno
        and o.id = op2.order_id
        and rownum < 2;
    -- Да, это курсовая разница.
    if vOrder2.Status = '3' then
      -- Соответствующий мультивалютный обработан - выходим.
      return true;
    else
      -- Обработаем соответствующий мультивалютный, а вместе с ним и курсовую разницу.
      vOrder:= vOrder2;
    end if;
  exception
    when no_data_found then null;
  end;
  --
  Tex2StrTab(vTexTab,vOrder.tex,cTexTabStrLen);
  --
  -- Откроем файл.

  vFileName:= 'CFT_'||nvl(vOrder.Filial,'382')||'_'||nvl(vOrder.Grp,'nogrp')||'_'||vOrder.Num||'_'||to_char(sysdate,'HH24miss')||'.exp';
  --Бало до нового экспорта
 -- vFile := utl_file.fopen(cDirOut,vFileName,'a');
  IF vOrder.Filial<>'185746585' then
  vDirOut:= cDirOut||'/'||nvl(vOrder.Filial,'382');
  else
  vDirOut:= cDirOut||'/5004115';
  end if;
  begin
  vFile := utl_file.fopen(vDirOut,vFileName,'a');
    exception
    when others then
      app_err.put('0',0,GenText('Не удалось открыть/создать файл "%1/%2"',vDirOut,vFileName));
  end;
  -- Если головной филиал, то подставим значение "М", иначе оставим ID
  if vOrder.Filial = '382' then
     vFilial := 'M';
  else
     vFilial := vOrder.Filial;
  end if;
  --
  if vOrder.Filial = '382' then
     vKorr := '30102810300000000685'; vFilialName := '000';
  elsif vOrder.Filial = '1228080' then
     vKorr := '30102810005000000878'; vFilialName := 'С-ПЕТЕРБУРГ';
  elsif vOrder.Filial = '1368349' then
     vKorr := '30102810306000000000'; vFilialName := 'ТВЕРЬ';
  elsif vOrder.Filial = '1787601'then
     vKorr := '30102810403000000778'; vFilialName := 'ВОРОНЕЖ';
  elsif vOrder.Filial = '1788104' then
     vKorr := '30102810504000000843'; vFilialName := 'ПЕРМЬ';
  elsif vOrder.Filial = '2188666' then
     vKorr := '30102810807000000745'; vFilialName := 'Н-НОВГОРОД';
  elsif vOrder.Filial = '1788509' then
     vKorr := '30102810402000000001'; vFilialName := 'КРАСНОЯРСК';
  elsif vOrder.Filial = '4975298' then
     vKorr := '30102810508000000850'; vFilialName := 'ОМСК';
  elsif vOrder.Filial = '5004115' then
     vKorr := '30102810609000000088'; vFilialName := 'РОСТОВ';
  elsif vOrder.Filial = '185746585' then
     vKorr := '30102810610000000978'; vFilialName := 'ЕКАТЕРИНБУРГ';
  else
     vKorr := '30102810402000000001'; vFilialName := '000';
  end if;

  -- Получаем 613 и 614 счета для филиала (в рублях) во внутреннем представлении
  -- и после этого получаем внешний номер счета по настройке EXT_CONS_ACC

SELECT                                                                                                                                      --## mishkov 03/02/2016
    --decode(decode(vOrder.Pyr_Cur,'810',vOrder.Rcp_Cur,vOrder.Pyr_Cur),'810','84','840','85','978','512','84')  -- определяем код валюты     --## mishkov 03/02/2016
    decode(decode(vOrder.Pyr_Cur,'810',vOrder.Rcp_Cur,vOrder.Pyr_Cur),'810','84','840','85','978','512','756','2560284','826','510','84') -- определяем код валюты --## mishkov 05/02/2016
    into vExCur                                                                                                                             --## mishkov 03/02/2016
FROM dual;   --- vOrder.Pyr_Cur   vOrder.Rcp_Cur                                                                                            --## mishkov 03/02/2016

  v614 := gc.s_g_q_d (o_type  => 'SYSCUR',  -- тип объекта
                   o_id    => vExCur,        -- ID валюты 84 - рубли  85 USD  512  EUR    2560284 CHF 756    510 GBP 826                      --## mishkov 03/02/2016 --84,        -- ID валюты 84 - рубли
                   pfilial => vFilial, -- ID филиала
                   q_name  => 'S_EXCH_OUTGO' --название настройки
                  );
  SELECT value into v614 FROM l_qual J, acc A
  WHERE J.name='EXT_CONS_ACC' and A.objid=J.objid AND A.s=v614;

  v613 := gc.s_g_q_d (o_type  => 'SYSCUR',   -- тип объекта
                   o_id    => vExCur,        -- ID валюты 84 - рубли  85 USD  512  EUR                            --## mishkov 03/02/2016 --84,         -- ID валюты 84 - рубли
                   pfilial => vFilial,    -- ID филиала
                   q_name  => 'S_EXCH_INCOME' --название настройки
                  );
  SELECT value into v613 FROM l_qual J, acc A
  WHERE J.name='EXT_CONS_ACC' and A.objid=J.objid AND A.s=v613;

--  if vOrder.Fin_Op_Id in (8,9,10,11) then
  vOPNum:='0';
  if vOrder.Fin_Op_Code in (1,2) then
    -- Касса.  1 - Касса (календарный день)
    --         2 - Касса (опердень)
    -- Кусок от Меринова Алексея.

   /*if (substr(vOrder.Pyr_Ls,1,3)='408' and vOrder.Pyr_Cur='810') then
          vSimKas := '51';
   elsif (substr(vOrder.Rcp_Ls,1,3)='408' and vOrder.Pyr_Cur='810') then
          vSimKas := '31';
   else
   vSimKas := vOrder.Cash_sym;
   end if;*/  --Комментарий Кантеров

   vSimKas := vOrder.Cash_sym;
    if vOrder.fin_op_code = 1 then
        dExportDate := vOrder.vltr;
    else
        dExportDate := vOrder.od;
    end if;

    ----- mishkov 17/01/2012 hd 50627 (замена номера на ун.номер) -------------------
    if substr(vOrder.PYR_LS,1,5)='20208' and substr(vOrder.RCP_LS,1,5)='20202' then
        select e.UNO into vOrder.Num from exp$oper e where e.order_id=vOrder.id;
--          select m.UNO into vOrder.Num
--          from gc.main m where
--          NO=vOrder.NUM
--          and substr(gc.nns.get(m.s_dt,m.Cur,sysdate),1,5)='20208'
--          and substr(gc.nns.get(m.s_kt,m.Cur,sysdate),1,5)='20202';
    end if;
    -----------------------------------------------------------------------------------
    AddLine2FileText('%КАССДОК');
    utl_file.put_line(vFile,convert('%КАССДОК',cNlsLang));
    PutLine('НОМЕР',vOrder.Num);
    PutLine('ДАТАВВОДА',to_char(trunc(vOrder.created),'dd/mm/yyyy'));
    PutLine('ВРЕМЯ',to_char(vOrder.created,'hh24:mi:ss'));
    PutLine('ДАТА',to_char(trunc(dExportDate),'dd/mm/yyyy'));
-- Было до нового экспорта --    PutLine('ДАТА',to_char(trunc(vOrder.vltr),'dd/mm/yyyy'));
    PutLine('ПЛАН','Новый план');
    PutLine('ФИЛИАЛ',vFilialName);
    PutLine('ОБЛАСТЬ','Баланс');
    PutLine('ПАЧКА',vOrder.grp);
    --PutLine('ОПЕРАЦИЯ','9');                                                             --- -mishkov 20/08/2010
    PutLine('ОПЕРАЦИЯ',a_VID_OPER(substr(vOrder.Pyr_Ls,1,5),substr(vOrder.Rcp_Ls,1,5)));   --- +mishkov 20/08/2010
    PutLine('ВАЛЮТА',vOrder.Pyr_Cur);
    PutLine('ДЕБЕТ',vOrder.Pyr_Ls);
    PutLine('КРЕДИТ',vOrder.Rcp_Ls);
    PutLine('СУММА',vOrder.Pyr_Amount);
    PutLine('СИМКАСС',vSimKas);
    PutLine('СУММАКАСС',vOrder.Pyr_Amount);
    tpipe.send('sdm_order_export label 4');
    for i in 0..vTexTab.count-1 loop
      PutLine('ПРИМ'||to_char(i+1),vTexTab(i));
    end loop;
    utl_file.put_line(vFile,'%END');
    AddLine2FileText('%END');
    vOPNum:='1';
    tpipe.send('sdm_order_export label 5');

--  elsif vOrder.Fin_Op_Id = 3 then
  elsif vOrder.Fin_Op_Code = 7 then
    -- Межбанк

------------- Добавил определение UIP изм mishkov 06/03/2014

     SELECT count(1),count(decode(m.supplier_bill_id,'0','',m.supplier_bill_id))
       into vCountNal,vCountUIP
       FROM gc.main_nal m
      WHERE m.uno=vOrder.Num;
-------------------------------------
      IF vCountNal<>0 THEN
        SELECT n.Status_ID
              ,n.kpp_pol
              ,n.kpp_pl
              ,nvl(s_kbk.name,'')
              ,n.region_code ---nvl(s_okato.name,'')   ---107Н
              ,n.Base_ID
              ,decode(n.Period_str,'0','00.00.0000',n.Period_str)
              ,n.DOC_NUM
---              ,nvl(to_char(n.DOC_PERIOD_DATE,'dd.mm.yyyy'),'0') ---- 107Н   было DOC_PERIOD_DATE,'dd.mm.yyyy')
              --- налоговый платеж 0 таможенный 00
              ,nvl(to_char(n.DOC_PERIOD_DATE,'dd.mm.yyyy'),decode(n.rekv_type,'C','00','N','0','0')) ---- 107Н   было DOC_PERIOD_DATE,'dd.mm.yyyy')
              ,n.Type_ID
              ,nvl(n.Supplier_bill_id,'0')  --- 107Н       было    n.Supplier_bill_id
              ,nvl(n.INN_PL,' ') --KANTEROV 21/11/2019
          into vStatusSost
               ,vKPPPOL
               ,vKPPPLAT
               ,vKBK
               ,vOKTMO
               ,vOSNNPP
               ,vNALPER
               ,vNOMND
               ,vDATAND
               ,vTypeNP
               ,vUIP
               ,vINN_PL
          FROM gc.main_nal n
              ,gc.sprav s_kbk
-- 107Н              ,gc.sprav s_okato
          WHERE n.uno=vOrder.Num
            and s_kbk.id(+)=n.kbk_id
            and s_kbk.ntype(+)='96';
-- 107Н           and s_okato.id(+)=n.region_code --Okato_id ---------------------
-- 107Н           and s_okato.nType(+)='89';
      END IF;


BEGIN
select m.income_type_code into vKodVidDoh  from gc.main m where m.uno=vOrder.Num; --- ###mishkov 21/05/2020
EXCEPTION WHEN NO_DATA_FOUND
THEN
 vKodVidDoh:=null;
END;

---------------------- +mishkov 11/03/2015 изменение счета кредита (PYR_LS) при выгрузке ZORG 0059 кодом
SELECT count(1) into vCountZORG
from gc.main m where m.k_o='0059' and m.doc_group='ZORG' and m.uno=vOrder.Num;

IF vCountZORG<>0
    THEN
        SELECT mr.nns into vOrder.Pyr_Ls
        from gc.main_rekv mr, gc.main m where m.uno=mr.uno and m.k_o='0059' and m.doc_group='ZORG'and m.uno=vOrder.Num;
END IF;


-- КПП ПОЛУЧАТЕЛЯ и ПРИОРИТЕТ kanterov 22/05/2018 +КОРСЧЕТ (
vKPP:='-'; vOcheredn:='5';
BEGIN
SELECT KPP, OCHEREDN, KS
  INTO vKPP, vOCHEREDN, vKS
  FROM GC.Rekv_doc d
  WHERE UNO=vOrder.Num;
EXCEPTION WHEN NO_DATA_FOUND THEN
 vOCHEREDN:='5'; VKPP:='-'; vKS:=null;
END;

if vOcheredn='' then vOcheredn:='5'; end if;

if vNumPP is NULL THEN vNumPP:=substr(vOrder.Num,-6,6); END IF;---- изменил номер с 3 на 6 (80467) kanterov FAKTURA 13/05/2022

    AddLine2FileText('%МЕЖБНКДОК');
    utl_file.put_line(vFile,convert('%МЕЖБНКДОК',cNlsLang));
    PutLine('ПАЧКА',vOrder.grp);
    PutLine('ВАЛЮТА',vOrder.Pyr_Cur);
    IF GC.SDM$DOC_IS_FBLOCK(vOrder.Num) > 0 then --15082023
    PutLine('ОПЕРАЦИЯ','6'); --LIPATOV
    ELSE
    PutLine('ОПЕРАЦИЯ','1'); --LIPATOV
    END IF; 
    PutLine('НОМЕР',vNumPP);   ---- изменил номер с 3 на 6 (80467) kanterov Faktura 13/05/2022
    PutLine('ПЛАН','Новый план');
    PutLine('ФИЛИАЛ',vFilialName);
    PutLine('ОБЛАСТЬ','Баланс');
    PutLine('ДЕБЕТ',vOrder.Pyr_Ls);
    PutLine('КРЕДИТ',vKorr);
    PutLine('СУММА',vOrder.Pyr_Amount);
    PutLine('ДАТАВАЛ',to_char(trunc(vOrder.vltr),'dd/mm/yyyy'));
    PutLine('ДАТАПЛАТ',to_char(trunc(vOrder.vltr),'dd/mm/yyyy'));
    PutLine('ДАТАПРДОК',to_char(trunc(vOrder.vltr),'dd/mm/yyyy'));

   -- IF vCountNal>0 and vStatusSost='13' THEN vOrder.Queue:='4'; ELSE vOrder.Queue:=vOCHEREDN; END IF; -- KANTEROV 22/05/2018

    vOrder.Queue:=vOCHEREDN; --- #mishkov 30/07/2020  по заявке HD 202861

    PutLine('ОЧЕРЕДНПЛ',vOrder.Queue);
    if vCountNal=0 and vKPP<>'-' THEN
    PutLine('КПППОЛ',vKPP);

    END IF;

    PutLine('ГРУППАДОК','');
---    PutLine('ОБСЛУЖ','Электронные-6');                                   -- -mishkov 12/02/2016
        IF vCountZORG=1 THEN      -- ZORG+0059                              -- +mishkov 12/02/2016
            PutLine('ОБСЛУЖ','ДБС Межбанк Банк-клиент (Основное время)');   -- Zorg да     +mishkov 12/02/2016
        ELSE                                                                -- +mishkov 12/02/2016
            PutLine('ОБСЛУЖ','Электронные-6');                              -- Zorg нет    +mishkov 12/02/2016
        END IF;                                                             -- +mishkov 12/02/2016




    ---PutLine('ИМЯОТПР',gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio));               ------ изм mishkov 11/11/2009

---    IF vOrder.Rcp_Amount>=15000 THEN                                            --- mishkov 23/11/2009
--IF vOrder.Rcp_Amount>=15000 or substr(vOrder.RCP_LS,1,3) between '401' and '406' THEN     --- mishkov 23/11/2009   +mishkov 03/02/2014 107Н
--        PutLine('ИМЯОТПР',gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio));
--       ELSE
--        --PutLine('ИМЯОТПР',gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio));
--        IF instr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),'//')=0 THEN
--            PutLine('ИМЯОТПР',vOrder.Pyr_NP_Fio);
--        ELSE
--            PutLine('ИМЯОТПР',substr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),1,instr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),'//')-1));
--        END IF;
--      END IF;
---------------------------------------------- 06/02/2014 mishkov
--- если 107Н
--### +19/02/2020
--- если 107Н
IF  substr(vOrder.RCP_LS,1,5)='40101'
    or (substr(vOrder.RCP_LS,1,5)='40501' and substr(vOrder.RCP_LS,14,1)='2')
    or (substr(vOrder.RCP_LS,1,5) in ('40601','40701') and substr(vOrder.RCP_LS,14,1) in ('1','3'))
    or (substr(vOrder.RCP_LS,1,5) in ('40503','40603','40703') and substr(vOrder.RCP_LS,14,1)='4') THEN     --- mishkov 05/02/2014 107П
    IF instr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),'//')=0 THEN  --- нет //
        IF ((vINN_PL !=' ') or nvl(vOrder.Pyr_NP_Idn,' ')<>' ') THEN --- есть ИНН  ###+19/02/2020
            PutLine('ИМЯОТПР',vOrder.Pyr_NP_Fio);
        ELSE
            PutLine('ИМЯОТПР',vOrder.Pyr_NP_Fio||gc.SDM_ACC2ADR(vOrder.PYR_NP_LS)); ----нет ИНН добавим адр
        END IF;
    ELSE                                                         ---- есть //
        IF ((vINN_PL !=' ') or nvl(vOrder.Pyr_NP_Idn,' ')<>' ') THEN --- есть ИНН
            PutLine('ИМЯОТПР',substr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),1,instr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),'//')-1));   --- удаляем все после // - оставляем только имя
        ELSE
            PutLine('ИМЯОТПР',substr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),1,instr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),'//')-1)||gc.SDM_ACC2ADR(vOrder.PYR_NP_LS)); --- удаление ИНН и // из имени и добавляем адр в //
        END IF;
    END IF;
     ------------------------------------------------------------------------

--- если не 107Н
ELSE
--- если не 107 >=15000
    IF vOrder.Rcp_Amount>=15000 THEN
        IF ((vINN_PL !=' ') or nvl(vOrder.Pyr_NP_Idn,' ')<>' ')  THEN  ---есть ИНН
            ---PutLine('ИМЯОТПР',substr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),1,instr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),'//')-1)); --- только имя
            PutLine('ИМЯОТПР',vOrder.Pyr_NP_Fio);
        ELSE
            PutLine('ИМЯОТПР',vOrder.Pyr_NP_Fio); --- как есть должен быть и адресс
        END IF;
    ELSE
        PutLine('ИМЯОТПР',vOrder.Pyr_NP_Fio);  --- если ничего нет кроме имени
    END IF;
END IF;
--### +19/02/2020
--------------------------------------------------------------------------------
          --- mishkov 23/11/2009
    PutLine('ИМЯПОЛУЧ',vOrder.Rcp_Name);
    PutLine('МФООТПР',vOrder.Pyr_Bik);
    PutLine('МФОПОЛУЧ',vOrder.Rcp_Bik);
    ---PutLine('Р/СОТПР',vOrder.Pyr_Ls);     --- #mishkov23092020
    PutLine('Р/СОТПР',vOrder.Pyr_NP_Ls); --- #mishkov23092020
    PutLine('Р/СПОЛУЧ',vOrder.Rcp_Ls);

    --Добавление Единого Казначейского Счета
    IF SUBSTR(vOrder.Rcp_Ls,1,1) = '0' and SUBSTR(vOrder.Rcp_Ls,6,3) = '643' THEN
    PutLine('К/СПОЛУЧ',vKS);
    END IF;

    --Наиграем УИП из Фактуры для получателей 40822 --KANTEROV 31/01/2023
    --Не актуально. С версии 3.23.012.004 код 22 передаетсяв штатное место main_nal.supplier_bill_id
    /*IF SUBSTR(vOrder.Rcp_Ls,1,5) = '40822' THEN
        vUIPF:='x';
        BEGIN

        SELECT P.taxsupplier_bill_id
          INTO vUIPF
          FROM FAKTURA.FAK$PAYDOCRU P
          WHERE P.docref=vOrder.Num;

        EXCEPTION WHEN NO_DATA_FOUND THEN
        vUIPF:='x';
        END;

       IF vUIPF <> 'x' THEN
       PutLine('КОД_УИП',vUIPF);
       END IF;

    END IF;
    */


    --Проверка есть ли платежи по этим реквизитам за последний год
    IF (    -- SUBSTR(vOrder.Rcp_Ls,1,5) in ('40817','40820','40702','30232','47422') --47422 HD
             SUBSTR(vOrder.Rcp_Ls,1,5) in ('47422') --KANTEROV Упростил выражение выше с учетом нижеследующего условия 210142
          or SUBSTR(vOrder.Rcp_Ls,1,3) in ('407','408','423','426')
          or SUBSTR(vOrder.Rcp_Ls,1,2) in ('30')   --HD 210142
       )

       AND GC.sdm$check_mbnk(vOrder.Num,vOrder.Rcp_Bik,vOrder.Rcp_Ls) = '0'
       AND vOrder.Rcp_Amount>=100000 --mishkov Приказ от 19/12/2022 года.

    THEN
       PutLine('СДМКОНТРОЛ','1');
    END IF;

    ---PutLine('ИННОТПР',vOrder.Pyr_Idn);                                       ------ - mishkov 10/11/2009
    ---PutLine('ИННОТПР',vOrder.Pyr_NP_Idn);                                       ------ + mishkov 10/11/2009
    ---IF ((vOrder.Pyr_NP_Idn !=' ' and vOrder.Rcp_Amount>=15000) or (vCountNal>0)) THEN                 ------   mishkov                             ------ + mishkov 10/11/2009
--    IF ((vOrder.Pyr_NP_Idn !=' ') or (vCountNal>0)) THEN ----  +12/04/2016  hd128407
     --   PutLine('ИННОТПР',vOrder.Pyr_NP_Idn);
    IF ((vINN_PL !=' ') or (vCountNal>0) or nvl(vOrder.Pyr_NP_Idn,' ')<>' ') THEN ----  +12/04/2016  hd128407
            IF nvl(vOrder.Pyr_NP_Idn,' ')<>' ' and vINN_PL= ' '
              THEN
              vINN_PL:=vOrder.Pyr_NP_Idn;
            END IF;


         PutLine('ИННОТПР',vINN_PL);
     END IF;
    PutLine('ИННПОЛУЧ',vOrder.Rcp_Idn);
    PutLine('БАНКПОЛУЧ',vOrder.Rcp_Bank);
    PutLine('ОТВЕТОИСП','');
    PutLine('ДАТАВВОДА','');
    PutLine('ВРЕМЯ','');
    --PutLine('БАНКОТПР',vOrder.Pyr_Bank);
    for i in 0..vTexTab.count-1 loop
      PutLine('ПРИМ'||to_char(i+1),vTexTab(i));
    end loop;
    PutLine('ДАТА',to_char(trunc(vOrder.od),'dd/mm/yyyy'));
    --Налоги--

    IF vCountNal<>0 THEN

        PutLine('СТАТУССОСТ',vStatusSost);
        PutLine('КПППОЛ',vKPPPOL);
        PutLine('КПППЛАТ',vKPPPLAT);
        PutLine('КБК',vKBK);
        PutLine('ОКТМО',vOKTMO);   ---- 107Н
        PutLine('ОСНОВНПП',vOSNNPP);

        PutLine('НАЛПЕР',vNALPER);
        ---PutLine('НОМЕРНД',vNOMND);
        IF vStatusSost='16' or vStatusSost='24' THEN                        -- mishkov 27/03/2014
            PutLine('НОМЕРНД',gc.SDM_ACC2DOC(vOrder.PYR_NP_LS));            -- mishkov 27/03/2014
        ELSE                                                                -- mishkov 27/03/2014
            PutLine('НОМЕРНД',vNOMND);                                      -- mishkov 27/03/2014
        END IF;                                                             -- mishkov 27/03/2014

        PutLine('ДАТАНАЛДОК',vDATAND);
        PutLine('ТИПНАЛПЛАТ',vTypeNP);
        PutLine('КОД_УИП',vUIP);

    END IF;

    --Налоги.

----  Доп ТЭГИ по Уралеву HelpDesk 71779
----  +mishkov 18/07/2013 ----------------------------------------
IF substr(vOrder.RCP_LS,1,5) in ('40601','40701','40503','40603','40703','40501','40101') THEN
    PutLine('ДОКТИП',gc.A_PayerTags(vOrder.PYR_NP_LS,'1'));
    PutLine('ГР',    gc.A_PayerTags(vOrder.PYR_NP_LS,'2'));
    PutLine('ДОК',   gc.A_PayerTags(vOrder.PYR_NP_LS,'3'));
END IF;
------------------------------------------------------------------
IF vKodVidDoh IS NOT NULL THEN
PutLine('НАЗНПЛКОД',vKodVidDoh); ----###mishkov 21/05/2020
END IF;

    utl_file.put_line(vFile,'%END');
    AddLine2FileText('%END');
    vOPNum:='2';
--  elsif vOrder.Fin_Op_Id in (1,16,17,37) and vOrder.Pyr_Cur != vOrder.Rcp_Cur then
  elsif vOrder.Fin_Op_Code in (3,4) and vOrder.Pyr_Cur != vOrder.Rcp_Cur then
    -- Конвертация.
    --KANTEROV 06/12/2013 - Старчикова Инцидент.
    if (substr(vOrder.PYR_LS,1,8)='20202810' or substr(vOrder.RCP_LS,1,8)='20202810') and vOrder.Cash_Sym is NULL
    then

     begin

     select NAME
      into vSimKas
      from Sprav where id=(select max(cash_sym_id)
                             from exp$oper e
                                 ,gc.maina m
                            where e.order_id=vOrder.id
                              and m.uno in (e.uno,e.uno2)
                           )
                     and NType='7';
     exception when no_data_found
     then
     vSimKas:=null;
     end;

     vOrder.Cash_sym:=vSimKas;

     end if;

    -- Курсовую разницу включим в файл документа конвертации.
    begin
      select op2.order_id,op2.uno
        into vMarginOrder.id,vMarginUno
        from exp$oper op1,convops c,exp$oper op2
        where op1.order_id = vOrder.Id
          and c.dt_uno = op1.uno
          and op2.uno = c.marg_uno
          and rownum < 2;
      select * into vMarginOrder
        from exp$vw$orders t
        where t.id = vMarginOrder.id;
      select b_dt.ps,b_kt.ps into vPS_Dt,vPS_Kt
        from maina m,acc a_dt,bal b_dt,acc a_kt,bal b_kt
        where m.uno = vMarginUno
          and a_dt.s = m.s_dt and a_dt.cur = m.cur
          and b_dt.bs = a_dt.bs and b_dt.cur = a_dt.cur and b_dt.filial = a_dt.filial
          and a_kt.s = m.s_kt and a_kt.cur = m.cur
          and b_kt.bs = a_kt.bs and b_kt.cur = a_kt.cur and b_kt.filial = a_kt.filial;
      if vPS_Dt in ('013','030','015','025') then
        vCompAccNum:= vMarginOrder.Pyr_Ls;
        vCompCur:= vMarginOrder.Pyr_Cur;
      elsif vPS_Kt in ('015','025','013','030') then
        vCompAccNum:= vMarginOrder.Rcp_Ls;
        vCompCur:= vMarginOrder.Rcp_Cur;
      end if;
    exception
      when no_data_found then null;
    end;
    --
    if (substr(vOrder.Pyr_Ls,1,3)='408' and vOrder.Rcp_Cur='810') then
          vSimKas :=vOrder.Cash_sym ;
    else
        if (substr(vOrder.Rcp_Ls,1,3)='408' and vOrder.Pyr_Cur='810') then
          vSimKas :=vOrder.Cash_sym;
        elsif vOrder.Pyr_Cur = p_cur.nat_cur then
           vNatAccNum:= vOrder.Pyr_Ls;
           vSimKas :=vOrder.Cash_sym;
        else
            if vOrder.Rcp_Cur = p_cur.nat_cur then
            vNatAccNum:= vOrder.Rcp_Ls;
            vSimKas :=vOrder.Cash_sym;
            else
            vSimKas := vOrder.Cash_sym;
            end if;
        end if;
     end if;
 --   if vOrder.Pyr_Cur = p_cur.nat_cur then
  --    vNatAccNum:= vOrder.Pyr_Ls;
  --    vSimKas :='30';
  --  elsif vOrder.Rcp_Cur = p_cur.nat_cur then
   ---   vNatAccNum:= vOrder.Rcp_Ls;
  --    vSimKas :='57';
  --  end if;
    --
    vMarginDeltaDt:= 0;
    vMarginDeltaKt:= 0;
    --
    if vMarginOrder.id is not null then
      if vOrder.Pyr_Ls = vMarginOrder.Pyr_Ls and vOrder.Pyr_Cur = vMarginOrder.Pyr_Cur then
        vMarginDeltaDt:= vMarginOrder.Pyr_Amount;
      end if;
      if vOrder.Rcp_Ls = vMarginOrder.Rcp_Ls and vOrder.Rcp_Cur = vMarginOrder.Rcp_Cur then
        vMarginDeltaKt:= vMarginOrder.Rcp_Amount;
      end if;
    end if;
    --
--    vAmountSum1 := vOrder.Pyr_Amount+vMarginDeltaDt;

    if vMarginOrder.id is not null then       -- не ЦБ
      -- Есть курсовая разница.
      vAmountSum1 := vOrder.Pyr_Amount+vMarginDeltaDt;
      vAmountSum2:= vOrder.Rcp_Amount+vMarginDeltaKt;
      vRate := 0;
    else                                      -- ЦБ
        if substr(vOrder.Pyr_Ls,1,5) = '70606' then
           vAmountSum1 := null;
           vAmountSum2 := vOrder.Rcp_Amount;
           vRate:= vOrder.Nrate;
        elsif substr(vOrder.Rcp_Ls,1,5) = '70601' then
           vAmountSum1 := vOrder.Pyr_Amount;
           vAmountSum2 := null;
           vRate:= vOrder.Nrate;
        else
           vAmountSum1 := vOrder.Pyr_Amount;
           vAmountSum2 := vOrder.Rcp_Amount;
           if (vAmountSum2/vAmountSum1 < vOrder.Nrate ) then
              vCompAccNum := v613;
           else
              vCompAccNum := v614;
           end if;
           vRate:= null;
        end if;
    end if;
    --
    if vOrder.Fin_Op_Code = 3 then
        dExportDate := vOrder.vltr;
    else
        dExportDate := vOrder.od;
    end if;
    --
    if vOrder.Fin_Op_Id in (95,96) then
       dExportDate := vOrder.created;
    end if;
    --
    AddLine2FileText('%КОНВЕРТАЦ');
    utl_file.put_line(vFile,convert('%КОНВЕРТАЦ',cNlsLang));
    PutLine('ПЛАН','Новый план');
    PutLine('ОБЛАСТЬ','Баланс');
    PutLine('ФИЛИАЛ',vFilialName);
    PutLine('ДАТА',to_char(trunc(dExportDate),'dd/mm/yyyy'));
-- Было до нового экспорта -- PutLine('ДАТА',to_char(trunc(vOrder.od),'dd/mm/yyyy'));
    PutLine('ПАЧКА',vOrder.grp);
    PutLine('НОМЕР',vOrder.Num);
    PutLine('ВАЛЮТА1',vOrder.Pyr_Cur);
    PutLine('ВАЛЮТА2',vOrder.Rcp_Cur);
    PutLine('СУММА1',vAmountSum1);
    PutLine('СУММА2',vAmountSum2);
    PutLine('КУРС',vOrder.Rate);
    --PutLine('ВИДОПЕР1','9');                                                              --- mishkov 28/05/2010
    PutLine('ВИДОПЕР1',a_VID_OPER(substr(vOrder.Pyr_Ls,1,5),substr(vOrder.Rcp_Ls,1,5)));    --- mishkov 28/05/2010
    PutLine('НОМЕРДОК1','');
    PutLine('СЧЕТИСТОЧ',vOrder.Pyr_Ls);
    PutLine('СЧЕТКОНВ1','77777777777777777777');
    --PutLine('ВИДОПЕР2','9');                                                              --- mishkov 28/05/2010
    PutLine('ВИДОПЕР2',a_VID_OPER(substr(vOrder.Pyr_Ls,1,5),substr(vOrder.Rcp_Ls,1,5)));    --- mishkov 28/05/2010
    PutLine('НОМЕРДОК2','');
    PutLine('СЧЕТПРИЕМ',vOrder.Rcp_Ls);
    PutLine('СЧЕТКОНВ2','77777777777777777777');
    PutLine('СЧЕТНАЦ',vNatAccNum);
    --PutLine('ОПЕРКОМП','9');                                                              --- mishkov 28/05/2010
    PutLine('ОПЕРКОМП',a_VID_OPER(substr(vNatAccNum,1,5),substr(vCompAccNum,1,5)));         --- mishkov 28/05/2010
    PutLine('НОМЕРКОМП','');
    PutLine('СЧЕТКОМП',nvl(vCompAccNum,'77777777777777777777'));
    PutLine('ВАЛЮТАКОМП',vCompCur);
    PutLine('СУММАКОМИС','0.00');
    PutLine('ДАТАВАЛ',to_char(trunc(dExportDate),'dd/mm/yyyy'));
-- Было до нового экспорта -- PutLine('ДАТАВАЛ',to_char(trunc(vOrder.vltr),'dd/mm/yyyy'));
    for i in 0..vTexTab.count-1 loop
      PutLine('ПРИМ'||to_char(i+1),vTexTab(i));
    end loop;
    PutLine('КОМП_ИСТ','ДА');
    PutLine('СИМКАСС',vSimKas);
    utl_file.put_line(vFile,'%END');
    AddLine2FileText('%END');
    vOPNum:='3';
 -- else   --   vOrder.Fin_Op_Code in (5,6)
    --Внутрибанковская одновалютная операция
    --
    elsif vOrder.Fin_Op_Code in (5,6) then

    if vOrder.Fin_Op_Code= 5 then
        dExportDate := vOrder.vltr;
    else
        dExportDate := vOrder.od;
    end if;
    --
    if vOrder.Fin_Op_Id in (95,96) then
       dExportDate := vOrder.created;
    end if;
   -- Было до внебаланса
   -- if vOrder.Fin_Op_Code = 5 then
   --    dExportDate := vOrder.vltr;
   -- else
   --     dExportDate := vOrder.od;
   -- end if;
    --А вот это мой кусок по исправительным проводкам
   if vOrder.Rcp_Cur = '810' then
      vKorr:= '47423810600009020012';
   elsif vOrder.Rcp_Cur = '840' then
      vKorr:= '47423840900009020012';
   else
      vKorr:= '47423978500009020012';
   end if;
    --

   if vOrder.Fin_Op_Id= 93 then
       vDedt := vKorr;
       vKred := vOrder.Rcp_Ls;
    elsif vOrder.Fin_Op_Id= 94 then
       vDedt := vOrder.Pyr_Ls;
       vKred := vKorr;
    else
       vDedt := vOrder.Pyr_Ls;
       vKred := vOrder.Rcp_Ls;
    end if;
        ---
    if( vOrder.Pyr_Ls  like '706%' or vOrder.Rcp_Ls like '706%') then
       vOperation := '9';
    else
       vOperation := '1';
    end if;

    if substr(vDedt,1,3) in ('408','423','426','407') and substr(vKred,1,3) in ('706') then
    vOperation:='17';
    end if;
    if substr(vDedt,1,5) in ('47423') and substr(vKred,1,3) in ('706') then
    vOperation:='17';
    end if;  -- KANTEROV 19/03/2010

    -- КПП ПОЛУЧАТЕЛЯ и ПРИОРИТЕТ kanterov 22/05/2018
    vKPP:=''; vOcheredn:='';
   BEGIN
   SELECT nvl(KPP,'-'), nvl(OCHEREDN,'5')
     INTO vKPP, vOCHEREDN
     FROM GC.Rekv_doc d
    WHERE UNO=vOrder.Num;
   EXCEPTION WHEN NO_DATA_FOUND THEN
   vKPP:='-'; vOCHEREDN:='5';
   END;
    if vOcheredn='' then vOcheredn:='5'; end if;


    AddLine2FileText('%ДОКУМЕНТ');
    utl_file.put_line(vFile,convert('%ДОКУМЕНТ',cNlsLang));
    PutLine('ДАТА',to_char(trunc(dExportDate),'dd/mm/yyyy'));
-- Было до нового экспорта -- PutLine('ДАТА',to_char(trunc(vOrder.od),'dd/mm/yyyy'));
    PutLine('ПЛАН','Новый план');
    PutLine('ФИЛИАЛ',vFilialName);
    PutLine('ОБЛАСТЬ','Баланс');
------------------------------------------ +mishkov 15/10/2013 (75052) ---------
--  PutLine('ПАЧКА',vOrder.grp);
    if substr(vDedt,1,5) in ('40817','40820','42301') and substr(vKred,1,5) in ('47427','47423') and vOrder.Filial='382' then
        if  vOrder.Pyr_Cur='810' then
            PutLine('ПАЧКА','1609');
        else
            PutLine('ПАЧКА','1617');
        end if;
    else
        PutLine('ПАЧКА',vOrder.grp);
    end if;
--------------------------------------------------------------------------------
--  PutLine('ОПЕРАЦИЯ',vOperation);                                          -- mishkov 19/05/2010
    PutLine('ОПЕРАЦИЯ',gc.a_VID_OPER(substr(vDedt,1,5),substr(vKred,1,5)));  -- mishkov 19/05/2010

    /*KANTEROV 66692*/
    IF substr(vDedt,1,5) in ('60305','60306','47422') and substr(vKred,1,5) in ('40817','40820','42301') THEN
    PutLine('ОЧЕРЕДНПЛ','3');
    ELSE
    vOrder.Queue:=vOCHEREDN;-- KANTEROV 22/05/2018

    PutLine('ОЧЕРЕДНПЛ',vOrder.Queue);
    END IF;

    PutLine('ВАЛЮТА',vOrder.Pyr_Cur);
    PutLine('НОМЕР',vOrder.Num);
    PutLine('ДЕБЕТ',vDedt);
    PutLine('ВАЛЮТАКРЕ',vOrder.Rcp_Cur);
    PutLine('КРЕДИТ',vKred);
    IF vOrder.Pyr_NP_Idn !=' ' and vOrder.Rcp_Amount>=15000 THEN                 ------   mishkov                             ------ + mishkov 10/11/2009
    PutLine('ИННОТПР',vOrder.Pyr_NP_Idn); END IF;                               ------ + mishkov 10/11/2009
    IF vOrder.Pyr_NP_Fio NOT LIKE '%СДМ-БАНК%' THEN

       IF vOrder.Rcp_Amount>=15000 THEN                                         --- изм mishkov 23/11/2009
        PutLine('ИМЯОТПР',gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio));              --
       ELSE
        ---PutLine('ИМЯОТПР',gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio));
        IF instr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),'//')=0 THEN
            PutLine('ИМЯОТПР',vOrder.Pyr_NP_Fio);
        ELSE
            PutLine('ИМЯОТПР',substr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),1,instr(gc.A_GETREPLACEPLAT(vOrder.Pyr_NP_Fio),'//')-1));
        END IF;
      END IF;

     END IF;                                                                    --- изм mishkov 23/11/2009


    IF vOrder.Rcp_Name NOT LIKE '%СДМ-БАНК%' THEN
    PutLine('ИМЯПОЛУЧ',vOrder.Rcp_Name); END IF;
 --- #mishkov20/07/2022
        IF vOrder.fin_op_id='148' THEN
            PutLine('Р/СОТПР',vOrder.Pyr_NP_Ls);
        END IF;
------------------------
    PutLine('Р/СПОЛУЧ',vOrder.Rcp_Ls);
    if vKPP<>'-' THEN  PutLine('КПППОЛ',vKPP);   END IF; --KANTEROV 22/05/2018
    PutLine('СУММА',vOrder.Pyr_Amount);
    for i in 0..vTexTab.count-1 loop
      PutLine('ПРИМ'||to_char(i+1),vTexTab(i));
    end loop;


--------------------------------------------------- ЖКХ -- добавить поле КОД_УИП для внутрибанковских документов +mishkov 20/07/2016 HD 133659
        SELECT count(decode(m.supplier_bill_id,'0','',m.supplier_bill_id)) into vCountUIP
        FROM gc.main_nal m
        WHERE m.uno=vOrder.Num;
        ---
        IF vCountUIP<>0 THEN
            SELECT nvl(n.Supplier_bill_id,'0') into vUIP
            FROM gc.main_nal n
            WHERE n.uno=vOrder.Num;

            PutLine('КОД_УИП',vUIP);
        END IF;
------------------------------------------------------------------------------------------------------------------------------------------------
    IF vKODVIDDOH IS NOT NULL THEN
    PutLine('НАЗНПЛКОД',vKodVidDoh); ----###mishkov 21/05/2020
    END IF;

    utl_file.put_line(vFile,'%END');
    AddLine2FileText('%END');
    vOPNum:='4';
    elsif vOrder.Fin_Op_Code = 8 then --внебаланс
    --if vOrder.Fin_Op_Code = 8 then --внебаланс
    if (vOrder.Pyr_Ls like '99998%' or vOrder.Rcp_Ls like '99999%') then
       vTipO := '0';
    elsif (vOrder.Rcp_Ls like '99998%' or vOrder.Pyr_Ls like '99999%')then
       vTipO := '1';
    else
       vTipO := '2';
    end if;

    ---
    if (substr(vOrder.Pyr_Ls,1,3) = '999' and vOrder.Rcp_Cur!= '810') then
           vAmountSum1 := null;
           vAmountSum2 := vOrder.Rcp_Amount;
           vRate:= vOrder.Nrate;
        else
           vAmountSum1 := vOrder.Pyr_Amount;
           vAmountSum2 := null;
           vRate:= vOrder.Nrate;
    end if;

    AddLine2FileText('%ЦЕНВНЕБЗЧ');
    utl_file.put_line(vFile,convert('%ЦЕНВНЕБЗЧ',cNlsLang));
--PutLine('ДАТА',to_char(trunc(dExportDate),'dd/mm/yyyy'));
    PutLine('ДАТА',to_char(trunc(vOrder.od),'dd/mm/yyyy'));
    PutLine('ПЛАН','Новый план');
    PutLine('ФИЛИАЛ',vFilialName);
    PutLine('ОБЛАСТЬ','Баланс');
    PutLine('ПАЧКА',vOrder.grp);
    ---PutLine('ОПЕРАЦИЯ',vOperation);                     ---- Mishkov 08/06/2010
    PutLine('ОПЕРАЦИЯ',a_VID_OPER(substr(vOrder.Pyr_Ls,1,5),substr(vOrder.Rcp_Ls,1,5)));    ---- Mishkov 08/06/2010
    PutLine('ВАЛЮТА',vOrder.Pyr_Cur);
    PutLine('НОМЕР',vOrder.Num);
    PutLine('ДЕБЕТ',vOrder.Pyr_Ls);
    PutLine('ВАЛЮТАКРЕ',vOrder.Rcp_Cur);
    PutLine('КРЕДИТ',vOrder.Rcp_Ls);
    --PutLine('СУММА',vOrder.Pyr_Amount);
    PutLine('СУММА',vAmountSum1);
    PutLine('СУММАКРЕ',vAmountSum2);
    PutLine('КУРС',vRate);
    PutLine('ТИПОПЕР',vTipO);
    for i in 0..vTexTab.count-1 loop
      PutLine('ПРИМ'||to_char(i+1),vTexTab(i));
    end loop;
    utl_file.put_line(vFile,'%END');
    AddLine2FileText('%END');
    vOPNum:='5';
  end if;
   --
  utl_file.fclose(vFile);
  --
  /*
  declare
    vLogFName varchar2(100);
  begin
    select dbms_session.unique_session_id||'.log' into vLogFName from dual;
    vFile:=utl_file.fopen(cDirOut,vLogFName,'a');
    utl_file.put_line(vFile,GenText('Время: %1; файл %2',to_char(sysdate,'dd/mm/yy hh24:mi:ss'),vFileName));
    utl_file.put_line(vFile,GenText('Номер: %1; Fin_Op_Id = %2; Fin_Op_Code = %3; OPNUM = %4',vOrder.Num,vOrder.Fin_Op_Id, vOrder.fin_op_code,vOPNum));
    utl_file.fclose(vFile);
  end;
  */
  --
  if vMarginOrder.id is not null then
    if vMarginOrder.id = pOrderId then
      -- Сменим статус соответствующему мультивалютному док-ту.
      update exp$orders set status = '3' where id = vOrder.id;
    else
      -- Соответствующему документу курсовой разницы надо сменить статус.
      update exp$orders set status = '3' where id = vMarginOrder.id;
    end if;
  end if;
  --
  vResult:= true;
  --
  insert into exp$files(order_id,file_name,file_text)
    values(pOrderId,vFileName,vFileText);
  update exp$orders set
      note = note||GenText('Экспортирован %1 в файл %2',to_char(sysdate,'dd/mm/yy hh24:mi:ss'),vFileName)
    where id = pOrderId;
  --
  tpipe.send('sdm_order_export end');

  return vResult;
exception
  when others then
    utl_file.put_line(vFile,convert(sqlerrm,cNlsLang));
    utl_file.fclose(vFile);
    return false;
end SDM_ORDER_EXPORT;
/

-- Grants for Function
GRANT EXECUTE ON sdm_order_export TO bookkeeper
/
GRANT EXECUTE ON sdm_order_export TO uc_adm
/
GRANT EXECUTE ON sdm_order_export TO bookfactory
/
GRANT EXECUTE ON sdm_order_export TO allfromgc
/
GRANT EXECUTE ON sdm_order_export TO oper_role
/


-- End of DDL Script for Function GC.SDM_ORDER_EXPORT
