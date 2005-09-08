-- Updatescript von Version 1.02/1.03 auf 2.00
-- H.Lindemann Lx-System GbR
-- info@lx-system.de
-- Version: 1.0.0
BEGIN;
LOCK TABLE gl IN ACCESS EXCLUSIVE MODE;
LOCK TABLE ar IN ACCESS EXCLUSIVE MODE;
LOCK TABLE ap IN ACCESS EXCLUSIVE MODE;

CREATE SEQUENCE glid start 1 increment 1 maxvalue 9223372036854775807 minvalue 1 cache 1;

CREATE FUNCTION _glid()
RETURNS text
AS 'DECLARE lv record;
BEGIN
SELECT INTO lv last_value from id;
execute ''SELECT pg_catalog.setval(''''glid'''', '' || lv.last_value || '' , true)'';
return cast(lv.last_value as text);
END;'
LANGUAGE 'plpgsql';
select _glid();
drop function _glid();

--execute ''CREATE SEQUENCE glid start '' || lv.last_value || ''increment 1 maxvalue 9223372036854775807 minvalue 1 cache 1'';
--update glid set last_value = (select last_value from id);

\echo acc_trans
ALTER TABLE acc_trans ADD COLUMN gldate date;
ALTER TABLE acc_trans ALTER COLUMN gldate SET DEFAULT date('now'::text);

\echo gl
ALTER TABLE gl ALTER COLUMN id SET DEFAULT nextval('glid'::text);
ALTER TABLE gl ADD COLUMN gldate date;
ALTER TABLE gl ALTER COLUMN gldate SET DEFAULT date('now'::text);
ALTER TABLE gl ADD COLUMN taxincluded boolean;

\echo ar
ALTER TABLE ar ALTER COLUMN id SET DEFAULT nextval('glid'::text);
ALTER TABLE ar ADD COLUMN gldate date;
ALTER TABLE ar ALTER COLUMN gldate SET DEFAULT date('now'::text);

\echo ap
ALTER TABLE ap ALTER COLUMN id SET DEFAULT nextval('glid'::text);
ALTER TABLE ap ADD COLUMN gldate date;
ALTER TABLE ap ALTER COLUMN gldate SET DEFAULT date('now'::text);

\echo parts
ALTER TABLE parts ADD COLUMN shop boolean;
ALTER TABLE parts ALTER COLUMN shop SET DEFAULT false;

update defaults set version = '2.0.0';


END;

\echo idexes
CREATE INDEX acc_trans_trans_id_key ON acc_trans USING btree (trans_id);

CREATE INDEX acc_trans_chart_id_key ON acc_trans USING btree (chart_id);

CREATE INDEX acc_trans_transdate_key ON acc_trans USING btree (transdate);

CREATE INDEX acc_trans_source_key ON acc_trans USING btree (lower(source));

CREATE INDEX ap_id_key ON ap USING btree (id);

CREATE INDEX ap_transdate_key ON ap USING btree (transdate);

CREATE INDEX ap_invnumber_key ON ap USING btree (lower(invnumber));

CREATE INDEX ap_ordnumber_key ON ap USING btree (lower(ordnumber));

CREATE INDEX ap_vendor_id_key ON ap USING btree (vendor_id);

CREATE INDEX ap_employee_id_key ON ap USING btree (employee_id);

CREATE INDEX ar_id_key ON ar USING btree (id);

CREATE INDEX ar_transdate_key ON ar USING btree (transdate);

CREATE INDEX ar_invnumber_key ON ar USING btree (lower(invnumber));

CREATE INDEX ar_ordnumber_key ON ar USING btree (lower(ordnumber));

CREATE INDEX ar_customer_id_key ON ar USING btree (customer_id);

CREATE INDEX ar_employee_id_key ON ar USING btree (employee_id);

CREATE INDEX assembly_id_key ON assembly USING btree (id);

CREATE INDEX chart_id_key ON chart USING btree (id);

CREATE UNIQUE INDEX chart_accno_key ON chart USING btree (accno);

CREATE INDEX chart_category_key ON chart USING btree (category);

CREATE INDEX chart_link_key ON chart USING btree (link);

CREATE INDEX chart_gifi_accno_key ON chart USING btree (gifi_accno);

CREATE INDEX customer_id_key ON customer USING btree (id);

CREATE INDEX customer_customer_id_key ON customertax USING btree (customer_id);

CREATE INDEX customer_customernumber_key ON customer USING btree (customernumber);

CREATE INDEX customer_name_key ON customer USING btree (name);

CREATE INDEX customer_contact_key ON customer USING btree (contact);

CREATE INDEX employee_id_key ON employee USING btree (id);

CREATE UNIQUE INDEX employee_login_key ON employee USING btree (login);

CREATE INDEX employee_name_key ON employee USING btree (name);

CREATE INDEX exchangerate_ct_key ON exchangerate USING btree (curr, transdate);

CREATE UNIQUE INDEX gifi_accno_key ON gifi USING btree (accno);

CREATE INDEX gl_id_key ON gl USING btree (id);

CREATE INDEX gl_transdate_key ON gl USING btree (transdate);

CREATE INDEX gl_reference_key ON gl USING btree (lower(reference));

CREATE INDEX gl_description_key ON gl USING btree (lower(description));

CREATE INDEX gl_employee_id_key ON gl USING btree (employee_id);

CREATE INDEX invoice_id_key ON invoice USING btree (id);

CREATE INDEX invoice_trans_id_key ON invoice USING btree (trans_id);

CREATE INDEX oe_id_key ON oe USING btree (id);

CREATE INDEX oe_transdate_key ON oe USING btree (transdate);

CREATE INDEX oe_ordnumber_key ON oe USING btree (lower(ordnumber));

CREATE INDEX oe_employee_id_key ON oe USING btree (employee_id);

CREATE INDEX orderitems_trans_id_key ON orderitems USING btree (trans_id);

CREATE INDEX parts_id_key ON parts USING btree (id);

CREATE INDEX parts_partnumber_key ON parts USING btree (lower(partnumber));

CREATE INDEX parts_description_key ON parts USING btree (lower(description));

CREATE INDEX partstax_parts_id_key ON partstax USING btree (parts_id);

CREATE INDEX vendor_id_key ON vendor USING btree (id);

CREATE INDEX vendor_name_key ON vendor USING btree (name);

CREATE INDEX vendor_vendornumber_key ON vendor USING btree (vendornumber);

CREATE INDEX vendor_contact_key ON vendor USING btree (contact);

CREATE INDEX vendortax_vendor_id_key ON vendortax USING btree (vendor_id);

CREATE INDEX shipto_trans_id_key ON shipto USING btree (trans_id);

CREATE INDEX project_id_key ON project USING btree (id);

CREATE INDEX ar_quonumber_key ON ar USING btree (lower(quonumber));

CREATE INDEX ap_quonumber_key ON ap USING btree (lower(quonumber));

CREATE INDEX makemodel_parts_id_key ON makemodel USING btree (parts_id);

CREATE INDEX makemodel_make_key ON makemodel USING btree (lower(make));

CREATE INDEX makemodel_model_key ON makemodel USING btree (lower(model));

CREATE INDEX status_trans_id_key ON status USING btree (trans_id);

CREATE INDEX department_id_key ON department USING btree (id);

CREATE INDEX orderitems_id_key ON orderitems USING btree (id);

CREATE INDEX contact_name_key ON contacts USING btree (cp_name);

\echo functions
SET check_function_bodies = false;

CREATE FUNCTION del_yearend() RETURNS "trigger"
    AS '
begin
  delete from yearend where trans_id = old.id;
  return NULL;
end;
'
LANGUAGE plpgsql;

CREATE FUNCTION del_department() RETURNS "trigger"
    AS '
begin
  delete from dpt_trans where trans_id = old.id;
  return NULL;
end;
'
LANGUAGE plpgsql;

CREATE FUNCTION del_customer() RETURNS "trigger"
    AS '
begin
  delete from shipto where trans_id = old.id;
  delete from customertax where customer_id = old.id;
  return NULL;
end;
'
LANGUAGE plpgsql;

CREATE FUNCTION del_vendor() RETURNS "trigger"
    AS '
begin
  delete from shipto where trans_id = old.id;
  delete from vendortax where vendor_id = old.id;
  return NULL;
end;
'
LANGUAGE plpgsql;

CREATE FUNCTION del_exchangerate() RETURNS "trigger"
    AS '
declare
  t_transdate date;
  t_curr char(3);
  t_id int;
  d_curr text;
begin
  select into d_curr substr(curr,1,3) from defaults;
  if TG_RELNAME = ''ar'' then
    select into t_curr, t_transdate curr, transdate from ar where id = old.id;
  end if;
  if TG_RELNAME = ''ap'' then
    select into t_curr, t_transdate curr, transdate from ap where id = old.id;
  end if;
  if TG_RELNAME = ''oe'' then
    select into t_curr, t_transdate curr, transdate from oe where id = old.id;
  end if;
  if d_curr != t_curr then
    select into t_id a.id from acc_trans ac
    join ar a on (a.id = ac.trans_id)
    where a.curr = t_curr
    and ac.transdate = t_transdate
    except select a.id from ar a where a.id = old.id
    union
    select a.id from acc_trans ac
    join ap a on (a.id = ac.trans_id)
    where a.curr = t_curr
    and ac.transdate = t_transdate
    except select a.id from ap a where a.id = old.id
    union
    select o.id from oe o
    where o.curr = t_curr
    and o.transdate = t_transdate
    except select o.id from oe o where o.id = old.id;
    if not found then
      delete from exchangerate where curr = t_curr and transdate = t_transdate;
    end if;
  end if;
return old;
end;
'
LANGUAGE plpgsql;

CREATE FUNCTION check_inventory() RETURNS "trigger"
    AS '
declare
  itemid int;
  row_data inventory%rowtype;
begin
  if not old.quotation then
    for row_data in select * from inventory where oe_id = old.id loop
      select into itemid id from orderitems where trans_id = old.id and id = row_data.orderitems_id;
      if itemid is null then
	delete from inventory where oe_id = old.id and orderitems_id = row_data.orderitems_id;
      end if;
    end loop;
  end if;
  return old;
end;
'
LANGUAGE plpgsql;

CREATE FUNCTION check_department() RETURNS "trigger"
    AS '
declare
  dpt_id int;
begin
  if new.department_id = 0 then
    delete from dpt_trans where trans_id = new.id;
    return NULL;
  end if;
  select into dpt_id trans_id from dpt_trans where trans_id = new.id;
  if dpt_id > 0 then
    update dpt_trans set department_id = new.department_id where trans_id = dpt_id;
  else
    insert into dpt_trans (trans_id, department_id) values (new.id, new.department_id);
  end if;
return NULL;
end;
'
LANGUAGE plpgsql;

\echo trigger
CREATE TRIGGER del_yearend
    AFTER DELETE ON gl
    FOR EACH ROW
    EXECUTE PROCEDURE del_yearend();

CREATE TRIGGER del_department
    AFTER DELETE ON ar
    FOR EACH ROW
    EXECUTE PROCEDURE del_department();

CREATE TRIGGER del_department
    AFTER DELETE ON ap
    FOR EACH ROW
    EXECUTE PROCEDURE del_department();

CREATE TRIGGER del_department
    AFTER DELETE ON gl
    FOR EACH ROW
    EXECUTE PROCEDURE del_department();

CREATE TRIGGER del_department
    AFTER DELETE ON oe
    FOR EACH ROW
    EXECUTE PROCEDURE del_department();

CREATE TRIGGER del_customer
    AFTER DELETE ON customer
    FOR EACH ROW
    EXECUTE PROCEDURE del_customer();

CREATE TRIGGER del_vendor
    AFTER DELETE ON vendor
    FOR EACH ROW
    EXECUTE PROCEDURE del_vendor();

CREATE TRIGGER del_exchangerate
    BEFORE DELETE ON ar
    FOR EACH ROW
    EXECUTE PROCEDURE del_exchangerate();

CREATE TRIGGER del_exchangerate
    BEFORE DELETE ON ap
    FOR EACH ROW
    EXECUTE PROCEDURE del_exchangerate();

CREATE TRIGGER del_exchangerate
    BEFORE DELETE ON oe
    FOR EACH ROW
    EXECUTE PROCEDURE del_exchangerate();

CREATE TRIGGER check_inventory
    AFTER UPDATE ON oe
    FOR EACH ROW
    EXECUTE PROCEDURE check_inventory();

CREATE TRIGGER check_department
    AFTER INSERT OR UPDATE ON ar
    FOR EACH ROW
    EXECUTE PROCEDURE check_department();

CREATE TRIGGER check_department
    AFTER INSERT OR UPDATE ON ap
    FOR EACH ROW
    EXECUTE PROCEDURE check_department();

CREATE TRIGGER check_department
    AFTER INSERT OR UPDATE ON gl
    FOR EACH ROW
    EXECUTE PROCEDURE check_department();

CREATE TRIGGER check_department
    AFTER INSERT OR UPDATE ON oe
    FOR EACH ROW
    EXECUTE PROCEDURE check_department();
