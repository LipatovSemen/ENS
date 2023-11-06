Sub main(param)

 FUND_ID= Param.Vars("ID").Value()
 OCHERED= Param.Vars("POSITION").Value()

 #sql_smt
 {

select to_char(trunc(f.date_b),'dd.mm.yyyy')
      ,to_char(trunc(f.date_b),'dd.mm.yyyy')
      ,case when f.initiator = 'FNS' then f.resolution else to_char(round(dbms_random.value(1000,9999)),'9999') end rnd_num 
      ,case when f.group_id is null then gc.digwords.getstr(f.sum_limit) 
       else  (select gc.digwords.getstr(gg.summ) from gc.funds_block_group gg where gg.id = f.group_id) end sumtxt
      ,case when f.group_id is null then trim(replace(to_char(f.sum_limit,'99999999.99'),'.','-')) 
       else (select trim(replace(to_char(gg.summ,'99999999.99'),'.','-')) from gc.funds_block_group gg where gg.id = f.group_id)
       end sum2
      --,trim(replace(to_char(f.sum_limit,'99999999.99'),'.','-')) sum2 
      ,v.inn_pl
      ,nvl(v.kpp_pl,'0')
      ,s.name||'//'||gc.REp_subj.get_address(s.id,'0','1','','1','1','1','1','1','','д.','корп.','кв.')||'//' PL
      ,gc.report.getbankname(decode(d.filial,'M','382',d.filial)) BANK
      ,gc.rep_subj.get_bank_bik(d.filial) bik
      ,(select KS from gc.banki where bank_id=decode(d.filial,'M','382',d.filial)) KS
      ,(select 'г. '||replace(sp.name,' Г','')   
 from gc.ADDRESS a,gc.sprav sp 
 where sp.id(+) = decode(a.city_id,null,a.region_id,a.city_id)
 and a.subj_id =decode(d.filial,'M','382',d.filial) and rownum=1) city  
      ,rd.bank bank_pol
      ,'г. '||replace(rd.gorod,' Г','') city_pol
      ,rd.mfo_rkc bik_pol
      ,rd.ks ks_pol
      ,rd.acc acc_pol
      ,rd.idn inn_pol
      ,rd.kpp kpp_pol
      ,rd.name name_pol
      ,supplier_bill_id kod22
      ,v.region_code oktmo
      --,'Взыск.по исп.док.от '|| to_char(f.date_r,'dd/mm/yyyy')||' N '||f.resolution||'.Исп.пр-во от '||to_char(f.id_date,'dd/mm/yyyy')||' N '||f.id_ip_num||'.В пользу взыск.'||f.comments NPLAT
      ,case when f.initiator = 'FNS' 
             then f.comments 
             else 'Взыск.по исп.док.от '|| to_char(f.date_r,'dd/mm/yyyy')||' N '||f.resolution||'.Исп.пр-во от '||to_char(f.id_date,'dd/mm/yyyy')||' N '||f.id_ip_num||'.В пользу взыск.'||f.comments end NPLAT
      ,case when f.initiator = 'FNS' then '|'||v.status_id||'|' else '|31|' end status_id  
      ,case when f.initiator = 'FNS' then f.reserve_number else '' end reserve_number
      ,nvl(gc.sprav_id2name(v.kbk_id),0) kbk
      ,nvl(v.period_str,0)
      ,nvl(to_char(v.doc_period_date,'dd.mm.yyyy'),0)
      ,nvl(v.doc_num,0)
      ,nvl(v.base_id,0) 

into :date_bb,:date_bb1,:rnd_num, :sumtxt, :sum2, :inn_pl, :kpp_pl, :pl, :bank, :bik, :ks, :city, :bank_pol, :city_pol, :bik_pol, :ks_pol, :acc_pol, :inn_pol, :kpp_pol, :name_pol, :kod22, :oktmo, :nplat, :status_id, :reserve_number, :kbk, :period_107, :period_109, :docnum_108, :osn_106
           from gc.funds_block f
               ,gc.doc$nal$vw_to v
               ,gc.dog d
               ,gc.subj s
               ,gc.rekv_doc rd
 where 1=1
   and f.OBJID = :FUND_ID
   and f.dog_id = d.objid
   and d.subj_id = s.id
   and f.rekv_nal = v.uno(+)
   and f.rekv = rd.uno(+);
}


   Param.Vars().Add("date_bb").SetValue(date_bb)
   Param.Vars().Add("date_bb1").SetValue(date_bb1)
   Param.Vars().Add("rnd_num").SetValue(rnd_num)
   Param.Vars().Add("sumtxt").SetValue(sumtxt)
   Param.Vars().Add("sum2").SetValue(sum2)
   Param.Vars().Add("inn_pl").SetValue(inn_pl)
   Param.Vars().Add("kpp_pl").SetValue(kpp_pl)
   Param.Vars().Add("pl").SetValue(pl)
   Param.Vars().Add("bank").SetValue(bank)
   Param.Vars().Add("bik").SetValue(bik)
   Param.Vars().Add("ks").SetValue(ks)
   Param.Vars().Add("city").SetValue(city)
   Param.Vars().Add("bank_pol").SetValue(bank_pol)
   Param.Vars().Add("city_pol").SetValue(city_pol)
   Param.Vars().Add("bik_pol").SetValue(bik_pol)
   Param.Vars().Add("ks_pol").SetValue(ks_pol)
   Param.Vars().Add("acc_pol").SetValue(acc_pol)
   Param.Vars().Add("inn_pol").SetValue(inn_pol)
   Param.Vars().Add("kpp_pol").SetValue(kpp_pol)
   Param.Vars().Add("name_pol").SetValue(name_pol)
   Param.Vars().Add("22").SetValue(kod22)
   Param.Vars().Add("oktmo").SetValue(oktmo)
   Param.Vars().Add("nplat").SetValue(nplat)
   Param.Vars().Add("77").SetValue(OCHERED)
   Param.Vars().Add("K").SetValue(status_id)
   Param.Vars().Add("RN").SetValue(reserve_number)
   Param.Vars().Add("KBK").SetValue(kbk)
   Param.Vars().Add("PRD_107").SetValue(period_107)
   Param.Vars().Add("PRD_109").SetValue(period_109)
   Param.Vars().Add("docnum_108").SetValue(docnum_108)
   Param.Vars().Add("106").SetValue(osn_106)


end sub
