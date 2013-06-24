-- @tag: chart_type_skonto
-- @description: SKR: Gewährte Skonti sind Erlöskonten, erhaltene Skonti sind Aufwandskonten
-- @depends: release_2_7_0

UPDATE chart SET category = 'I' WHERE accno = '8731' AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR03EU');
UPDATE chart SET category = 'I' WHERE accno = '8735' AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR03EU');
UPDATE chart SET category = 'E' WHERE accno = '3731' AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR03EU');
UPDATE chart SET category = 'E' WHERE accno = '3735' AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR03EU');

UPDATE chart SET category = 'I' WHERE accno = '4731' AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR04EU');
UPDATE chart SET category = 'I' WHERE accno = '4735' AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR04EU');
UPDATE chart SET category = 'I' WHERE accno = '4736' AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR04EU');
UPDATE chart SET category = 'E' WHERE accno = '5731' AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR04EU');
UPDATE chart SET category = 'E' WHERE accno = '5735' AND EXISTS (SELECT * FROM defaults WHERE coa = 'Germany-DATEV-SKR04EU');
