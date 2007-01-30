-- changes on system tables
-- TODO Make me Update2
ALTER TABLE tax ALTER COLUMN taxkey DROP NOT NULL;

-- Minimal COA

INSERT INTO chart (
  accno,       description,        charttype,     category,    link,    
  gifi_accno,  taxkey_id,          pos_ustva,     pos_bwa,     pos_bilanz,  
  pos_eur,     datevautomatik,     new_chart_id,  valid_from  
) VALUES (
  ' ',         'Nicht zugeordnet'  'A',           '',          '',
  '',          0,                  0,             0,           0,
  0,           FALSE,              0,             now()  
);

-- Minimal Tax Konfiguration

INSERT INTO tax 
       (chart_id,  rate,  taxnumber,  taxkey,  taxdescription) 
VALUES ('0',       '0',   '0',         '0',     'ohne Steuerautomatik');



















