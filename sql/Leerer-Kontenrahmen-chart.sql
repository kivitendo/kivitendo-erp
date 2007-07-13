-- Minimal Chart of Accounts

INSERT INTO chart (
  id,           accno,           description,         charttype,     category,

  link, -- create links to all forms as default
  
  gifi_accno,  taxkey_id,       pos_ustva,            pos_bwa,       pos_bilanz,  
  pos_eur,     datevautomatik,  new_chart_id,         valid_from

) VALUES (

  0,           '0',             'Nicht zugeordnet',  'A',           'A',
  'AR:AP:IC:AR_amount:AR_paid:AP_amount:AP_paid:IC_sale:IC_cogs:IC_income:IC_expense',
  '',          0,               0 ,                   0,             0,          
  0,           FALSE,           0 ,                   now()  
);

-- Minimal Tax-o-matic Configuration

INSERT INTO tax (
        id,   chart_id,  rate,  taxnumber,  taxkey,  taxdescription
)  VALUES  (
        '0',  '0',       '0',   '0',        '0',     'ohne Steuerautomatik');


INSERT INTO taxkeys (
        id, chart_id, tax_id, taxkey_id, pos_ustva, startdate
)  VALUES  (
        0,  0,        0,      0,         0,         '1970-01-01'
);

DELETE FROM tax_zones;

INSERT INTO tax_zones (
        id,  description
)  VALUES  (
         0,  'keiner'
);


-- Minimal buchungsgruppen
INSERT INTO buchungsgruppen (
        id,                  description,         inventory_accno_id,  
        income_accno_id_0,   expense_accno_id_0,  income_accno_id_1, 
        expense_accno_id_1,  income_accno_id_2,   expense_accno_id_2, 
        income_accno_id_3,   expense_accno_id_3
)  VALUES   (
        0,                  'keine',              0, 
        0,                   0,                   0, 
        0,                   0,                   0, 
        0,                   0
);

-- Minimal

INSERT INTO customer (
             id,  name
)  VALUES  (  0,  ' keiner');

INSERT INTO vendor (
             id,  name
)  VALUES  (  0,  ' keiner');



-- Minimal defaults

update defaults set 
  inventory_accno_id =  0, 
  income_accno_id    =  0, 
  expense_accno_id   =  0, 
  fxgain_accno_id    =  0, 
  fxloss_accno_id    =  0, 
  invnumber          = '1', 
  sonumber           = '1', 
  ponumber           = '1', 
  sqnumber           = '1',
  rfqnumber          = '1',
  customernumber     = '1',
  vendornumber       = '1',
  articlenumber      = '1',
  servicenumber      = '1',
  rmanumber          = '1',
  cnnumber           = '1',
  coa                = 'Leerer-Kontenrahmen',
  curr               = 'EUR:USD', 
  weightunit         = 'kg';

                                                    