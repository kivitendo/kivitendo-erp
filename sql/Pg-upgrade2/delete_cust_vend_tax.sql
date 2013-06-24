-- @tag: delete_cust_vend_tax
-- @description: Alte Tabellen löschen
-- @depends: delete_customertax_vendortax_partstax

CREATE OR REPLACE FUNCTION del_customer() RETURNS "trigger" AS
  'BEGIN
     DELETE FROM shipto WHERE trans_id = old.id;
     RETURN NULL;
   END;' LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION del_vendor() RETURNS "trigger" AS
  'BEGIN
    DELETE FROM shipto WHERE trans_id = old.id;
    RETURN NULL;
  END;' LANGUAGE plpgsql;

