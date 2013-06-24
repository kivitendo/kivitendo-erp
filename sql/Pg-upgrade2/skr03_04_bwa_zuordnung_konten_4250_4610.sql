-- @tag: skr03_04_bwa_zuordnung_konten_4250_4610
-- @description: Fehler in der BWA-Zuordnung
-- @depends: release_2_6_1

-- SKR03
UPDATE chart
  SET pos_bwa = 11, pos_bilanz = NULL
  WHERE (accno = '4250')
    AND ((SELECT coa FROM defaults LIMIT 1) = 'Germany-DATEV-SKR03EU');

UPDATE chart
  SET pos_bwa = 15, pos_bilanz = NULL
  WHERE (accno = '4610')
    AND ((SELECT coa FROM defaults LIMIT 1) = 'Germany-DATEV-SKR03EU');

-- SKR04
UPDATE chart
  SET pos_bwa = 11, pos_bilanz = NULL
  WHERE (accno = '6330')
    AND ((SELECT coa FROM defaults LIMIT 1) = 'Germany-DATEV-SKR04EU');

UPDATE chart
  SET pos_bwa = 15, pos_bilanz = NULL
  WHERE (accno = '6600')
    AND ((SELECT coa FROM defaults LIMIT 1) = 'Germany-DATEV-SKR04EU');

