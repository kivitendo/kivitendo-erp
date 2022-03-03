-- @tag: convert_real_qty
-- @description: Spaltentyp auf Numeric anstelle von Real für qty
-- @depends: release_3_6_0
ALTER TABLE orderitems ALTER column qty type numeric(25,5);
ALTER TABLE invoice    ALTER column qty type numeric(25,5);


