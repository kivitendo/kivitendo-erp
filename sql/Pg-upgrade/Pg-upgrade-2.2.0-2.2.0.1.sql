--
-- Fehler im SKR03 4250 Reinigung und 4610 Werbekosten
--
UPDATE chart SET pos_bwa=11  WHERE accno IN ('4250');
UPDATE chart SET pos_bilanz=null  WHERE accno IN ('4250');

UPDATE chart SET pos_bwa=15  WHERE accno IN ('4610');
UPDATE chart SET pos_bilanz=null  WHERE accno IN ('4610');
