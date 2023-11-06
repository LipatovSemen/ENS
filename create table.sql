-- Start of DDL Script for Table GC.SDM$440P_ENS_PROTOCOL
-- Generated 21.09.2023 11:31:22 from GC@BANKNULL

CREATE TABLE sdm$440p_ens_protocol
    (event_date                     DATE,
    dogid                          VARCHAR2(15 BYTE),
    uuid                           VARCHAR2(50 BYTE),
    type_oper                      VARCHAR2(50 BYTE),
    status                         VARCHAR2(50 BYTE),
    text                           VARCHAR2(2000 BYTE))
  SEGMENT CREATION IMMEDIATE
  PCTFREE     10
  INITRANS    1
  MAXTRANS    255
  TABLESPACE  users
  STORAGE   (
    INITIAL     65536
    NEXT        1048576
    MINEXTENTS  1
    MAXEXTENTS  2147483645
  )
  NOCACHE
  MONITORING
  NOPARALLEL
  LOGGING
/





-- End of DDL Script for Table GC.SDM$440P_ENS_PROTOCOL
