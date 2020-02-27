--
-- PostgreSQL database dump
--

--
-- Name: id; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE id
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1;


--
-- Name: glid; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE glid
    START WITH 1
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1;


--
-- Name: gl; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE gl (
    id integer DEFAULT nextval('glid'::text) NOT NULL,
    reference text,
    description text,
    transdate date DEFAULT date('now'::text),
    gldate date DEFAULT date('now'::text),
    employee_id integer,
    notes text,
    department_id integer DEFAULT 0,
    taxincluded boolean,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    "type" text
);


--
-- Name: chart; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE chart (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    accno text NOT NULL,
    description text,
    charttype character(1) DEFAULT 'A'::bpchar,
    category character(1),
    link text,
    gifi_accno text,
    taxkey_id integer,
    pos_ustva integer,
    pos_bwa integer,
    pos_bilanz integer,
    pos_eur integer,
    datevautomatik boolean DEFAULT false,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    new_chart_id integer,
    valid_from date
);


--
-- Name: datev; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE datev (
    beraternr character varying(7),
    beratername character varying(9),
    mandantennr character varying(5),
    dfvkz character varying(2),
    datentraegernr character varying(3),
    abrechnungsnr character varying(6),
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: gifi; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE gifi (
    accno text,
    description text
);


--
-- Name: parts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE parts (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    partnumber text NOT NULL,
    description text,
    listprice numeric(15,5),
    sellprice numeric(15,5),
    lastcost numeric(15,5),
    priceupdate date DEFAULT date('now'::text),
    weight real,
    onhand real DEFAULT 0,
    notes text,
    makemodel boolean DEFAULT false,
    assembly boolean DEFAULT false,
    alternate boolean DEFAULT false,
    rop real,
    inventory_accno_id integer,
    income_accno_id integer,
    expense_accno_id integer,
    bin text,
    shop boolean DEFAULT false,
    obsolete boolean DEFAULT false,
    bom boolean DEFAULT false,
    image text,
    drawing text,
    microfiche text,
    partsgroup_id integer,
    ve integer,
    gv numeric(15,5),
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    unit character varying(20),
    formel text,
    not_discountable boolean DEFAULT false,
    buchungsgruppen_id integer,
    payment_id integer
);


--
-- Name: defaults; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "defaults" (
    inventory_accno_id integer,
    income_accno_id integer,
    expense_accno_id integer,
    fxgain_accno_id integer,
    fxloss_accno_id integer,
    invnumber text,
    sonumber text,
    yearend character varying(5),
    weightunit character varying(5),
    businessnumber text,
    "version" character varying(8),
    curr text,
    closedto date,
    revtrans boolean DEFAULT false,
    ponumber text,
    sqnumber text,
    rfqnumber text,
    customernumber text,
    vendornumber text,
    audittrail boolean DEFAULT false,
    articlenumber text,
    servicenumber text,
    coa text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    rmanumber text,
    cnnumber text,
    accounting_method text,
    inventory_system text,
    profit_determination text
);


--
-- Name: audittrail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE audittrail (
    trans_id integer,
    tablename text,
    reference text,
    formname text,
    "action" text,
    transdate timestamp without time zone DEFAULT ('now'::text)::timestamp(6) with time zone,
    employee_id integer
);


--
-- Name: acc_trans; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE acc_trans (
    trans_id integer,
    chart_id integer,
    amount numeric(15,5),
    transdate date DEFAULT date('now'::text),
    gldate date DEFAULT date('now'::text),
    source text,
    cleared boolean DEFAULT false,
    fx_transaction boolean DEFAULT false,
    project_id integer,
    memo text,
    taxkey integer,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: invoice; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE invoice (
    id integer DEFAULT nextval('invoiceid'::text) NOT NULL,
    trans_id integer,
    parts_id integer,
    description text,
    qty real,
    allocated real,
    sellprice numeric(15,5),
    fxsellprice numeric(15,5),
    discount real,
    assemblyitem boolean DEFAULT false,
    project_id integer,
    deliverydate date,
    serialnumber text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    pricegroup_id integer,
    ordnumber text,
    transdate text,
    cusordnumber text,
    unit character varying(20),
    base_qty real,
    subtotal boolean DEFAULT false,
    longdescription text
);


--
-- Name: vendor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE vendor (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    name character varying(75) NOT NULL,
    department_1 character varying(75),
    department_2 character varying(75),
    street character varying(75),
    zipcode character varying(10),
    city character varying(75),
    country character varying(75),
    contact character varying(75),
    phone character varying(30),
    fax character varying(30),
    homepage text,
    email text,
    notes text,
    terms smallint DEFAULT 0,
    taxincluded boolean,
    vendornumber text,
    cc text,
    bcc text,
    gifi_accno text,
    business_id integer,
    taxnumber text,
    sic_code text,
    discount real,
    creditlimit numeric(15,5),
    account_number character varying(15),
    bank_code character varying(10),
    bank text,
    "language" character varying(5),
    datevexport integer,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    obsolete boolean DEFAULT false,
    ustid character varying(12),
    username character varying(50),
    user_password character varying(12),
    salesman_id integer,
    v_customer_id text,
    language_id integer,
    payment_id integer,
    taxzone_id integer,
    greeting text
);


--
-- Name: customer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE customer (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    name character varying(75) NOT NULL,
    department_1 character varying(75),
    department_2 character varying(75),
    street character varying(75),
    zipcode character varying(10),
    city character varying(75),
    country character varying(75),
    contact character varying(75),
    phone character varying(30),
    fax character varying(30),
    homepage text,
    email text,
    notes text,
    discount real,
    taxincluded boolean,
    creditlimit numeric(15,5) DEFAULT 0,
    terms smallint DEFAULT 0,
    customernumber text,
    cc text,
    bcc text,
    business_id integer,
    taxnumber text,
    sic_code text,
    account_number character varying(15),
    bank_code character varying(10),
    bank text,
    "language" character varying(5),
    datevexport integer,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    obsolete boolean DEFAULT false,
    ustid character varying(12),
    username character varying(50),
    user_password text,
    salesman_id integer,
    c_vendor_id text,
    klass integer DEFAULT 0,
    language_id integer,
    payment_id integer,
    taxzone_id integer,
    greeting text
);


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE contacts (
    cp_id integer DEFAULT nextval('id'::text) NOT NULL,
    cp_cv_id integer,
    cp_greeting character varying(75),
    cp_title character varying(75),
    cp_givenname character varying(75),
    cp_name character varying(75),
    cp_email text,
    cp_phone1 character varying(75),
    cp_phone2 character varying(75),
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    cp_fax text,
    cp_mobile1 text,
    cp_mobile2 text,
    cp_satphone text,
    cp_satfax text,
    cp_project text,
    cp_privatphone text,
    cp_privatemail text,
    cp_birthday text,
    cp_abteilung text
);


--
-- Name: assembly; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE assembly (
    id integer,
    parts_id integer,
    qty real,
    bom boolean,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: ar; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE ar (
    id integer DEFAULT nextval('glid'::text) NOT NULL,
    invnumber text NOT NULL,
    transdate date DEFAULT date('now'::text),
    gldate date DEFAULT date('now'::text),
    customer_id integer,
    taxincluded boolean,
    amount numeric(15,5),
    netamount numeric(15,5),
    paid numeric(15,5),
    datepaid date,
    duedate date,
    deliverydate date,
    invoice boolean DEFAULT false,
    shippingpoint text,
    terms smallint DEFAULT 0,
    notes text,
    curr character(3),
    ordnumber text,
    employee_id integer,
    quonumber text,
    cusordnumber text,
    intnotes text,
    department_id integer DEFAULT 0,
    shipvia text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    cp_id integer,
    language_id integer,
    payment_id integer,
    delivery_customer_id integer,
    delivery_vendor_id integer,
    storno boolean DEFAULT false,
    taxzone_id integer,
    shipto_id integer,
    "type" text,
    dunning_id integer
);


--
-- Name: ap; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE ap (
    id integer DEFAULT nextval('glid'::text) NOT NULL,
    invnumber text NOT NULL,
    transdate date DEFAULT date('now'::text),
    gldate date DEFAULT date('now'::text),
    vendor_id integer,
    taxincluded boolean DEFAULT false,
    amount numeric(15,5),
    netamount numeric(15,5),
    paid numeric(15,5),
    datepaid date,
    duedate date,
    invoice boolean DEFAULT false,
    ordnumber text,
    curr character(3),
    notes text,
    employee_id integer,
    quonumber text,
    intnotes text,
    department_id integer DEFAULT 0,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    shipvia text,
    cp_id integer,
    language_id integer,
    payment_id integer,
    storno boolean DEFAULT false,
    taxzone_id integer,
    "type" text
);


--
-- Name: partstax; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE partstax (
    parts_id integer,
    chart_id integer,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: tax; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE tax (
    chart_id integer,
    rate numeric(15,5),
    taxnumber text,
    taxkey integer,
    taxdescription text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    id integer DEFAULT nextval('id'::text)
);


--
-- Name: customertax; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE customertax (
    customer_id integer,
    chart_id integer,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: vendortax; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE vendortax (
    vendor_id integer,
    chart_id integer,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: oe; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE oe (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    ordnumber text NOT NULL,
    transdate date DEFAULT date('now'::text),
    vendor_id integer,
    customer_id integer,
    amount numeric(15,5),
    netamount numeric(15,5),
    reqdate date,
    taxincluded boolean,
    shippingpoint text,
    notes text,
    curr character(3),
    employee_id integer,
    closed boolean DEFAULT false,
    quotation boolean DEFAULT false,
    quonumber text,
    cusordnumber text,
    intnotes text,
    department_id integer DEFAULT 0,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    shipvia text,
    cp_id integer,
    language_id integer,
    payment_id integer,
    delivery_customer_id integer,
    delivery_vendor_id integer,
    taxzone_id integer,
    proforma boolean DEFAULT false,
    shipto_id integer
);


--
-- Name: orderitems; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE orderitems (
    trans_id integer,
    parts_id integer,
    description text,
    qty real,
    sellprice numeric(15,5),
    discount real,
    project_id integer,
    reqdate date,
    ship real,
    serialnumber text,
    id integer DEFAULT nextval('orderitemsid'::text),
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    pricegroup_id integer,
    ordnumber text,
    transdate text,
    cusordnumber text,
    unit character varying(20),
    base_qty real,
    subtotal boolean DEFAULT false,
    longdescription text
);


--
-- Name: exchangerate; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE exchangerate (
    curr character(3),
    transdate date,
    buy numeric(15,5),
    sell numeric(15,5),
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: employee; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE employee (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    login text,
    name character varying(35),
    addr1 character varying(35),
    addr2 character varying(35),
    addr3 character varying(35),
    addr4 character varying(35),
    workphone character varying(20),
    homephone character varying(20),
    startdate date DEFAULT date('now'::text),
    enddate date,
    notes text,
    role text,
    sales boolean DEFAULT true,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: shipto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE shipto (
    trans_id integer,
    shiptoname character varying(75),
    shiptodepartment_1 character varying(75),
    shiptodepartment_2 character varying(75),
    shiptostreet character varying(75),
    shiptozipcode character varying(75),
    shiptocity character varying(75),
    shiptocountry character varying(75),
    shiptocontact character varying(75),
    shiptophone character varying(30),
    shiptofax character varying(30),
    shiptoemail text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    module text,
    shipto_id integer DEFAULT nextval('id'::text)
);


--
-- Name: project; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE project (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    projectnumber text,
    description text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: partsgroup; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE partsgroup (
    id integer DEFAULT nextval('id'::text),
    partsgroup text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: makemodel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE makemodel (
    parts_id integer,
    make text,
    model text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE status (
    trans_id integer,
    formname text,
    printed boolean DEFAULT false,
    emailed boolean DEFAULT false,
    spoolfile text,
    chart_id integer,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: invoiceid; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE invoiceid
    START WITH 1
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1;


--
-- Name: orderitemsid; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orderitemsid
    START WITH 1
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1
    CYCLE;


--
-- Name: warehouse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE warehouse (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    description text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: inventory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE inventory (
    warehouse_id integer,
    parts_id integer,
    oe_id integer,
    orderitems_id integer,
    qty real,
    shippingdate date,
    employee_id integer,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: department; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE department (
    id integer DEFAULT nextval('id'::text),
    description text,
    role character(1) DEFAULT 'P'::bpchar,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: dpt_trans; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE dpt_trans (
    trans_id integer,
    department_id integer,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: business; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE business (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    description text,
    discount real,
    customernumberinit text,
    salesman boolean DEFAULT false,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: sic; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE sic (
    code text,
    sictype character(1),
    description text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: license; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE license (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    parts_id integer,
    customer_id integer,
    "comment" text,
    validuntil date,
    issuedate date DEFAULT date('now'::text),
    quantity integer,
    licensenumber text
);


--
-- Name: licenseinvoice; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE licenseinvoice (
    trans_id integer,
    license_id integer
);


--
-- Name: pricegroup; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE pricegroup (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    pricegroup text NOT NULL
);


--
-- Name: prices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE prices (
    parts_id integer,
    pricegroup_id integer,
    price numeric(15,5)
);


--
-- Name: finanzamt; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE finanzamt (
    fa_land_nr text,
    fa_bufa_nr text,
    fa_name text,
    fa_strasse text,
    fa_plz text,
    fa_ort text,
    fa_telefon text,
    fa_fax text,
    fa_plz_grosskunden text,
    fa_plz_postfach text,
    fa_postfach text,
    fa_blz_1 text,
    fa_kontonummer_1 text,
    fa_bankbezeichnung_1 text,
    fa_blz_2 text,
    fa_kontonummer_2 text,
    fa_bankbezeichnung_2 text,
    fa_oeffnungszeiten text,
    fa_email text,
    fa_internet text
);


--
-- Name: check_department(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION check_department() RETURNS "trigger"
    AS 'declare  dpt_id int;begin  if new.department_id = 0 then    delete from dpt_trans where trans_id = new.id;    return NULL;  end if;  select into dpt_id trans_id from dpt_trans where trans_id = new.id;  if dpt_id > 0 then    update dpt_trans set department_id = new.department_id where trans_id = dpt_id;  else    insert into dpt_trans (trans_id, department_id) values (new.id, new.department_id);  end if;return NULL;end;'
    LANGUAGE plpgsql;


--
-- Name: del_department(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION del_department() RETURNS "trigger"
    AS 'begin  delete from dpt_trans where trans_id = old.id;  return NULL;end;'
    LANGUAGE plpgsql;


--
-- Name: del_customer(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION del_customer() RETURNS "trigger"
    AS 'begin  delete from shipto where trans_id = old.id;  delete from customertax where customer_id = old.id;  return NULL;end;'
    LANGUAGE plpgsql;


--
-- Name: del_vendor(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION del_vendor() RETURNS "trigger"
    AS 'begin  delete from shipto where trans_id = old.id;  delete from vendortax where vendor_id = old.id;  return NULL;end;'
    LANGUAGE plpgsql;


--
-- Name: del_exchangerate(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION del_exchangerate() RETURNS "trigger"
    AS 'declare  t_transdate date;  t_curr char(3);  t_id int;  d_curr text;begin  select into d_curr substr(curr,1,3) from defaults;  if TG_RELNAME = ''ar'' then    select into t_curr, t_transdate curr, transdate from ar where id = old.id;  end if;  if TG_RELNAME = ''ap'' then    select into t_curr, t_transdate curr, transdate from ap where id = old.id;  end if;  if TG_RELNAME = ''oe'' then    select into t_curr, t_transdate curr, transdate from oe where id = old.id;  end if;  if d_curr != t_curr then    select into t_id a.id from acc_trans ac    join ar a on (a.id = ac.trans_id)    where a.curr = t_curr    and ac.transdate = t_transdate    except select a.id from ar a where a.id = old.id    union    select a.id from acc_trans ac    join ap a on (a.id = ac.trans_id)    where a.curr = t_curr    and ac.transdate = t_transdate    except select a.id from ap a where a.id = old.id    union    select o.id from oe o    where o.curr = t_curr    and o.transdate = t_transdate    except select o.id from oe o where o.id = old.id;    if not found then      delete from exchangerate where curr = t_curr and transdate = t_transdate;    end if;  end if;return old;end;'
    LANGUAGE plpgsql;


--
-- Name: check_inventory(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION check_inventory() RETURNS "trigger"
    AS 'declare  itemid int;  row_data inventory%rowtype;begin  if not old.quotation then    for row_data in select * from inventory where oe_id = old.id loop      select into itemid id from orderitems where trans_id = old.id and id = row_data.orderitems_id;      if itemid is null then	delete from inventory where oe_id = old.id and orderitems_id = row_data.orderitems_id;      end if;    end loop;  end if;  return old;end;'
    LANGUAGE plpgsql;


--
-- Name: set_datevexport(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION set_datevexport() RETURNS "trigger"
    AS '    BEGIN        IF OLD.datevexport IS NULL THEN            NEW.datevexport := 1;        END IF;        IF OLD.datevexport = 0 THEN            NEW.datevexport := 2;        END IF;        RETURN NEW;    END;'
    LANGUAGE plpgsql;


--
-- Name: set_mtime(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION set_mtime() RETURNS "trigger"
    AS '    BEGIN        NEW.mtime := ''now'';        RETURN NEW;    END;'
    LANGUAGE plpgsql;


--
-- Name: language; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "language" (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    description text,
    template_code text,
    article_code text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);


--
-- Name: payment_terms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE payment_terms (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    description text,
    description_long text,
    terms_netto integer,
    terms_skonto integer,
    percent_skonto real,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    ranking integer
);


--
-- Name: translation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE translation (
    parts_id integer,
    language_id integer,
    translation text,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    longdescription text
);


--
-- Name: units; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE units (
    name character varying(20) NOT NULL,
    base_unit character varying(20),
    factor numeric(20,5),
    "type" character varying(20) NOT NULL
);


--
-- Name: rma; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE rma (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    rmanumber text NOT NULL,
    transdate date DEFAULT date('now'::text),
    vendor_id integer,
    customer_id integer,
    amount numeric(15,5),
    netamount numeric(15,5),
    reqdate date,
    taxincluded boolean,
    shippingpoint text,
    notes text,
    curr character(3),
    employee_id integer,
    closed boolean DEFAULT false,
    quotation boolean DEFAULT false,
    quonumber text,
    cusrmanumber text,
    intnotes text,
    delivery_customer_id integer,
    delivery_vendor_id integer,
    language_id integer,
    payment_id integer,
    department_id integer DEFAULT 0,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    shipvia text,
    cp_id integer
);


--
-- Name: rmaitems; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE rmaitems (
    trans_id integer,
    parts_id integer,
    description text,
    qty real,
    base_qty real,
    sellprice numeric(15,5),
    discount real,
    project_id integer,
    reqdate date,
    ship real,
    serialnumber text,
    id integer DEFAULT nextval('orderitemsid'::text),
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone,
    pricegroup_id integer,
    rmanumber text,
    transdate text,
    cusrmanumber text,
    unit character varying(20)
);


--
-- Name: printers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE printers (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    printer_description text NOT NULL,
    printer_command text,
    template_code text
);


--
-- Name: tax_zones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE tax_zones (
    id integer,
    description text
);


--
-- Name: buchungsgruppen; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE buchungsgruppen (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    description text,
    inventory_accno_id integer,
    income_accno_id_0 integer,
    expense_accno_id_0 integer,
    income_accno_id_1 integer,
    expense_accno_id_1 integer,
    income_accno_id_2 integer,
    expense_accno_id_2 integer,
    income_accno_id_3 integer,
    expense_accno_id_3 integer
);


--
-- Name: dunning_config; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE dunning_config (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    dunning_level integer,
    dunning_description text,
    active boolean,
    auto boolean,
    email boolean,
    terms integer,
    payment_terms integer,
    fee numeric(15,5),
    interest numeric(15,5),
    email_body text,
    email_subject text,
    email_attachment boolean,
    "template" text
);


--
-- Name: dunning; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE dunning (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    trans_id integer,
    dunning_id integer,
    dunning_level integer,
    transdate date,
    duedate date,
    fee numeric(15,5),
    interest numeric(15,5)
);


--
-- Name: set_priceupdate_parts(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION set_priceupdate_parts() RETURNS "trigger"
    AS '    BEGIN        NEW.priceupdate := ''now'';        RETURN NEW;    END;'
    LANGUAGE plpgsql;


--
-- Name: leads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE leads (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    lead character varying(50)
);


--
-- Name: taxkeys; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE taxkeys (
    id integer DEFAULT nextval('id'::text) NOT NULL,
    chart_id integer,
    tax_id integer,
    taxkey_id integer,
    pos_ustva integer,
    startdate date
);


--
-- Name: defaults; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "defaults" ("version", "curr") VALUES ('2.4.0.0', 'EUR:USD');

--
-- Name: finanzamt; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('10', '1010', 'Saarlouis ', 'Gaswerkweg 25', '66740', 'Saarlouis', '06831/4490', '06831/449397', '', '66714', '1440', '59000000', '59301502', 'BBK SAARBRUECKEN', '59010066', '7761668', 'POSTBANK SAARBRUECKEN', 'Mo,Di,Do 7.30-15.30, Mi 7.30-18,Fr 7.30-12', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('10', '1020', 'Merzig ', 'Am Gaswerk', '66663', 'Merzig', '06861/7030', '06861/703133', '', '66653', '100232', '59000000', '59301502', 'BBK SAARBRUECKEN', '59010066', '7761668', 'POSTBANK SAARBRUECKEN', 'Mo-Do 7.30-15.30,Mi bis 18.00,Fr 7.30-12.00', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('10', '1030', 'Neunkirchen ', 'Uhlandstr.', '66538', 'Neunkirchen', '06821/1090', '06821/109275', '', '66512', '1234', '59000000', '59001508', 'BBK SAARBRUECKEN', '59010066', '2988669', 'POSTBANK SAARBRUECKEN', 'Mo-Do 7.30-15.30,Mi bis 18.00,Fr 07.30-12.00', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('10', '1040', 'Saarbrücken Am Stadtgr ', 'Am Stadtgraben 2-4', '66111', 'Saarbrücken', '0681/30000', '0681/3000329', '', '66009', '100952', '59000000', '59001502', 'BBK SAARBRUECKEN', '59010066', '7766663', 'POSTBANK SAARBRUECKEN', 'Mo,Di,Do 7.30-15.30, Mi 7.30-18,Fr 7.30-12', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('10', '1055', 'Saarbrücken MainzerStr ', 'Mainzer Str.109-111', '66121', 'Saarbrücken', '0681/30000', '0681/3000762', '', '66009', '100944', '59000000', '59001502', 'BBK SAARBRUECKEN', '59010066', '7766663', 'POSTBANK SAARBRUECKEN', 'Mo,Mi,Fr 8.30-12.00, zus. Mi 13.30 - 15.30', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('10', '1060', 'St. Wendel ', 'Marienstr. 27', '66606', 'St. Wendel', '06851/8040', '06851/804189', '', '66592', '1240', '59000000', '59001508', 'BBK SAARBRUECKEN', '59010066', '2988669', 'POSTBANK SAARBRUECKEN', 'Mo-Do 7.30-15.30,Mi bis 18.00,Fr 07.30-12.00', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('10', '1070', 'Sulzbach ', 'Vopeliusstr. 8', '66280', 'Sulzbach', '06897/9082-0', '06897/9082110', '', '66272', '1164', '59000000', '59001502', 'BBK SAARBRUECKEN', '59010066', '7766663', 'POSTBANK SAARBRUECKEN', 'Mo,Mi,Fr 08.30-12.00, zus. Mi 13.30-18.00', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('10', '1075', 'Homburg ', 'Schillerstr. 15', '66424', 'Homburg', '06841/6970', '06841/697199', '', '66406', '1551', '59000000', '59001508', 'BBK SAARBRUECKEN', '59010066', '2988669', 'POSTBANK SAARBRUECKEN', 'Mo-Do 7.30-15.30,Mi bis 18.00,Fr 07.30-12.00', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('10', '1085', 'St. Ingbert ', 'Rentamtstr. 39', '66386', 'St. Ingbert', '06894/984-01', '06894/984159', '', '66364', '1420', '59000000', '59001508', 'BBK SAARBRUECKEN', '59010066', '2988669', 'POSTBANK SAARBRUECKEN', 'Mo-Do 7.30-15.30,Mi bis 18.00,Fr 7.30-12.00', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('10', '1090', 'Völklingen ', 'Marktstr.', '66333', 'Völklingen', '06898/20301', '06898/203133', '', '66304', '101440', '59000000', '59001502', 'BBK SAARBRUECKEN', '59010066', '7766663', 'POSTBANK SAARBRUECKEN', 'Mo-Do 7.30-15.30,Mi bis 18.00,Fr 07.30-12.00', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1113', 'Berlin Charlottenburg', 'Bismarckstraße 48', '10627', 'Berlin', '030 9024-13-0', '030 9024-13-900', '', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'facharlottenburg@berlin.de', 'http://www.berlin.de/ofd');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1114', 'Berlin Kreuzberg', 'Mehringdamm 22', '10961', 'Berlin', '030 9024-14-0', '030 9024-14-900', '10958', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fakreuzberg@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1115', 'Berlin Neukölln', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 'faneukoelln@berlin.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1116', 'Berlin Neukölln', 'Thiemannstr. 1', '12059', 'Berlin', '030 9024-16-0', '030 9024-16-900', '', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'faneukoelln@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1117', 'Berlin Reinickendorf', 'Eichborndamm 208', '13403', 'Berlin', '030 9024-17-0', '030 9024-17-900', '13400', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fareinickendorf@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1118', 'Berlin Schöneberg', 'Bülowstraße 85/88', '10783', 'Berlin', '030/9024-18-0', '030/9024-18-900', '', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Montag und Freitag: 8:00 - 13:00 Uhr Donnerstag: 11:00 - 18:00 Uhr', 'faschoeneberg@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1119', 'Berlin Spandau', 'Nonnendammallee 15-21', '13599', 'Berlin', '030/9024-19-0', '030/9024-19-900', '', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'faspandau@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1120', 'Berlin Steglitz', 'Schloßstr. 58/59', '12165', 'Berlin', '030/9024-20-0', '030/9024-20-900', '', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fasteglitz@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1121', 'Berlin Tempelhof', 'Tempelhofer Damm 234/236', '12099', 'Berlin', '030 9024-21-0', '030 9024-21-900', '12096', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fatempelhof@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1123', 'Berlin Wedding', 'Osloer Straße 37', '13359', 'Berlin', '030 9024-23-0', '030 9024-23-900', '', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fawedding@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1124', 'Berlin Wilmersdorf', 'Blissestr. 5', '10713', 'Berlin', '030/9024-24-0', '030/9024-24-900', '10702', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fawilmersdorf@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1125', 'Berlin Zehlendorf', 'Martin-Buber-Str. 20/21', '14163', 'Berlin', '030 9024-25-0', '030 9024-25-900', '14160', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fazehlendorf@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1127', 'Berlin für Körperschaften I', 'Gerichtstr. 27', '13347', 'Berlin', '030 9024-27-0', '030 9024-27-900', '', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fakoerperschaften1@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1128', 'Berlin Pankow/Weißennsee - nur KFZ-Steuer -', 'Berliner Straße 32', '13089', 'Berlin', '030/4704-0', '030/94704-1777', '13083', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'pankow.weissensee@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1129', 'Berlin für Körperschaften III', 'Volkmarstr. 13', '12099', 'Berlin', '030/70102-0', '030/70102-100', '', '12068', '420844', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fakoeperschaften3@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1130', 'Berlin für Körperschaften IV', 'Magdalenenstr. 25', '10365', 'Berlin', '030 9024-30-0', '030 9024-30-900', '', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fakoeperschaften4@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1131', 'Berlin Friedrichsh./Prenzb.', 'Pappelallee 78/79', '10437', 'Berlin', '030 9024-28-0', '030 9024-28-900', '10431', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fafriedrichshain.prenzlauerberg@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1132', 'Berlin Lichtenb./Hohenschh.', 'Josef-Orlopp-Str. 62', '10365', 'Berlin', '030/5501-0', '030/55012222', '10358', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'falichtenberg.hohenschoenhausen@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1133', 'Berlin Hellersdorf/Marzahn', 'Allee der Kosmonauten 29', '12681', 'Berlin', '030 9024-26-0', '030 9024-26-900', '12677', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fahellersdorf.marzahn@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1134', 'Berlin Mitte/Tiergarten', 'Neue Jakobstr. 6-7', '10179', 'Berlin', '030 9024-22-0', '030 9024-22-900', '', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'famitte.tiergarten@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1135', 'Berlin Pankow/Weißensee', 'Berliner Straße 32', '13089', 'Berlin', '030/4704-0', '030/47041777', '13083', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'pankow.weissensee@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1136', 'Berlin Treptow/Köpenick', 'Seelenbinderstr. 99', '12555', 'Berlin', '030 9024-12-0', '030 9024-12-900', '', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fatreptow.koepenick@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1137', 'Berlin für Körperschaften II', 'Magdalenenstr. 25', '10365', 'Berlin', '030 9024-29-0', '030 9024-29-900', '', '', '', '10010010', '691555100', 'POSTBANK BERLIN', '10050000', '6600046463', 'LBB GZ - BERLINER SPARKASSE', 'Mo und Fr 8:00 - 13:00, Do 11:00 - 18:00 Uhr und nach Vereinbarung', 'fakoeperschaften2@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('11', '1138', 'Berlin für Fahndung und Strafsachen', 'Colditzstr. 41', '12099', 'Berlin', '030/70102-777', '030/70102-700', '', '', '', '', '', '', '', '', '', 'Mo - Mi 10:00 - 14:00, Do 10:00 - 18:00, Fr 10:00 - 14:00 Uhr', 'fafahndung.strafsachen@berlin.de', 'http://www.berlin.de/oberfinanzdirektion');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2111', 'Bad Segeberg ', 'Theodor-Storm-Str. 4-10', '23795', 'Bad Segeberg', '04551 54-0', '04551 54-303', '23792', '', '', '23000000', '23001502', 'BBK LUEBECK', '23051030', '744', 'KR SPK SUEDHOLSTEIN BAD SEG', '0830-1200 MO, DI, DO, FR, 1330-1630 DO', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2112', 'Eckernförde ', 'Bergstr. 50', '24340', 'Eckernförde', '04351 756-0', '04351 83379', '', '24331', '1180', '21000000', '21001500', 'BBK KIEL', '21092023', '11511260', 'ECKERNFOERDER BANK VRB', '0800-1200 MO-FR', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2113', 'Elmshorn ', 'Friedensallee 7-9', '25335', 'Elmshorn', '04121 481-0', '04121 481-460', '25333', '', '', '22200000', '22201502', 'BBK KIEL EH ITZEHOE', '', '', '', '0800-1200 MO-FR', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2114', 'Eutin ', 'Robert-Schade-Str. 22', '23701', 'Eutin', '04521 704-0', '04521 704-406', '', '23691', '160', '23000000', '23001505', 'BBK LUEBECK', '21352240', '4283', 'SPK OSTHOLSTEIN EUTIN', '0830-1200 MO-FR, Nebenstelle Janusstr. 5 am Mo., Di, Do und Fr. 0830-1200, Do. 1330-1700', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2115', 'Flensburg ', 'Duburger Str. 58-64', '24939', 'Flensburg', '0461 813-0', '0461 813-254', '', '24905', '1552', '21500000', '21501500', 'BBK FLENSBURG', '', '', '', '0800-1200 MO-FR', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2116', 'Heide ', 'Ernst-Mohr-Str. 34', '25746', 'Heide', '0481 92-1', '0481 92-690', '25734', '', '', '21500000', '21701502', 'BBK FLENSBURG', '22250020', '60000123', 'SPK WESTHOLSTEIN', '0800-1200 MO, DI, DO, FR, 1400-1700 DO', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2117', 'Husum ', 'Herzog-Adolf-Str. 18', '25813', 'Husum', '04841 8949-0', '04841 8949-200', '', '25802', '1230', '21500000', '21701500', 'BBK FLENSBURG', '', '', '', '0800-1200 MO-FR', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2118', 'Itzehoe ', 'Fehrsstr. 5', '25524', 'Itzehoe', '04821 66-0', '04821 661-499', '', '25503', '1344', '22200000', '22201500', 'BBK KIEL EH ITZEHOE', '', '', '', '0800-1200 MO, DI, DO, FR, 1400-1730 DO', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2119', 'Kiel-Nord ', 'Holtenauer Str. 183', '24118', 'Kiel', '0431 8819-0', '0431 8819-1200', '24094', '', '', '21000000', '21001501', 'BBK KIEL', '21050000', '52001500', 'HSH NORDBANK KIEL', '0800-1200 MO-FR 1430-1600 DI', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2120', 'Kiel-Süd ', 'Hopfenstr. 2a', '24114', 'Kiel', '0431 602-0', '0431 602-1009', '24095', '', '', '21000000', '21001502', 'BBK KIEL', '21050000', '52001510', 'HSH NORDBANK KIEL', '0800-1200 MO, DI, DO, FR, 1430-1730 DI', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2121', 'Leck ', 'Eesacker Str. 11 a', '25917', 'Leck', '04662 85-0', '04662 85-266', '', '25912', '1240', '21700000', '21701501', 'BBK FLENSBURG EH HUSUM', '21750000', '80003569', 'NORD-OSTSEE SPK SCHLESWIG', '0800-1200 MO-FR', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2122', 'Lübeck ', 'Possehlstr. 4', '23560', 'Lübeck', '0451 132-0', '0451 132-501', '23540', '', '', '23000000', '23001500', 'BBK LUEBECK', '21050000', '7052000200', 'HSH NORDBANK KIEL', '0730-1300 MO+DI 0730-1700 Do 0730-1200 Fr', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2123', 'Meldorf ', 'Jungfernstieg 1', '25704', 'Meldorf', '04832 87-0', '04832 87-2508', '', '25697', '850', '21500000', '21701503', 'BBK FLENSBURG', '21851830', '106747', 'VERB SPK MELDORF', '0800-1200 MO, DI, DO, FR, 1400-1700 MO', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2124', 'Neumünster ', 'Bahnhofstr. 9', '24534', 'Neumünster', '04321 496 0', '04321 496-189', '24531', '', '', '21000000', '21001507', 'BBK KIEL', '', '', '', '0800-1200 MO-MI, FR 1400-1700 DO', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2125', 'Oldenburg ', 'Lankenstr. 1', '23758', 'Oldenburg', '04361 497-0', '04361 497-125', '', '23751', '1155', '23000000', '23001504', 'BBK LUEBECK', '21352240', '51000396', 'SPK OSTHOLSTEIN EUTIN', '0900-1200 MO-FR 1400-1600 MI', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2126', 'Plön ', 'Fünf-Seen-Allee 1', '24306', 'Plön', '04522 506-0', '04522 506-2149', '', '24301', '108', '21000000', '21001503', 'BBK KIEL', '21051580', '2600', 'SPK KREIS PLOEN', '0800-1200 MO, Di, Do, Fr, 1400-1700 Di', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2127', 'Ratzeburg ', 'Bahnhofsallee 20', '23909', 'Ratzeburg', '04541 882-01', '04541 882-200', '23903', '', '', '23000000', '23001503', 'BBK LUEBECK', '23052750', '100188', 'KR SPK LAUENBURG RATZEBURG', '0830-1230 MO, DI, DO, FR, 1430-1730 DO', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2128', 'Rendsburg ', 'Ritterstr. 10', '24768', 'Rendsburg', '04331 598-0', '04331 598-2770', '', '24752', '640', '21000000', '21001504', 'BBK KIEL', '21450000', '1113', 'SPK MITTELHOLSTEIN RENDSBG', '0730-1200 MO-FR', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2129', 'Schleswig ', 'Suadicanistr. 26-28', '24837', 'Schleswig', '04621 805-0', '04621 805-290', '', '24821', '1180', '21500000', '21501501', 'BBK FLENSBURG', '21690020', '91111', 'VOLKSBANK RAIFFEISENBANK', '0800-1200 MO, DI, DO, FR, 1430-1700 DO', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2130', 'Stormarn ', 'Berliner Ring 25', '23843', 'Bad Oldesloe', '04531 507-0', '04531 507-399', '23840', '', '', '23000000', '23001501', 'BBK LUEBECK', '23051610', '20503', 'SPK BAD OLDESLOE', '0830-1200 MO-FR', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2131', 'Pinneberg ', 'Friedrich-Ebert-Str. 29', '25421', 'Pinneberg', '04101 5472-0', '04101 5472-680', '', '25404', '1451', '22200000', '22201503', 'BBK KIEL EH ITZEHOE', '', '', '', '0800-1200 MO-FR', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('1', '2132', 'Bad Segeberg / Außenst.Norderstedt', 'Europaallee 22', '22850', 'Norderstedt', '040 523068-0', '040 523068-70', '', '', '', '23000000', '23001502', 'BBK LUEBECK', '23051030', '744', 'KR SPK SUEDHOLSTEIN BAD SEG', '0830-1200 MO, DI, DO, FR, 1330-1630 DO', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2201', 'Hamburg Steuerkasse', 'Steinstraße 10', '20095', 'Hamburg', '040/42853-03', '040/42853-2159', '', '20041', '106026', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAfuerSteuererhebung@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2202', 'Hamburg-Altona ', 'Gr. Bergstr. 264/266', '22767', 'Hamburg', '040/42811-02', '040/42811-2871', '', '22704', '500471', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAHamburgAltona@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2203', 'Hamburg-Bergedorf ', 'Ludwig-Rosenberg-Ring 41', '21031', 'Hamburg', '040/42891-0', '040/42891-2243', '', '21003', '800360', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', 'FAHamburgBergedorf@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2206', 'Hamburg-Harburg ', 'Harburger Ring 40', '21073', 'Hamburg', '040/42871-0', '040/42871-2215', '', '21043', '900352', '20000000', '200 015 30', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAHamburgHarburg@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2208', 'Hamburg-Wandsbek ', 'Schloßstr.107', '22041', 'Hamburg', '040/42881-0', '040/42881-2888', '', '22006', '700660', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAHamburgWandsbek@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2209', 'Hamburg-Oberalster ', 'Hachmannplatz 2', '20099', 'Hamburg', '040/42854-90', '040/42854-4960', '', '20015', '102248', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAHamburgOberalster@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2210', 'Hamburg f.VerkSt.u.Grundbes-10', 'Gorch-Fock-Wall 11', '20355', 'Hamburg', '040/42843-60', '040/42843-6199', '', '20306', '301721', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAfuerVerkehrsteuern@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2215', 'Hamburg-Barmbek-Uhlenhorst 15  ', 'Lübecker Str. 101-109', '22087', 'Hamburg', '040/42860-0', '040/42860-730', '', '22053', '760360', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAHamburgBarmbekUhlenhorst@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2216', 'Hamburg f.VerkSt.u.Grundbes-16', 'Gorch-Fock-Wall 11', '20355', 'Hamburg', '040/42843-60', '040/42843-6199', '', '20306', '301721', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAfuerVerkehrsteuern@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2217', 'Hamburg-Mitte-Altstadt 17 ', 'Wendenstraße 35 b', '20097', 'Hamburg', '040/42853-06', '040/42853-6671', '', '20503', '261338', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAHamburgMitteAltstadt@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2220', 'Hamburg f.VerkSt.u.Grundbes-20', 'Gorch-Fock-Wall 11', '20355', 'Hamburg', '040/42843-60', '040/42843-6599', '', '20306', '301721', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAfuerVerkehrsteuern@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2222', 'Hamburg-Hansa ', 'Steinstraße 10', '20095', 'Hamburg', '040/42853-01', '040/42853-2064', '', '20015', '102244', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', 'FAHamburgHansa@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2224', 'Hamburg-Mitte-Altstadt ', 'Wendenstr. 35 b', '20097', 'Hamburg', '040/42853-06', '040/42853-6671', '', '20503', '261338', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAHamburgMitteAltstadt@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2225', 'Hamburg-Neustadt-St.Pauli ', 'Steinstraße 10', '20095', 'Hamburg', '040/42853-02', '040/42853-2106', '', '20015', '102246', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAHamburgNeustadt@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2226', 'Hamburg-Nord ', 'Borsteler Chaussee 45', '22453', 'Hamburg', '040/42806-0', '040/42806-220', '', '22207', '600707', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', 'FAHamburgNord@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2227', 'Hamburg für Großunternehmen', 'Amsinckstr. 40', '20097', 'Hamburg', '040/42853-05', '040/42853-5559', '', '20015', '102205', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAfuerGroßunternehmen@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2228', 'Hamburg Neust.-St.Pauli-28', 'Steinstr. 10', '20095', 'Hamburg', '040/42853-3589', '040/42853-2106', '', '20015', '102246', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAHamburgNeustadt@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2230', 'Hamburg f.Verkehrst.u.Grundbes', 'Gorch-Fock-Wall 11', '20355', 'Hamburg', '040/42843-60', '040/42843-6799', '', '20306', '301721', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAfuerVerkehrsteuern@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2235', 'Hamburg f.VerkSt.u.Grundbes-35', 'Gorch-Fock-Wall 11', '20355', 'Hamburg', '040/42843-60', '040/42843-6199', '', '20306', '301721', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAfuerVerkehrsteuern@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2254', 'Hamburg-Eimsbüttel ', 'Stresemannstraße 23', '22769', 'Hamburg', '040/42807-0', '040/42807-220', '', '22770', '570110', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAHamburgEimsbuettel@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2257', 'Hamburg-Am Tierpark ', 'Hugh-Greene-Weg 6', '22529', 'Hamburg', '', '', '', '22520', '', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FAHamburgAmTierpark@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('2', '2271', 'Hamburg-Barmbek-Uhlenhorst ', 'Lübecker Str. 101-109', '22087', 'Hamburg', '040/42860-0', '040/42860-730', '', '22053', '760360', '20000000', '20001530', 'BBK HAMBURG', '21050000', '101444000', 'HSH NORDBANK KIEL', '', ' FABarmbekUhlenhorst@finanzamt.hamburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2311', 'Alfeld (Leine) ', 'Ravenstr.10', '31061', 'Alfeld', '05181/7050', '05181/705240', '', '31042', '1244', '25000000', '25901505', 'BBK HANNOVER', '25950130', '10011102', 'KR SPK HILDESHEIM', 'Mo. - Fr. 8.30 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-alf.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2312', 'Bad Gandersheim ', 'Alte Gasse 24', '37581', 'Bad Gandersheim', '05382/760', '(05382) 76-213 + 204', '', '37575', '1180', '26000000', '26001501', 'BBK GOETTINGEN', '25050000', '22801005', 'NORD LB HANNOVER', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-gan.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2313', 'Braunschweig-Altewiekring ', 'Altewiekring 20', '38102', 'Braunschweig', '0531/7050', '0531/705309', '', '38022', '3229', '27000000', '27001501', 'BBK BRAUNSCHWEIG', '25050000', '2498020', 'NORD LB HANNOVER', 'Mo. - Fr. 8.00 - 12.00 Uhr, Mo. 14.00 - 17.00 Uhr', 'Poststelle@fa-bs-a.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2314', 'Braunschweig-Wilhelmstr. ', 'Wilhelmstr. 4', '38100', 'Braunschweig', '0531/4890', '0531/489224', '', '38022', '3249', '27000000', '27001502', 'BBK BRAUNSCHWEIG', '25050000', '811422', 'NORD LB HANNOVER', 'Mo. - Fr. 8.00 - 12.00 Uhr, Mo. 14.00 - 17.00 Uhr', 'Poststelle@fa-bs-w.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2315', 'Buchholz in der Nordheide ', 'Bgm.-A.-Meyer-Str. 5', '21244', 'Buchholz', '04181/2030', '(04181) 203-4444', '', '21232', '1262', '20000000', '20001520', 'BBK HAMBURG', '20750000', '3005063', 'SPK HARBURG-BUXTEHUDE', 'Mo. - Fr. 8.00 - 12.00 Uhr , Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-buc.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2316', 'Burgdorf ', 'V.d.Hannov. Tor 30', '31303', 'Burgdorf', '05136/8060', '05136/806144', '31300', '', '', '25000000', '25001515', 'BBK HANNOVER', '25050180', '1040400010', 'SPARKASSE HANNOVER', 'Mo. - Fr. 8.30 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-bu.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2317', 'Celle ', 'Sägemühlenstr. 5', '29221', 'Celle', '(05141) 915-0', '05141/915666', '', '29201', '1107', '25000000', '25701511', 'BBK HANNOVER', '25750001', '59', 'SPARKASSE CELLE', 'Mo. - Fr. 8.00 - 12.00 Uhr , Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-ce.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2318', 'Cuxhaven ', 'Poststr. 81', '27474', 'Cuxhaven', '(04721) 563-0', '04721/563313', '', '27452', '280', '29000000', '24101501', 'BBK BREMEN', '24150001', '100503', 'ST SPK CUXHAVEN', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-cux.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2319', 'Gifhorn ', 'Braunschw. Str. 6-8', '38518', 'Gifhorn', '05371/8000', '05371/800241', '', '38516', '1249', '27000000', '27001503', 'BBK BRAUNSCHWEIG', '26951311', '11009958', 'SPK GIFHORN-WOLFSBURG', 'Mo. - Fr. 8.00 - 12.00 Uhr, Do. 14.00 - 17.00', 'Poststelle@fa-gf.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2320', 'Göttingen ', 'Godehardstr. 6', '37073', 'Göttingen', '0551/4070', '0551/407449', '37070', '', '', '26000000', '26001500', 'BBK GOETTINGEN', '26050001', '91', 'SPARKASSE GOETTINGEN', 'Servicecenter: Mo., Di., Mi. und Fr. 8.00 - 12.00 u. Do. 8.00 - 17.00 Uhr,', 'Poststelle@fa-goe.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2321', 'Goslar ', 'Wachtelpforte 40', '38644', 'Goslar', '05321/5590', '05321/559200', '', '38604', '1440', '27000000', '27001505', 'BBK BRAUNSCHWEIG', '26850001', '2220', 'SPARKASSE GOSLAR/HARZ', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-gs.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2322', 'Hameln ', 'Süntelstraße 2', '31785', 'Hameln', '05151/2040', '05151/204200', '', '31763', '101325', '25000000', '25401511', 'BBK HANNOVER', '25450001', '430', 'ST SPK HAMELN', 'Mo. - Fr. 8.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-hm.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2323', 'Hannover-Land I ', 'Göttinger Chaus. 83A', '30459', 'Hannover', '(0511) 419-1', '0511/4192269', '', '30423', '910320', '25000000', '25001512', 'BBK HANNOVER', '25050000', '101342434', 'NORD LB HANNOVER', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-h-l1.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2324', 'Hannover-Mitte ', 'Lavesallee 10', '30169', 'Hannover', '0511/16750', '0511/1675277', '', '30001', '143', '25000000', '25001516', 'BBK HANNOVER', '25050000', '101341816', 'NORD LB HANNOVER', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhrund nach Vereinbarung', 'Poststelle@fa-h-mi.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2325', 'Hannover-Nord ', 'Vahrenwalder Str.206', '30165', 'Hannover', '0511/67900', '(0511) 6790-6090', '', '30001', '167', '25000000', '25001514', 'BBK HANNOVER', '25050000', '101342426', 'NORD LB HANNOVER', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-h-no.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2326', 'Hannover-Süd ', 'Göttinger Chaus. 83B', '30459', 'Hannover', '0511/4191', '0511/4192575', '', '30423', '910355', '25000000', '25001517', 'BBK HANNOVER', '25050000', '101342400', 'NORD LB HANNOVER', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-h-su.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2327', 'Hannover-Land II ', 'Vahrenwalder Str.208', '30165', 'Hannover', '0511/67900', '(0511) 6790-6633', '', '30001', '165', '25000000', '25001520', 'BBK HANNOVER', '25050000', '101342517', 'NORD LB HANNOVER', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-h-l2.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2328', 'Helmstedt ', 'Ernst-Koch-Str.3', '38350', 'Helmstedt', '05351/1220', '(05351) 122-299', '', '38333', '1320', '27000000', '27101500', 'BBK BRAUNSCHWEIG', '25050000', '5801006', 'NORD LB HANNOVER', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-he.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2329', 'Herzberg am Harz ', 'Sieberstr. 1', '37412', 'Herzberg', '05521/8570', '05521/857220', '', '37401', '1153', '26000000', '26001502', 'BBK GOETTINGEN', '26351015', '1229327', 'SPARKASSE IM KREIS OSTERODE', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-hz.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2330', 'Hildesheim ', 'Kaiserstrasse 47', '31134', 'Hildesheim', '05121/3020', '05121/302480', '', '31104', '100455', '25000000', '25901500', 'BBK HANNOVER', '25950130', '5555', 'KR SPK HILDESHEIM', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-hi.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2331', 'Holzminden ', 'Ernst-August-Str.30', '37603', 'Holzminden', '05531/1220', '05531/122100', '', '37601', '1251', '25000000', '25401512', 'BBK HANNOVER', '25050000', '27811140', 'NORD LB HANNOVER', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-hol.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2332', 'Lüchow ', 'Mittelstr.5', '29439', 'Lüchow', '(05841) 963-0', '05841/963170', '', '29431', '1144', '24000000', '25801503', 'BBK LUENEBURG', '25851335', '2080000', 'KR SPK LUECHOW-DANNENBERG', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-luw.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2333', 'Lüneburg ', 'Am Alt. Eisenwerk 4a', '21339', 'Lüneburg', '04131/3050', '04131/305915', '21332', '', '', '24000000', '24001500', 'BBK LUENEBURG', '24050110', '18', 'SPK LUENEBURG', 'Mo. - Fr. 8.00-12.00 Uhr, Do. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-lg.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2334', 'Nienburg/Weser ', 'Schloßplatz 10', '31582', 'Nienburg', '05021/8011', '05021/801300', '', '31580', '2000', '25000000', '25601500', 'BBK HANNOVER', '25650106', '302224', 'SPARKASSE NIENBURG', 'Mo. - Fr. 7.30 - 12.00 Uhr und nach Vereinbarung, zusätzl. Arbeitnehmerbereich: Do. 14 -', 'Poststelle@fa-ni.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2335', 'Northeim ', 'Graf-Otto-Str. 31', '37154', 'Northeim', '05551/7040', '05551/704221', '', '37142', '1261', '26000000', '26201500', 'BBK GOETTINGEN', '26250001', '208', 'KR SPK NORTHEIM', 'Mo. - Fr. 8.30 - 12.30 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-nom.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2336', 'Osterholz-Scharmbeck ', 'Pappstraße 2', '27711', 'Osterholz-Scharmbeck', '04791/3020', '04791/302101', '', '27701', '1120', '29000000', '29001523', 'BBK BREMEN', '29152300', '202622', 'KR SPK OSTERHOLZ', 'Mo. - Fr. 8.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-ohz.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2338', 'Peine ', 'Duttenstedt.Str. 106', '31224', 'Peine', '05171/4070', '05171/407199', '31221', '', '', '27000000', '27001507', 'BBK BRAUNSCHWEIG', '25250001', '75003210', 'KR SPK PEINE', 'Mo. - Mi. Fr. 9.00 - 12.00, Do. 13.30 - 16.00 UhrDo. (Infothek) 13.30 -', 'Poststelle@fa-pe.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2340', 'Rotenburg (Wümme) ', 'Hoffeldstr. 5', '27356', 'Rotenburg', '04261/740', '04261/74108', '', '27342', '1260', '29000000', '29001522', 'BBK BREMEN', '24151235', '26106377', 'SPK ROTENBURG-BREMERVOERDE', 'Mo. - Mi., Fr. 8.00 - 12.00 Uhr, Do. 8.00 - 17.30', 'Poststelle@fa-row.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2341', 'Soltau ', 'Rühberg 16 - 20', '29614', 'Soltau', '05191/8070', '05191/807144', '', '29602', '1243', '24000000', '25801502', 'BBK LUENEBURG', '25851660', '100016', 'KR SPK SOLTAU', 'Mo. - Fr. 8.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-sol.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2342', 'Hannover-Land I Außenstelle Springe', 'Bahnhofstr. 28', '31832', 'Springe', '05041/7730', '05041/77363', '', '31814', '100255', '25000000', '25001512', 'BBK HANNOVER', '25050180', '3001000037', 'SPARKASSE HANNOVER', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-ast-spr.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2343', 'Stade ', 'Harburger Str. 113', '21680', 'Stade', '(04141) 536-0', '(04141) 536-499', '21677', '', '', '24000000', '24001560', 'BBK LUENEBURG', '24151005', '42507', 'SPK STADE-ALTES LAND', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-std.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2344', 'Stadthagen ', 'Schloß', '31655', 'Stadthagen', '05721/7050', '05721/705250', '31653', '', '', '49000000', '49001502', 'BBK MINDEN, WESTF', '25551480', '470140401', 'SPARKASSE SCHAUMBURG', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-shg.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2345', 'Sulingen ', 'Hindenburgstr. 16', '27232', 'Sulingen', '04271/870', '04271/87289', '', '27226', '1520', '29000000', '29001516', 'BBK BREMEN', '25651325', '30101430', 'KR SPK DIEPHOLZ', 'Mo., Mi., Do. und Fr. 8.00 - 12.00 Uhr, Di. 8.00 - 17.00 Uhr', 'Poststelle@fa-su.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2346', 'Syke ', 'Bürgerm.-Mävers-Str. 15', '28857', 'Syke', '04242/1620', '04242/162423', '', '28845', '1164', '29000000', '29001515', 'BBK BREMEN', '29151700', '1110044557', 'KREISSPARKASSE SYKE', 'Mo. - Fr. 8.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-sy.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2347', 'Uelzen ', 'Am Königsberg 3', '29525', 'Uelzen', '0581/8030', '0581/803404', '', '29504', '1462', '24000000', '25801501', 'BBK LUENEBURG', '25850110', '26', 'SPARKASSE UELZEN', 'Mo. - Fr. 8.30 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-ue.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2348', 'Verden (Aller) ', 'Bremer Straße 4', '27283', 'Verden', '04231/9190', '04231/919310', '', '27263', '1340', '29000000', '29001517', 'BBK BREMEN', '29152670', '10000776', 'KR SPK VERDEN', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-ver.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2349', 'Wesermünde ', 'Borriesstr. 50', '27570', 'Bremerhaven', '0471/1830', '0471/183119', '', '27503', '100369', '29000000', '29201501', 'BBK BREMEN', '29250150', '100103200', 'KR SPK WESERMUENDE-HADELN', 'Mo. - Fr. 8.30 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-wem.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2350', 'Winsen (Luhe) ', 'Von-Somnitz-Ring 6', '21423', 'Winsen', '04171/6560', '(04171) 656-115', '', '21413', '1329', '24000000', '24001550', 'BBK LUENEBURG', '20750000', '7051519', 'SPK HARBURG-BUXTEHUDE', 'Mo. - Fr. 8.00 - 12.00 Uhr, Do. 14.00 - 18.00 Uhr und nach Vereinbarung', 'Poststelle@fa-wl.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2351', 'Wolfenbüttel ', 'Jägerstr. 19', '38304', 'Wolfenbüttel', '05331/8030', '(05331) 803-113/266 ', '38299', '', '', '27000000', '27001504', 'BBK BRAUNSCHWEIG', '25050000', '9801002', 'NORD LB HANNOVER', 'Mo. - Fr. 8.00 - 12.00 Uhr, Mi. 14.00 - 17.00 Uhr', 'Poststelle@fa-wf.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2352', 'Zeven ', 'Kastanienweg 1', '27404', 'Zeven', '04281/7530', '04281/753290', '', '27392', '1259', '29000000', '29201503', 'BBK BREMEN', '24151235', '404350', 'SPK ROTENBURG-BREMERVOERDE', 'Mo. - Fr. 8.30 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-zev.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2353', 'Papenburg ', 'Große Straße 32', '26871', 'Aschendorf', '04962/5030', '04962/503222', '', '26883', '2264', '28000000', '28501512', 'BBK OLDENBURG (OLDB)', '26650001', '1020007', 'SPK EMSLAND', 'Mo. - Fr. 9.00 - 12.00 Uhr, Mi. 14.00 - 17.00 Uhr', 'Poststelle@fa-pap.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2354', 'Aurich ', 'Hasseburger Str. 3', '26603', 'Aurich', '04941/1750', '04941/175152', '', '26582', '1260', '28000000', '28501514', 'BBK OLDENBURG (OLDB)', '28350000', '90001', 'SPK AURICH-NORDEN', 'Mo. - Fr. 8.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-aur.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2355', 'Bad Bentheim ', 'Heinrich-Böll-Str. 2', '48455', 'Bad Bentheim', '05922/970-0', '05922/970-2000', '', '48443', '1262', '26500000', '26601501', 'BBK OSNABRUECK', '26750001', '1000066', 'KR SPK NORDHORN', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do 14.00 - 15.30 Uhr', 'Poststelle@fa-ben.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2356', 'Cloppenburg ', 'Bahnhofstr. 57', '49661', 'Cloppenburg', '04471/8870', '04471/887477', '', '49646', '1680', '28000000', '28001501', 'BBK OLDENBURG (OLDB)', '28050100', '80402100', 'LANDESSPARKASSE OLDENBURG', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-clp.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2357', 'Delmenhorst ', 'Fr.-Ebert-Allee 15', '27749', 'Delmenhorst', '04221/1530', '04221/153126', '27747', '', '', '29000000', '29001521', 'BBK BREMEN', '28050100', '30475669', 'LANDESSPARKASSE OLDENBURG', 'Mo. - Fr. 9.00 - 12.00 Uhr, Di. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-del.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2358', 'Emden ', 'Ringstr. 5', '26721', 'Emden', '(04921) 934-0', '(04921) 934-499', '', '26695', '1553', '28000000', '28401500', 'BBK OLDENBURG (OLDB)', '28450000', '26', 'SPARKASSE EMDEN', 'Mo. - Fr. 8.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-emd.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2360', 'Leer (Ostfriesland) ', 'Edzardstr. 12/16', '26789', 'Leer', '(0491) 9870-0', '0491/9870209', '26787', '', '', '28000000', '28501511', 'BBK OLDENBURG (OLDB)', '28550000', '849000', 'SPARKASSE LEER-WEENER', 'Mo. - Fr. 8.00 - 12.00 Uhr, nur Infothek: Mo., Do. 14.00 - 17.30 Uhr', 'Poststelle@fa-ler.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2361', 'Lingen (Ems) ', 'Mühlentorstr. 14', '49808', 'Lingen', '0591/91490', '0591/9149468', '', '49784', '1440', '26500000', '26601500', 'BBK OSNABRUECK', '26650001', '2402', 'SPK EMSLAND', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr und nach Vereinbarung', 'Poststelle@fa-lin.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2362', 'Norden ', 'Mühlenweg 20', '26506', 'Norden', '04931/1880', '04931/188196', '', '26493', '100360', '28000000', '28501515', 'BBK OLDENBURG (OLDB)', '28350000', '1115', 'SPK AURICH-NORDEN', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-nor.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2363', 'Nordenham ', 'Plaatweg 1', '26954', 'Nordenham', '04731/8700', '04731/870100', '', '26942', '1264', '28000000', '28001504', 'BBK OLDENBURG (OLDB)', '28050100', '63417000', 'LANDESSPARKASSE OLDENBURG', 'Mo. - Fr. 8.30 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-nhm.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2364', 'Oldenburg (Oldenburg) ', '91er Straße 4', '26121', 'Oldenburg', '0441/2381', '(0441) 238-201/2/3', '', '26014', '2445', '28000000', '28001500', 'BBK OLDENBURG (OLDB)', '28050100', '423301', 'LANDESSPARKASSE OLDENBURG', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-ol.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2365', 'Osnabrück-Land ', 'Hannoversche Str. 12', '49084', 'Osnabrück', '0541/58420', '0541/5842450', '', '49002', '1280', '26500000', '26501501', 'BBK OSNABRUECK', '26552286', '110007', 'KREISSPARKASSE MELLE', 'Mo., Mi., Do. u. Fr. 8.00 - 12.00 Uhr, Di. 12.00 - 17.00 Uhr', 'Poststelle@fa-os-l.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2366', 'Osnabrück-Stadt ', 'Süsterstr. 46/48', '49074', 'Osnabrück', '0541/3540', '(0541) 354-312', '', '49009', '1920', '26500000', '26501500', 'BBK OSNABRUECK', '26550105', '19000', 'SPARKASSE OSNABRUECK', 'Mo. - Mi., Fr. 8.00 - 12.00 Uhr, nur Infothek: Do. 12.00 - 17.00 Uhr', 'Poststelle@fa-os-s.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2367', 'Quakenbrück ', 'Lange Straße 37', '49610', 'Quakenbrück', '05431/1840', '05431/184101', '', '49602', '1261', '26500000', '26501503', 'BBK OSNABRUECK', '26551540', '18837179', 'KR SPK BERSENBRUECK', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-qua.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2368', 'Vechta ', 'Rombergstr. 49', '49377', 'Vechta', '04441/180', '(04441) 18-100', '49375', '', '', '28000000', '28001502', 'BBK OLDENBURG (OLDB)', '28050100', '70400049', 'LANDESSPARKASSE OLDENBURG', 'Mo. - Fr. 8.30 - 12.00 Uhr, Mo. 14.00 - 16.00 Uhr,Mi. 14.00 - 17.00', 'Poststelle@fa-vec.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2369', 'Westerstede ', 'Ammerlandallee 14', '26655', 'Westerstede', '04488/5150', '04488/515444', '26653', '', '', '28000000', '28001503', 'BBK OLDENBURG (OLDB)', '28050100', '40465007', 'LANDESSPARKASSE OLDENBURG', 'Mo. - Fr. 9.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-wst.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2370', 'Wilhelmshaven ', 'Rathausplatz 3', '26382', 'Wilhelmshaven', '04421/1830', '04421/183111', '', '26354', '1462', '28000000', '28201500', 'BBK OLDENBURG (OLDB)', '28250110', '2117000', 'SPARKASSE WILHELMSHAVEN', 'Mo. - Fr. 8.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-whv.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2371', 'Wittmund ', 'Harpertshausen.Str.2', '26409', 'Wittmund', '04462/840', '04462/84195', '', '26398', '1153', '28000000', '28201502', 'BBK OLDENBURG (OLDB)', '', '', '', 'Mo. - Fr. 8.00 - 12.00 Uhr, Do. 14.00 - 17.00 Uhr', 'Poststelle@fa-wtm.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2380', 'Braunschweig für Großbetriebsprüfung', 'Theodor-Heuss-Str.4a', '38122', 'Braunschweig', '0531/80970', '(0531) 8097-333', '', '38009', '1937', '', '', '', '', '', '', 'nach Vereinbarung', 'Poststelle@fa-gbp-bs.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2381', 'Göttingen für Großbetriebsprüfung', 'Godehardstr. 6', '37073', 'Göttingen', '0551/4070', '(0551) 407-448', '', '', '', '', '', '', '', '', '', '', 'Poststelle@fa-gbp-goe.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2382', 'Hannover I für Großbetriebsprüfung', 'Bischofsholer Damm 15', '30173', 'Hannover', '(0511) 8563-01', '(0511) 8563-195', '', '', '', '', '', '', '', '', '', '', 'Poststelle@fa-gbp-h1.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2383', 'Hannover II für Großbetriebsprüfung', 'Bischofsholer Damm 15', '30173', 'Hannover', '(0511) 8563-02', '(0511) 8563-250', '', '30019', '1927', '', '', '', '', '', '', '', 'Poststelle@fa-gbp-h2.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2384', 'Stade für Großbetriebsprüfung', 'Am Ärztehaus 12', '21680', 'Stade', '(04141) 602-0', '(04141) 602-60', '', '', '', '', '', '', '', '', '', '', 'Poststelle@fa-gbp-std.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2385', 'Oldenburg für Großbetriebsprüfung', 'Georgstr. 36', '26121', 'Oldenburg', '0441/2381', '(0441) 238-522', '', '26014', '2445', '', '', '', '', '', '', '', 'Poststelle@fa-gbp-ol.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2386', 'Osnabrück für Großbetriebsprüfung', 'Johann-Domann-Str. 6', '49080', 'Osnabrück', '(0541) 503 800', '(0541) 503 888', '', '', '', '', '', '', '', '', '', '', 'Poststelle@fa-gbp-os.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2390', 'Braunschweig für Fahndung und Strafsachen', 'Rudolf-Steiner-Str. 1', '38120', 'Braunschweig', '0531/28510', '(0531) 2851-150', '', '38009', '1931', '', '', '', '', '', '', 'nach Vereinbarung', 'Poststelle@fa-fust-bs.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2391', 'Hannover für Fahndung und Strafsachen', 'Göttinger Chaus. 83B', '30459', 'Hannover', '(0511) 419-1', '(0511) 419-2988', '', '30430', '911007', '', '', '', '', '', '', '', 'Poststelle@fa-fust-h.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2392', 'Lüneburg für Fahndung und Strafsachen', 'Horst-Nickel-Str. 6', '21337', 'Lüneburg', '(04131) 8545-600', '(04131) 8545-698', '', '21305', '1570', '', '', '', '', '', '', '', 'Poststelle@fa-fust-lg.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('3', '2393', 'Oldenburg für Fahndung und Strafsachen', 'Cloppenburger Str. 320', '26133', 'Oldenburg', '(0441) 9401-0', '(0441) 9401-200', '', '26014', '2442', '', '', '', '', '', '', '', 'Poststelle@fa-fust-ol.niedersachsen.de', 'www.ofd.niedersachsen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2457', 'Bremen-Mitte Bewertung ', 'Rudolf-Hilferding-Platz 1', '28195', 'Bremen', '0421 322-2725', '0421 322-2878', '', '28079', '10 79 67', '29050000', '1070110002', 'BREMER LANDESBANK BREMEN', '29050101', '109 0901', 'SPK BREMEN', 'Zentrale Informations- und Annahmestelle Mo+Do 08:00-18:00,Di+Mi 08:00-16:00,Fr 08:00-15:00', 'office@FinanzamtMitte.bremen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2471', 'Bremen-Mitte ', 'Rudolf-Hilferding-Platz 1', '28195', 'Bremen', '0421 322-2725', '0421 322-2878', '28187', '28079', '10 79 67', '29000000', '29001512', 'BBK BREMEN', '29050101', '1090646', 'SPK BREMEN', 'Zentrale Informations- und Annahmestelle Mo+Do 08:00-18:00,Di+Mi 08:00-16:00,Fr 08:00-15:00', 'office@FinanzamtMitte.bremen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2472', 'Bremen-Ost ', 'Rudolf-Hilferding-Platz 1', '28195', 'Bremen', '0421 322-3005', '0421 322-3178', '', '28057', '10 57 09', '29000000', '29001513', 'BBK BREMEN', '29050101', '1090612', 'SPK BREMEN', 'Zentrale Informations- und Annahmestelle Mo+Do 08:00-18:00,Di+Mi 08:00-16:00,Fr 08:00-15:00', 'office@FinanzamtOst.bremen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2473', 'Bremen-West ', 'Rudolf-Hilferding-Platz 1', '28195', 'Bremen', '0421 322-3422', '0421 322-3478', '', '28057', '10 57 29', '29000000', '29001514', 'BBK BREMEN', '29050101', '1090638', 'SPK BREMEN', 'Zentrale Informations- und Annahmestelle Mo+Do 08:00-18:00,Di+Mi 08:00-16:00,Fr 08:00-15:00', 'office@FinanzamtWest.bremen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2474', 'Bremen-Nord ', 'Gerhard-Rohlfs-Str. 32', '28757', 'Bremen', '0421 6607-1', '0421 6607-300', '', '28734', '76 04 34', '29000000', '29001518', 'BBK BREMEN', '29050101', '5016001', 'SPK BREMEN', 'Zentrale Informations- und Annahmestelle Mo+Do 08:00-18:00,Di+Mi 08:00-16:00,Fr 08:00-14:00', 'office@FinanzamtNord.bremen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2475', 'Bremerhaven ', 'Schifferstr. 2-8', '27568', 'Bremerhaven', '0471 486-1', '0471 486-370', '', '27516', '12 02 42', '29200000', '29201500', 'BBK BREMEN EH BREMERHAVEN', '29250000', '1100068', 'STE SPK BREMERHAVEN', 'Zentrale Informations- und Annahmestelle Mo+Do 08:00-18:00,Di+Mi 08:00-16:00,Fr 08:00-15:00', 'office@FinanzamtBremerhaven.bremen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2476', 'Bremen-Mitte KraftfahrzeugSt ', 'Schillerstr. 22', '28195', 'Bremen', '0421 322-2725', '0421 322-2878', '', '28079', '107967', '29000000', '29001512', 'BBK BREMEN', '29050101', ' 109 0646', 'SPK BREMEN', 'Zentrale Informations- und Annahmestelle Mo+Do 08:00-18:00,Di+Mi 08:00-16:00,Fr 08:00-15:00', 'office@FinanzamtMitte.bremen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2477', 'Bremerhaven Bewertung ', 'Schifferstr. 2 - 8', '27568', 'Bremerhaven', '0471 486-1', '0471 486-370', '', '27516', '12 02 42', '29200000', '29201500', 'BBK BREMEN EH BREMERHAVEN', '29250000', '1100068', 'STE SPK BREMERHAVEN', 'Zentrale Informations- und Annahmestelle Mo+Do 08.00-18.00/Di+Mi 08.00-16.00/Fr 08.00-15.00', 'office@FinanzamtBremerhaven.bremen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2478', 'Bremen für Großbetriebsprüfung', 'Schillerstr. 6-7', '28195', 'Bremen', '0421 322-4019', '0421 322-4078', '', '28057', '10 57 69', '', '', '', '', '', '', 'nach Vereinbarung', '', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2482', 'Bremen-Ost Arbeitnehmerbereich ', 'Rudolf-Hilferding-Platz 1', '28195', 'Bremen', '0421 322-3005', '0421 322-3178', '', '28057', '10 57 09', '29000000', '29001513', 'BBK BREMEN', '29050101', '1090612', 'SPK BREMEN', 'Zentrale Informations- und Annahmestelle Mo+Do 08:00-18:00,Di+Mi 08:00-16:00,Fr 08:00-15:00', 'office@FinanzamtOst.bremen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2484', 'Bremen-Nord Arbeitnehmerbereic ', 'Gerhard-Rohlfs-Str. 32', '28757', 'Bremen', '0421 6607-1', '0421 6607-300', '', '28734', '76 04 34', '29000000', '29001518', 'BBK BREMEN', '29050101', '5016001', 'SPK BREMEN', 'Zentrale Informations- und Annahmestelle Mo+Do 08:00-18:00,Di+Mi 08:00-16:00,Fr 08:00-14:00', 'office@FinanzamtNord.bremen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('4', '2485', 'Bremerhaven Arbeitnehmerbereic ', 'Schifferstr. 2-8', '27568', 'Bremerhaven', '0471 486-1', '0471 486-370', '', '27516', '12 02 42', '29200000', '29201500', 'BBK BREMEN EH BREMERHAVEN', '29250000', '1100068', 'STE SPK BREMERHAVEN', 'Zentrale Informations- und Annahmestelle Mo+Do 08:00-18:00,Di+Mi 08:00-16:00,Fr 08:00-15:00', 'office@FinanzamtBremerhaven.bremen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2601', 'Alsfeld-Lauterbach Verwaltungsstelle Alsfeld', 'In der Rambach 11', '36304', 'Alsfeld', '06631/790-0', '06631/790-555', '', '36292', '1263', '51300000', '51301504', 'BBK GIESSEN', '53051130', '1022003', 'SPARKASSE VOGELSBERGKREIS', 'Mo u. Mi 8:00-12:00, Do 14:00-18:00 Uhr', 'poststelle@Finanzamt-Alsfeld-Lauterbach.de', 'www.Finanzamt-Alsfeld-Lauterbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2602', 'Hersfeld-Rotenburg Verwaltungsstelle Bad Hersfeld', 'Im Stift 7', '36251', 'Bad Hersfeld', '06621/933-0', '06621/933-333', '', '36224', '1451', '53200000', '53201500', 'BBK KASSEL EH BAD HERSFELD', '53250000', '1000016', 'SPK BAD HERSFELD-ROTENBURG', 'Mo u. Do 8:00-12:00, Di 14:00-18:00 Uhr', 'poststelle@Finanzamt-Hersfeld-Rotenburg.de', 'www.Finanzamt-Hersfeld-Rotenburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2603', 'Bad Homburg v.d. Höhe ', 'Kaiser-Friedr.-Promenade 8-10 ', '61348', 'Bad Homburg', '06172/107-0', '06172/107-317', '61343', '61284', '1445', '50000000', '50001501', 'BBK FILIALE FRANKFURT MAIN', '51250000', '1014781', 'TAUNUS-SPARKASSE BAD HOMBG', 'Mo u. Fr 8:00-12:00, Mi 14:00-18:00 Uhr', 'poststelle@Finanzamt-Bad-Homburg.de', 'www.Finanzamt-Bad-Homburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2604', 'Rheingau-Taunus Verwaltungsst. Bad Schwalbach ', 'Emser Str.27a', '65307', 'Bad Schwalbach', '06124/705-0', '06124/705-400', '', '65301', '1165', '51000000', '51001502', 'BBK WIESBADEN', '51050015', '393000643', 'NASS SPK WIESBADEN', 'Mo-Mi 8:00-15:30, Do 13:30-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Rheingau-Taunus.de', 'www.Finanzamt-Rheingau-Taunus.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2605', 'Bensheim ', 'Berliner Ring 35', '64625', 'Bensheim', '06251/15-0', '06251/15-267', '', '64603', '1351', '50800000', '50801510', 'BBK DARMSTADT', '50950068', '1040005', 'SPARKASSE BENSHEIM', 'Mo-Mi 8:00-15:30, Do 13:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Bensheim.de', 'www.Finanzamt-Bensheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2606', 'Marburg-Biedenkopf Verwaltungsstelle Biedenkopf', 'Im Feldchen 2', '35216', 'Biedenkopf', '06421/698-0', '06421/698-109', '', '', '', '51300000', '51301514', 'BBK GIESSEN', '53350000', '110027303', 'SPK MARBURG-BIEDENKOPF', 'Mo u. Fr 8:00-12:00, Mi 14:00-18:00 Uhr Telefon Verwaltungsstelle: 06461/709-0', 'poststelle@Finanzamt-Marburg-Biedenkopf.de', 'www.Finanzamt-Marburg-Biedenkopf.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2607', 'Darmstadt ', 'Soderstraße 30', '64283', 'Darmstadt', '06151/102-0', '06151/102-1262', '64287', '64219', '110465', '50800000', '50801500', 'BBK DARMSTADT', '50850049', '5093005006', 'LD BK GZ DARMSTADT', 'Mo-Mi 8:00-15:30, Do 8:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Darmstadt.de', 'www.Finanzamt-Darmstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2608', 'Dieburg ', 'Marienstraße 19', '64807', 'Dieburg', '06071/2006-0', '06071/2006-100', '', '64802', '1209', '50800000', '50801501', 'BBK DARMSTADT', '50852651', '33211004', 'SPARKASSE DIEBURG', 'Mo-Mi 7:30-15:30, Do 13:30-18:00, Fr 7:30-12:00 Uhr', 'poststelle@Finanzamt-Dieburg.de', 'www.Finanzamt-Dieburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2609', 'Dillenburg ', 'Wilhelmstraße 9', '35683', 'Dillenburg', '02771/908-0', '02771/908-100', '', '35663', '1362', '51300000', '51301509', 'BBK GIESSEN', '51650045', '18', 'BEZ SPK DILLENBURG', 'Mo-Mi 8:00-15:30, Do 14:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Dillenburg.de', 'www.Finanzamt-Dillenburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2610', 'Eschwege-Witzenhausen Verwaltungsstelle Eschwege', 'Schlesienstraße 2', '37269', 'Eschwege', '05651/926-5', '05651/926-720', '37267', '37252', '1280', '52000000', '52001510', 'BBK KASSEL', '52250030', '18', 'SPARKASSE WERRA-MEISSNER', 'Mo u. Mi 8:00-12:00, Do 14:00-18:00 Uhr', 'poststelle@Finanzamt-Eschwege-Witzenhausen.de', 'www.Finanzamt-Eschwege-Witzenhausen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2611', 'Korbach-Frankenberg Verwaltungsstelle Frankenberg ', 'Geismarer Straße 16', '35066', 'Frankenberg', '05631/563-0', '05631/563-888', '', '', '', '51300000', '51301513', 'BBK GIESSEN', '52350005', '5001557', 'SPK WALDECK-FRANKENBERG', 'Mo, Di u. Do 8:00-15:30, Mi 13:30-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Korbach-Frankenberg.de', 'www.Finanzamt-Korbach-Frankenberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2612', 'Frankfurt am Main II ', 'Gutleutstraße 122', '60327', 'Frankfurt', '069/2545-02', '069/2545-2999', '', '60305', '110862', '50000000', '50001504', 'BBK FILIALE FRANKFURT MAIN', '50050000', '1600006', 'LD BK HESS-THUER GZ FFM', 'Mo-Mi 8:00-15:30, Do 13:30-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Frankfurt-2.de', 'www.Finanzamt-Frankfurt-am-Main.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2613', 'Frankfurt am Main I ', 'Gutleutstraße 124', '60327', 'Frankfurt', '069/2545-01', '069/2545-1999', '', '60305', '110861', '50000000', '50001504', 'BBK FILIALE FRANKFURT MAIN', '50050000', '1600006', 'LD BK HESS-THUER GZ FFM', 'Mo-Mi 8:00-15:30, Do 13:30-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Frankfurt-1.de', 'www.Finanzamt-Frankfurt-am-Main.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2614', 'Frankfurt am Main IV ', 'Gutleutstraße 118', '60327', 'Frankfurt', '069/2545-04', '069/2545-4999', '', '60305', '110864', '50000000', '50001504', 'BBK FILIALE FRANKFURT MAIN', '50050000', '1600006', 'LD BK HESS-THUER GZ FFM', 'Mo u. Mi 8:00-12:00, Do 14:00-18:00 Uhr', 'poststelle@Finanzamt-Frankfurt-4.de', 'www.Finanzamt-Frankfurt-am-Main.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2615', 'Frankfurt/M. V-Höchst Verwaltungsstelle Höchst', 'Hospitalstraße 16 a', '65929', 'Frankfurt', '069/2545-05', '069/2545-5999', '', '', '', '50000000', '50001502', 'BBK FILIALE FRANKFURT MAIN', '50050201', '608604', 'FRANKFURTER SPK FRANKFURT', 'Mo u. Mi 8:00-12:00, Do 14:00-18:00 Uhr Telefon Verwaltungsstelle: 069/30830-0', 'poststelle@Finanzamt-Frankfurt-5-Hoechst.de', 'www.Finanzamt-Frankfurt-am-Main.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2616', 'Friedberg (Hessen) ', 'Leonhardstraße 10 - 12', '61169', 'Friedberg', '06031/49-1', '06031/49-333', '', '61143', '100362', '51300000', '51301506', 'BBK GIESSEN', '51850079', '50000400', 'SPARKASSE WETTERAU', 'Di 8:00-12:00, Do 14:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Friedberg.de', 'www.Finanzamt-Friedberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2617', 'Bensheim Außenstelle Fürth', 'Erbacher Straße 23', '64658', 'Fürth', '06253/206-0', '06253/206-10', '', '64654', '1154', '50800000', '50801510', 'BBK DARMSTADT', '50950068', '1040005', 'SPARKASSE BENSHEIM', '', 'poststelle@Finanzamt-Bensheim.de', 'www.Finanzamt-Bensheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2618', 'Fulda ', 'Königstraße 2', '36037', 'Fulda', '0661/924-01', '0661/924-1606', '', '36003', '1346', '53000000', '53001500', 'BBK KASSEL EH FULDA', '53050180', '49009', 'SPARKASSE FULDA', 'Mo-Mi 8:00-15:30, Do 14:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Fulda.de', 'www.Finanzamt-Fulda.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2619', 'Gelnhausen ', 'Frankfurter Straße 14', '63571', 'Gelnhausen', '06051/86-0', '06051/86-299', '63569', '63552', '1262', '50600000', '50601502', 'BBK FRANKFURT EH HANAU', '50750094', '2008', 'KREISSPARKASSE GELNHAUSEN', 'Mo u. Mi 8:00-12:00, Do 14:30-18:00 Uhr', 'poststelle@Finanzamt-Gelnhausen.de', 'www.Finanzamt-Gelnhausen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2620', 'Gießen ', 'Schubertstraße 60', '35392', 'Gießen', '0641/4800-100', '0641/4800-1590', '35387', '35349', '110440', '', '', '', '51300000', '51301500', 'BBK GIESSEN', 'Mo-Mi 8:00-15:30,Do 14:00-18:00, Fr 8:00-12:00 Uhr', 'info@Finanzamt-Giessen.de', 'www.Finanzamt-Giessen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2621', 'Groß-Gerau ', 'Europaring 11-13', '64521', 'Groß-Gerau', '06152/170-01', '06152/170-601', '64518', '64502', '1262', '50800000', '50801502', 'BBK DARMSTADT', '50852553', '1685', 'KR SPK GROSS-GERAU', 'Mo-Mi 8:00-15.30, Do 14:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Gross-Gerau.de', 'www.Finanzamt-Gross-Gerau.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2622', 'Hanau ', 'Am Freiheitsplatz 2', '63450', 'Hanau', '06181/101-1', '06181/101-501', '63446', '63404', '1452', '50600000', '50601500', 'BBK FRANKFURT EH HANAU', '50650023', '50104', 'SPARKASSE HANAU', 'Mo u. Mi 7:30-12:00, Do 14:30-18:00 Uhr', 'poststelle@Finanzamt-Hanau.de', 'www.Finanzamt-Hanau.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2623', 'Kassel-Hofgeismar Verwaltungsstelle Hofgeismar', 'Altstädter Kirchplatz 10', '34369', 'Hofgeismar', '0561/7207-0', '0561/7207-2500', '', '', '', '52000000', '52001501', 'BBK KASSEL', '52050353', '100009202', 'KASSELER SPARKASSE', 'Di, Mi u. Fr 8:00-12:00, Do 15:00-18:00 Uhr Telefon Verwaltungsstelle: 05671/8004-0', 'poststelle@Finanzamt-Kassel-Hofgeismar.de', 'www.Finanzamt-Kassel.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2624', 'Schwalm-Eder Verwaltungsstelle Fritzlar', 'Georgengasse 5', '34560', 'Fritzlar', '05622/805-0', '05622/805-111', '', '34551', '1161', '52000000', '52001502', 'BBK KASSEL', '52052154', '110007507', 'KREISSPARKASSE SCHWALM-EDER', 'Mo u. Fr 8:00-12:00, Mi 14:00-18:00 Uhr', 'poststelle@Finanzamt-Schwalm-Eder.de', 'www.Finanzamt-Schwalm-Eder.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2625', 'Kassel-Spohrstraße ', 'Spohrstraße 7', '34117', 'Kassel', '0561/7208-0', '0561/7208-408', '34111', '34012', '101249', '52000000', '52001500', 'BBK KASSEL', '52050000', '4091300006', 'LANDESKREDITKASSE KASSEL', 'Mo u. Fr 7:30-12:00, Mi 14:00-18:00 Uhr', 'poststelle@Finanzamt-Kassel-Spohrstrasse.de', 'www.Finanzamt-Kassel.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2626', 'Kassel-Hofgeismar Verwaltungsstelle Kassel', 'Goethestraße 43', '34119', 'Kassel', '0561/7207-0', '0561/7207-2500', '34111', '34012', '101229', '52000000', '52001500', 'BBK KASSEL', '52050000', '4091300006', 'LANDESKREDITKASSE KASSEL', 'Mo, Mi u. Fr 8:00-12:00, Mi 14:00-18:00 Uhr', 'poststelle@Finanzamt-Kassel-Hofgeismar.de', 'www.Finanzamt-Kassel.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2627', 'Korbach-Frankenberg Verwaltungsstelle Korbach', 'Medebacher Landstraße 29', '34497', 'Korbach', '05631/563-0', '05631/563-888', '34495', '34482', '1240', '52000000', '52001509', 'BBK KASSEL', '52350005', '19588', 'SPK WALDECK-FRANKENBERG', 'Mo, Mi u. Fr 8:00-12:00, Do 15:30-18:00 Uhr', 'poststelle@Finanzamt-Korbach-Frankenberg.de', 'www.Finanzamt-Korbach-Frankenberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2628', 'Langen ', 'Zimmerstraße 27', '63225', 'Langen', '06103/591-01', '06103/591-285', '63222', '63202', '1280', '50000000', '50001511', 'BBK FILIALE FRANKFURT MAIN', '50592200', '31500', 'VB DREIEICH', 'Mo, Mi u. Do 8:00-15:30, Di 13:30-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Langen.de', 'www.Finanzamt-Langen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2629', 'Alsfeld-Lauterbach Verwaltungsstelle Lauterbach', 'Bahnhofstraße 69', '36341', 'Lauterbach', '06631/790-0', '06631/790-555', '36339', '', '', '53000000', '53001501', 'BBK KASSEL EH FULDA', '53051130', '60100509', 'SPARKASSE VOGELSBERGKREIS', 'Mo u. Mi 8:00-12:00, Do 14:00-18:00 Uhr Telefon Verwaltungsstelle: 06641/188-0', 'poststelle@Finanzamt-Alsfeld-Lauterbach.de', 'www.Finanzamt-Alsfeld-Lauterbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2630', 'Limburg-Weilburg Verwaltungsstelle Limburg', 'Walderdorffstraße 11', '65549', 'Limburg', '06431/208-1', '06431/208-294', '65547', '65534', '1465', '51000000', '51001507', 'BBK WIESBADEN', '51050015', '535054800', 'NASS SPK WIESBADEN', 'Mo-Mi 8:00-15:30, Do 8:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Limburg-Weilburg.de', 'www.Finanzamt-Limburg-Weilburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2631', 'Marburg-Biedenkopf Verwaltungsstelle Marburg', 'Robert-Koch-Straße 7', '35037', 'Marburg', '06421/698-0', '06421/698-109', '35034', '35004', '1469', '51300000', '51301512', 'BBK GIESSEN', '53350000', '11517', 'SPK MARBURG-BIEDENKOPF', 'Mo-Mi 8:00-15:30, Do 14:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Marburg-Biedenkopf.de', 'www.Finanzamt-Marburg-Biedenkopf.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2632', 'Schwalm-Eder Verwaltungsstelle Melsungen', 'Kasseler Straße 31 (Schloß)', '34212', 'Melsungen', '05622/805-0', '05622/805-111', '', '', '', '52000000', '52001503', 'BBK KASSEL', '52052154', '10060002', 'KREISSPARKASSE SCHWALM-EDER', 'Mo u. Fr 8:00-12:00, Mi 14:00-18:00 Uhr Telefon Verwaltungsstelle: 05661/706-0', 'poststelle@Finanzamt-Schwalm-Eder.de', 'www.Finanzamt-Schwalm-Eder.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2633', 'Michelstadt ', 'Erbacher Straße 48', '64720', 'Michelstadt', '06061/78-0', '06061/78-100', '', '64712', '3180', '50800000', '50801503', 'BBK DARMSTADT', '50851952', '40041451', 'SPK ODENWALDKREIS ERBACH', 'Mo, Di u. Do 8:00-15:30, Mi 13:30-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Michelstadt.de', 'www.Finanzamt-Michelstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2634', 'Nidda ', 'Schillerstraße 38', '63667', 'Nidda', '06043/805-0', '06043/805-159', '', '63658', '1180', '50600000', '50601501', 'BBK FRANKFURT EH HANAU', '51850079', '150003652', 'SPARKASSE WETTERAU', 'Mo, Di u. Do 7:30-16:00, Mi 13:30-18:00, Fr 7:00-12:00 Uhr', 'poststelle@Finanzamt-Nidda.de', 'www.Finanzamt-Nidda.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2635', 'Offenbach am Main-Stadt ', 'Bieberer Straße 59', '63065', 'Offenbach', '069/8091-1', '069/8091-2400', '63063', '63005', '100563', '50000000', '50001500', 'BBK FILIALE FRANKFURT MAIN', '50550020', '493', 'STE SPK OFFENBACH', 'Mo, Di u. Do 7:30-15:30, Mi 13:00-18:00, Fr 7:30-12:00 Uhr', 'poststelle@Finanzamt-Offenbach-Stadt.de', 'www.Finanzamt-Offenbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2636', 'Hersfeld-Rotenburg Verwaltungsstelle Rotenburg', 'Dickenrücker Straße 12', '36199', 'Rotenburg', '06621/933-0', '06621/933-333', '', '', '', '52000000', '52001504', 'BBK KASSEL', '53250000', '50000012', 'SPK BAD HERSFELD-ROTENBURG', 'Mo u. Fr 8:00-12:00, Mi 14:00-18:00 Uhr Telefon Verwaltungsstelle: 06623/816-0', 'poststelle@Finanzamt-Hersfeld-Rotenburg.de', 'www.Finanzamt-Hersfeld-Rotenburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2637', 'Rheingau-Taunus Verwaltungsstelle Rüdesheim', 'Hugo-Asbach-Straße 3 - 7', '65385', 'Rüdesheim', '06124/705-0', '06124/705-400', '', '', '', '51000000', '51001501', 'BBK WIESBADEN', '51050015', '455022800', 'NASS SPK WIESBADEN', 'Mo u. Fr 8:00-12:00, Mi 14:00-18:00 Uhr Telefon Verwaltungsstelle: 06722/405-0', 'poststelle@Finanzamt-Rheingau-Taunus.de', 'www.Finanzamt-Rheingau-Taunus.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2638', 'Limburg-Weilburg Verwaltungsstelle Weilburg', 'Kruppstraße 1', '35781', 'Weilburg', '06431/208-1', '06431/208-294', '35779', '', '', '51000000', '51001511', 'BBK WIESBADEN', '51151919', '100000843', 'KR SPK WEILBURG', 'Mo-Mi 8:00-16:00, Do 14:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Limburg-Weilburg.de', 'www.Finanzamt-Limburg-Weilburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2639', 'Wetzlar ', 'Frankfurter Straße 59', '35578', 'Wetzlar', '06441/202-0', '06441/202-6810', '35573', '35525', '1520', '51300000', '51301508', 'BBK GIESSEN', '51550035', '46003', 'SPARKASSE WETZLAR', 'Mo u. Mi 8:00-12:00, Do 14:00-18:00 Uhr', 'poststelle@Finanzamt-Wetzlar.de', 'www.Finanzamt-Wetzlar.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2640', 'Wiesbaden I ', 'Dostojewskistraße 8', '65187', 'Wiesbaden', '0611/813-0', '0611/813-1000', '65173', '65014', '2469', '51000000', '51001500', 'BBK WIESBADEN', '51050015', '100061600', 'NASS SPK WIESBADEN', 'Mo, Di u. Do 8:00-15:30, Mi 13:30-18:00, Fr 7:00-12:00 Uhr', 'poststelle@Finanzamt-Wiesbaden-1.de', 'www.Finanzamt-Wiesbaden.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2641', 'Eschwege-Witzenhausen Verwaltungsstelle Witzenhausen', 'Südbahnhofstraße 37', '37213', 'Witzenhausen', '05651/926-5', '05651/926-720', '', '', '', '52000000', '52001505', 'BBK KASSEL', '52250030', '50000991', 'SPARKASSE WERRA-MEISSNER', 'Mo u. Fr 8:00-12:00, Mi 14:00-18:00 Uhr Telefon Verwaltungsstelle: 05542/602-0', 'poststelle@Finanzamt-Eschwege-Witzenhausen.de', 'www.Finanzamt-Eschwege-Witzenhausen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2642', 'Schwalm-Eder Verwaltungsstelle Schwalmstadt', 'Landgraf-Philipp-Straße 15', '34613', 'Schwalmstadt', '05622/805-0', '05622/805-111', '', '', '', '52000000', '52001506', 'BBK KASSEL', '52052154', '200006641', 'KREISSPARKASSE SCHWALM-EDER', 'Mo u. Mi 8:00-12:00, Do 14:00-18:00 Uhr Telefon Verwaltungsstelle: 06691/738-0', 'poststelle@Finanzamt-Schwalm-Eder.de', 'www.Finanzamt-Schwalm-Eder.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2643', 'Wiesbaden II ', 'Dostojewskistraße 8', '65187', 'Wiesbaden', '0611/813-0', '0611/813-2000', '65173', '65014', '2469', '51000000', '51001500', 'BBK WIESBADEN', '51050015', '100061600', 'NASS SPK WIESBADEN', 'Mo, Di u. Do 8:00-15:30, Mi 13:30-18:00, Fr 7:00-12:00 Uhr', 'poststelle@Finanzamt-Wiesbaden-2.de', 'www.Finanzamt-Wiesbaden.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2644', 'Offenbach am Main-Land ', 'Bieberer Straße 59', '63065', 'Offenbach', '069/8091-1', '069/8091-3400', '63063', '63005', '100552', '50000000', '50001500', 'BBK FILIALE FRANKFURT MAIN', '50550020', '493', 'STE SPK OFFENBACH', 'Mo, Di u. Do 7:30-15:30, Mi 13:00-18:00, Fr 7:30-12:00 Uhr', 'poststelle@Finanzamt-Offenbach-Land.de', 'www.Finanzamt-Offenbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2645', 'Frankfurt am Main III ', 'Gutleutstraße 120', '60327', 'Frankfurt', '069/2545-03', '069/2545-3999', '', '60305', '110863', '50000000', '50001504', 'BBK FILIALE FRANKFURT MAIN', '50050000', '1600006', 'LD BK HESS-THUER GZ FFM', 'Mo u. Mi 8:00-12:00, Do 14:00-18:00 Uhr', 'poststelle@Finanzamt-Frankfurt-3.de', 'wwww.Finanzamt-Frankfurt-am-Main.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2646', 'Hofheim am Taunus ', 'Nordring 4 - 10', '65719', 'Hofheim', '06192/960-0', '06192/960-412', '65717', '65703', '1380', '50000000', '50001503', 'BBK FILIALE FRANKFURT MAIN', '51250000', '2000008', 'TAUNUS-SPARKASSE BAD HOMBG', 'Mo-Mi 8:00-15:30, Do 13:30-18:00, Fr 8:00-12:00 Uhr', 'poststelle@Finanzamt-Hofheim-am-Taunus.de', 'www.Finanzamt-Hofheim-am-Taunus.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('6', '2647', 'Frankfurt/M. V-Höchst Verwaltungsstelle Frankfurt', 'Gutleutstraße 116', '60327', 'Frankfurt', '069/2545-05', '069/2545-5999', '', '60305', '110865', '50000000', '50001504', 'BBK FILIALE FRANKFURT MAIN', '50050000', '1600006', 'LD BK HESS-THUER GZ FFM', 'Mo u. Mi 8:00-12:00, Do 14:00-18:00 Uhr', 'poststelle@Finanzamt-Frankfurt-5-Hoechst.de', 'www.Finanzamt-Frankfurt-am-Main.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2701', 'Bad Neuenahr-Ahrweiler ', 'Römerstr. 5', '53474', 'Bad Neuenahr-Ahrweiler', '02641/3820', '02641/38212000', '', '53457', '1209', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-aw.fin-rlp.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2702', 'Altenkirchen-Hachenburg ', 'Frankfurter Str. 21', '57610', 'Altenkirchen', '02681/860', '02681/8610090', '57609', '57602', '1260', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-ak.fin-rlp.de', 'www.finanzamt-altenkirchen-hachenburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2703', 'Bingen-Alzey Aussenstelle Alzey', 'Rochusallee 10', '55411', 'Bingen', '06721/7060', '06721/70614080', '55409', '55382', '', '55050000', '901', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR Telefon-Nr. Aussenstelle: 06731/4000', 'Poststelle@fa-bi.fin-rlp.de', 'www.finanzamt-bingen-alzey.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2706', 'Bad Kreuznach ', 'Ringstr. 10', '55543', 'Bad Kreuznach', '0671/7000', '0671/70011702', '55541', '55505', '1552', '55050000', '901', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-kh.fin-rlp.de', 'www.finanzamt-bad-kreuznach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2707', 'Bernkastel-Wittlich Aussenstelle Bernkastel-Kues', 'Unterer Sehlemet 15', '54516', 'Wittlich', '06571/95360', '06571/953613400', '', '54502', '1240', '55050000', '902', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR Telefon-Nr. Aussenstelle: 06531/5060', 'Poststelle@fa-wi.fin-rlp.de', 'www.finanzamt-bernkastel-wittlich.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2708', 'Bingen-Alzey ', 'Rochusallee 10', '55411', 'Bingen', '06721/7060', '06721/70614080', '55409', '55382', '', '55050000', '901', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-bi.fin-rlp.de', 'www.finanzamt-bingen-alzey.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2709', 'Idar-Oberstein ', 'Hauptstraße 199', '55743', 'Idar-Oberstein', '06781/680', '06781/6818333', '', '55708', '11820', '55050000', '901', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-io.fin-rlp.de', 'www.finanzamt-idar-oberstein.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2710', 'Bitburg-Prüm ', 'Kölner Straße 20', '54634', 'Bitburg', '06561/6030', '06561/60315090', '', '54622', '1252', '55050000', '902', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-bt.fin-rlp.de', 'www.finanzamt-bitburg-pruem.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2713', 'Daun ', 'Berliner Straße 1', '54550', 'Daun', '06592/95790', '06592/957916175', '', '54542', '1160', '55050000', '902', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-da.fin-rlp.de', 'www.finanzamt-daun.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2714', 'Montabaur-Diez Aussenstelle Diez', 'Koblenzer Str. 15', '56410', 'Montabaur', '02602/1210', '02602/12127099', '56409', '56404', '1461', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR Telefon-Nr. Aussenstelle: 06432/5040', 'Poststelle@fa-mt.fin-rlp.de', 'www.finanzamt-montabaur-diez.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2715', 'Frankenthal ', 'Friedrich-Ebert-Straße 6', '67227', 'Frankenthal', '06233/49030', '06233/490317082', '67225', '67203', '1324', '55050000', '910', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-ft.fin-rlp.de', 'www.finanzamt-frankenthal.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2716', 'Speyer-Germersheim Aussenstelle Germersheim', 'Johannesstr. 9-12', '67346', 'Speyer', '06232/60170', '06232/601733431', '67343', '67323', '1309', '55050000', '910', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR Telefon-Nr. Aussenstelle: 07274/9500', 'Poststelle@fa-sp.fin-rlp.de', 'www.finanzamt-speyer-germersheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2718', 'Altenkirchen-Hachenburg Aussenstelle Hachenburg', 'Frankfurter Str. 21', '57610', 'Altenkirchen', '02681/860', '02681/8610090', '57609', '57602', '1260', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR Telefon-Nr. Aussenstelle: 02662/94520', 'Poststelle@fa-ak.fin-rlp.de', 'www.finanzamt-altenkirchen-hachenburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2719', 'Kaiserslautern ', 'Eisenbahnstr. 56', '67655', 'Kaiserslautern', '0631/36760', '0631/367619500', '67653', '67621', '3360', '55050000', '901', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-kl.fin-rlp.de', 'www.finanzamt-kaiserslautern.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2721', 'Worms-Kirchheimbolanden Aussenstelle Kirchheimbolanden', 'Karlsplatz 6', '67549', 'Worms', '06241/30460', '06241/304635060', '67545', '', '', '55050000', '901', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR Telefon-Nr. Aussenstelle: 06352/4070', 'Poststelle@fa-wo.fin-rlp.de', 'www.finanzamt-worms-kirchheimbolanden.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2722', 'Koblenz ', 'Ferdinand-Sauerbruch-Str. 19', '56073', 'Koblenz', '0261/49310', '0261/493120090', '56060', '56007', '709', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-ko.fin-rlp.de', 'www.finanzamt-koblenz.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2723', 'Kusel-Landstuhl ', 'Trierer Str. 46', '66869', 'Kusel', '06381/99670', '06381/996721060', '', '66864', '1251', '55050000', '901', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-ku.fin-rlp.de', 'www.finanzamt-kusel-landstuhl.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2724', 'Landau ', 'Weißquartierstr. 13', '76829', 'Landau', '06341/9130', '06341/91322100', '76825', '76807', '1760u.1780', '55050000', '910', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-ld.fin-rlp.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2725', 'Kusel-Landstuhl Aussenstelle Landstuhl', 'Trierer Str. 46', '66869', 'Kusel', '06381/99670', '06381/996721060', '', '66864', '1251', '55050000', '901', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR Telefon-Nr. Aussenstelle: 06371/61730', 'Poststelle@fa-ku.fin-rlp.de', 'www.finanzamt-kusel-landstuhl.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2726', 'Mainz-Mitte ', 'Schillerstr. 13', '55116', 'Mainz', '06131/2510', '06131/25124090', '', '55009', '1980', '55050000', '901', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-mz.fin-rlp.de', 'www.finanzamt-mainz-mitte.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2727', 'Ludwigshafen ', 'Bayernstr. 39', '67061', 'Ludwigshafen', '0621/56140', '0621/561423051', '', '67005', '210507', '55050000', '910', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-lu.fin-rlp.de', 'www.finanzamt-ludwigshafen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2728', 'Mainz-Süd ', 'Emy-Roeder-Str. 3', '55129', 'Mainz', '06131/5520', '06131/55225272', '', '55071', '421365', '55050000', '901', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-ms.fin-rlp.de', 'www.finanzamt-mainz-sued.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2729', 'Mayen ', 'Westbahnhofstr. 11', '56727', 'Mayen', '02651/70260', '02651/702626090', '', '56703', '1363', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-my.fin-rlp.de', 'www.finanzamt-mayen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2730', 'Montabaur-Diez ', 'Koblenzer Str. 15', '56410', 'Montabaur', '02602/1210', '02602/12127099', '56409', '56404', '1461', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-mt.fin-rlp.de', 'www.finanzamt-montabaur-diez.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2731', 'Neustadt ', 'Konrad-Adenauer-Str. 26', '67433', 'Neustadt', '06321/9300', '06321/93028600', '67429', '67404', '100 465', '55050000', '910', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-nw.fin-rlp.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2732', 'Neuwied ', 'Augustastr. 54', '56564', 'Neuwied', '02631/9100', '02631/91029906', '56562', '56505', '1561', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-nr.fin-rlp.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2735', 'Pirmasens-Zweibrücken ', 'Kaiserstr. 2', '66955', 'Pirmasens', '06331/7110', '06331/71130950', '66950', '66925', '1662', '55050000', '910', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-ps.fin-rlp.de', 'www.finanzamt-pirmasens-zweibruecken.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2736', 'Bitburg-Prüm Aussenstelle Prüm', 'Kölner Str. 20', '54634', 'Bitburg', '06561/6030', '06561/60315093', '', '54622', '1252', '55050000', '902', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR Telefon-Nr. Aussenstelle: 06551/9400', 'Poststelle@fa-bt.fin-rlp.de', 'www.finanzamt-bitburg-pruem.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2738', 'Sankt Goarshausen-Sankt Goar Aussenstelle Sankt Goar', 'Wellmicher Str. 79', '56346', 'St. Goarshausen', '06771/95900', '06771/959031090', '', '56342', '', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR Telefon-Nr. Aussenstelle: 06741/98100', 'Poststelle@fa-gh.fin-rlp.de', 'www.finanzamt-sankt-goarshausen-sankt-goar.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2739', 'Sankt Goarshausen-Sankt Goar ', 'Wellmicher Str. 79', '56346', 'St. Goarshausen', '06771/95900', '06771/959031090', '', '56342', '', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-gh.fin-rlp.de', 'www.finanzamt-sankt-goarshausen-sankt-goar.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2740', 'Simmern-Zell ', 'Brühlstraße 3', '55469', 'Simmern', '06761/8550', '06761/85532053', '', '55464', '440', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-si.fin-rlp.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2741', 'Speyer-Germersheim ', 'Johannesstr. 9-12', '67346', 'Speyer', '06232/60170', '06232/601733431', '67343', '67323', '1309', '55050000', '910', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-sp.fin-rlp.de', 'www.finanzamt-speyer-germersheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2742', 'Trier ', 'Hubert-Neuerburg-Str. 1', '54290', 'Trier', '0651/93600', '0651/936034900', '', '54207', '1750u.1760', '55050000', '902', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-tr.fin-rlp.de', 'www.finanzamt-trier.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2743', 'Bernkastel-Wittlich ', 'Unterer Sehlemet 15', '54516', 'Wittlich', '06571/95360', '06571/953613400', '', '54502', '1240', '55050000', '902', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-wi.fin-rlp.de', 'www.finanzamt-bernkastel-wittlich.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2744', 'Worms-Kirchheimbolanden ', 'Karlsplatz 6', '67549', 'Worms', '06241/30460', '06241/304635060', '67545', '', '', '55050000', '901', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR', 'Poststelle@fa-wo.fin-rlp.de', 'www.finanzamt-worms-kirchheimbolanden.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2745', 'Simmern-Zell Aussenstelle Zell', 'Brühlstr. 3', '55469', 'Simmern', '06761/8550', '06761/85532053', '', '55464', '440', '55050000', '908', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR Telefon-Nr. Aussenstelle: 06542/7090', 'Poststelle@fa-si.fin-rlp.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('7', '2746', 'Pirmasens-Zweibrücken Aussenstelle Zweibrücken', 'Kaiserstr. 2', '66955', 'Pirmasens', '06331/7110', '06331/71130950', '66950', '66925', '1662', '55050000', '910', 'LRP GZ MAINZ', '', '', '', '8.00-17.00 MO-MI 8.00-18.00 DO 8.00-13.00 FR Telefon-Nr. Aussenstelle: 06332/80680', 'Poststelle@fa-ps.fin-rlp.de', 'www.finanzamt-pirmasens-zweibruecken.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2801', 'Achern ', 'Allerheiligenstr. 10', '77855', 'Achern', '07841/6940', '07841/694136', '77843', '77843', '1260', '66000000', '66001518', 'BBK KARLSRUHE', '66450050', '88013009', 'SPARKASSE OFFENBURG-ORTENAU', 'MO-DO 8-12.30+13.30-15.30,DO-17.30,FR 8-12 H', 'poststelle@fa-achern.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2804', 'Donaueschingen ', 'Käferstr. 25', '78166', 'Donaueschingen', '0771/8080', '0771/808359', '78153', '78153', '1269', '69400000', '694 01501', 'BBK VILLINGEN-SCHWENNINGEN', '69421020', '6204700600', 'BW BANK DONAUESCHINGEN', 'MO-MI 8-16 UHR, DO 8-17.30 UHR, FR 8-12 UHR', 'poststelle@fa-donaueschingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2805', 'Emmendingen ', 'Bahnhofstr. 3', '79312', 'Emmendingen', '07641/4500', '07641/450350', '79305', '79305', '1520', '68000000', '680 01507', 'BBK FREIBURG IM BREISGAU', '68050101', '20066684', 'SPK FREIBURG-NOERDL BREISGA', 'MO-MI 7:30-15:30,DO 7:30-17:00,FR 7:30-12:00', 'poststelle@fa-emmendingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2806', 'Freiburg-Stadt ', 'Sautierstr. 24', '79104', 'Freiburg', '0761/2040', '0761/2043295', '79079', '', '', '68000000', '680 01501', 'BBK FREIBURG IM BREISGAU', '68020020', '4402818100', 'BW BANK FREIBURG BREISGAU', 'MO, DI, DO 7.30-16,MI 7.30-17.30, FR 7.30-12', 'poststelle@fa-freiburg-stadt.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2807', 'Freiburg-Land ', 'Stefan-Meier-Str. 133', '79104', 'Freiburg', '0761/2040', '0761/2043424', '79095', '', '', '68000000', '680 015 00', 'BBK FREIBURG IM BREISGAU', '68090000', '12222300', 'VOLKSBANK FREIBURG', 'ZIA: MO,DI,DO 8-16, MI 8-17:30, FR 8-12 UHR', 'poststelle@fa-freiburg-land.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2808', 'Kehl ', 'Ludwig-Trick-Str. 1', '77694', 'Kehl', '07851/8640', '07851/864108', '77676', '77676', '1640', '66400000', '664 01501', 'BBK FREIBURG EH OFFENBURG', '66451862', '-6008', 'SPK HANAUERLAND KEHL', 'MO,DI,MI 7.45-15.30, DO -17.30, FR -12.00UHR', 'poststelle@fa-kehl.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2809', 'Konstanz ', 'Bahnhofplatz 12', '78462', 'Konstanz', '07531/2890', '07531/289312', '78459', '', '', '69400000', '69001500', 'BBK VILLINGEN-SCHWENNINGEN', '69020020', '6604947900', 'BW BANK KONSTANZ', 'MO,DI,DO 7.30-15.30,MI 7.30-17.00,FR 7.30-12', 'poststelle@fa-konstanz.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2810', 'Lahr ', 'Gerichtstr. 5', '77933', 'Lahr', '07821/2830', '07821/283100', '', '77904', '1466', '66000000', '66001527', 'BBK KARLSRUHE', '66450050', '76103333', 'SPARKASSE OFFENBURG-ORTENAU', 'MO,DI,DO 7:30-16:00, MI 7:30-17:30, FR 7:30-12:00', 'poststelle@fa-lahr.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2811', 'Lörrach ', 'Luisenstr. 10 a', '79539', 'Lörrach', '07621/1730', '07621/173245', '79537', '', '', '68000000', '68301500', 'BBK FREIBURG IM BREISGAU', '68320020', '4602600100', 'BW BANK LOERRACH', 'MO-MI 7.00-15.30/DO 7.00-17.30/FR 7.00-12.00', 'poststelle@fa-loerrach.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2812', 'Müllheim ', 'Goethestr. 11', '79379', 'Müllheim', '07631/18900', '(07631)189-190', '79374', '79374', '1461', '68000000', '680 01511', 'BBK FREIBURG IM BREISGAU', '68351865', '802 888 8', 'SPARKASSE MARKGRAEFLERLAND', 'MO-MI 7,30-15,30 DO 7,30-17,30 FR 7,30-12,00', 'poststelle@fa-muellheim.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2813', 'Titisee-Neustadt ', 'Goethestr. 5', '79812', 'Titisee-Neustadt', '07651/2030', '07651/203110', '', '79812', '12 69', '68000000', '680 015 10', 'BBK FREIBURG IM BREISGAU', '68051004', '4040408', 'SPK HOCHSCHWARZWALD T-NEUST', 'MO-MI 7.30-15.30,DO 7.30-17.30,FR 7.30-12.30', 'poststelle@fa-titisee-neustadt.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2814', 'Offenburg ', 'Zeller Str. 1- 3', '77654', 'Offenburg', '0781/9330', '0781/9332444', '77604', '77604', '1440', '68000000', '664 01500', 'BBK FREIBURG IM BREISGAU', '66420020', '4500000700', 'BW BANK OFFENBURG', 'MO-DO 7.30-15.30 DURCHGEHEND,MI -18.00,FR-12', 'poststelle@fa-offenburg.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2815', 'Oberndorf ', 'Brandeckerstr. 4', '78727', 'Oberndorf', '07423/8150', '07423/815107', '78721', '78721', '1240', '69400000', '694 01506', 'BBK VILLINGEN-SCHWENNINGEN', '64250040', '813 015', 'KR SPK ROTTWEIL', 'ZIA:MO,DI,DO 8-16,MI 8-17:30,FR 8-12 UHR', 'poststelle@fa-oberndorf.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2816', 'Bad Säckingen ', 'Werderstr. 5', '79713', 'Bad Säckingen', '07761/5660', '07761/566126', '79702', '79702', '1148', '68000000', '683 015 02', 'BBK FREIBURG IM BREISGAU', '', '', '', 'MO,DI,DO 8-15.30, MI 8-17.30, FR 8-12 UHR', 'poststelle@fa-badsaeckingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2818', 'Singen ', 'Alpenstr. 9', '78224', 'Singen', '07731/8230', '07731/823650', '', '78221', '380', '69000000', '69001507', 'BBK VILL-SCHWEN EH KONSTANZ', '69220020', '6402000100', 'BW BANK SINGEN', 'MO-DO 7:30-15:30, MI bis 17:30, FR 7:30-12:00', 'poststelle@fa-singen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2819', 'Rottweil ', 'Körnerstr. 28', '78628', 'Rottweil', '0741/2430', '0741/2432194', '78612', '78612', '1252', '69400000', '69401505', 'BBK VILLINGEN-SCHWENNINGEN', '64250040', '136503', 'KR SPK ROTTWEIL', 'MO-MI 8-16, DO 8-18, FR 8-12 UHR', 'poststelle@fa-rottweil.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2820', 'Waldshut-Tiengen ', 'Bahnhofstr. 11', '79761', 'Waldshut-Tiengen', '07741/6030', '07741/603213', '79753', '79753', '201360', '68000000', '68301501', 'BBK FREIBURG IM BREISGAU', '68452290', '14449', 'SPARKASSE HOCHRHEIN', 'MO-MI 8-15.30,DO 8-17.30,FR 8-12 UHR', 'poststelle@fa-waldshut-tiengen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2821', 'Tuttlingen ', 'Zeughausstr. 91', '78532', 'Tuttlingen', '07461/980', '07461/98303', '', '78502', '180', '69400000', '69401502', 'BBK VILLINGEN-SCHWENNINGEN', '64350070', '251', 'KR SPK TUTTLINGEN', 'MO-MI8-15.30,DO8-17.30,FR8-12.00UHR', 'poststelle@fa-tuttlingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2822', 'Villingen-Schwenningen ', 'Weiherstr. 7', '78050', 'Villingen-Schwenningen', '07721/923-0', '07721/923-100', '78045', '', '', '69400000', '69401500', 'BBK VILLINGEN-SCHWENNINGEN', '', '', '', 'MO-MI 8-16UHR,DO 8-17.30UHR,FR 8-12UHR', 'poststelle@fa-villingen-schwenningen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2823', 'Wolfach ', 'Hauptstr. 55', '77709', 'Wolfach', '07834/9770', '07834/977-169', '77705', '77705', '1160', '66400000', '664 01502', 'BBK FREIBURG EH OFFENBURG', '66452776', '-31956', 'SPK WOLFACH', 'MO-MI 7.30-15.30,DO 7.30-17.30,FR 7.30-12.00', 'poststelle@fa-wolfach.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2830', 'Bruchsal ', 'Schönbornstr. 1-5', '76646', 'Bruchsal', '07251/740', '07251/742111', '76643', '76643', '3021', '66000000', '66001512', 'BBK KARLSRUHE', '66350036', '50', 'SPK KRAICHGAU', 'SERVICEZENTRUM:MO-MI8-15:30DO8-17:30FR8-1200', 'poststelle@fa-bruchsal.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2831', 'Ettlingen ', 'Pforzheimer Str. 16', '76275', 'Ettlingen', '07243/5080', '07243/508295', '76257', '76257', '363', '66000000', '66001502', 'BBK KARLSRUHE', '66051220', '1043009', 'SPARKASSE ETTLINGEN', 'MO+DI 8-15.30,MI 7-15.30,DO 8-17.30,FR 8-12', 'poststelle@fa-ettlingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2832', 'Heidelberg ', 'Kurfürsten-Anlage 15-17', '69115', 'Heidelberg', '06221/590', '06221/592355', '69111', '', '', '67000000', '67001510', 'BBK MANNHEIM', '67220020', '5302059000', 'BW BANK HEIDELBERG', 'ZIA:MO-DO 7.30-15.30, MI - 17.30, FR - 12.00', 'poststelle@fa-heidelberg.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2833', 'Baden-Baden ', 'Stephanienstr. 13 + 15', '76530', 'Baden-Baden', '07221/3590', '07221/359320', '76520', '', '', '66000000', '66001516', 'BBK KARLSRUHE', '66220020', '4301111300', 'BW BANK BADEN-BADEN', 'MO,DI,DO 8-16 UHR,MI 8-17.30 UHR,FR 8-12 UHR', 'poststelle@fa-baden-baden.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2834', 'Karlsruhe-Durlach ', 'Prinzessenstr. 2', '76227', 'Karlsruhe', '0721/9940', '0721/9941235', '76225', '76203', '410326', '66000000', '66001503', 'BBK KARLSRUHE', '', '', '', 'MO-DO 8-15.30,MI 8-17.30,FR 8-12', 'poststelle@fa-karlsruhe-durlach.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2835', 'Karlsruhe-Stadt ', 'Schlossplatz 14', '76131', 'Karlsruhe', '0721/1560', '(0721) 156-1000', '', '', '', '66000000', '66001501', 'BBK KARLSRUHE', '66020020', '4002020800', 'BW BANK KARLSRUHE', 'MO-DO 7.30-15.30 MI -17.30 FR 7.30-12.00', 'poststelle@fa-karlsruhe-stadt.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2836', 'Bühl ', 'Alban-Stolz-Str. 8', '77815', 'Bühl', '07223/8030', '07223/3625', '77815', '', '', '66000000', '66001525', 'BBK KARLSRUHE', '66220020', '4301111300', 'BW BANK BADEN-BADEN', 'MO,DI,DO=8-16UHR, MI=8-17.30UHR,FR=8-12UHR', 'poststelle@fa-buehl.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2837', 'Mannheim-Neckarstadt ', 'L3, 10', '68161', 'Mannheim', '0621/2920', '0621/292-1010', '68150', '', '', '67000000', '67001500', 'BBK MANNHEIM', '67020020', '5104719900', 'BW BANK MANNHEIM', 'MO,DI,DO7.30-15.30,MI7.30-17.30,FR7.30-12.00', 'poststelle@fa-mannheim-neckarstadt.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2838', 'Mannheim-Stadt ', 'L3, 10', '68161', 'Mannheim', '0621/2920', '2923640', '68150', '', '', '67000000', '670 01500', 'BBK MANNHEIM', '67020020', '5104719900', 'BW BANK MANNHEIM', 'MO,DI,DO7.30-15.30,MI7.30.17.30,FR7.30-12.00', 'poststelle@fa-mannheim-stadt.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2839', 'Rastatt ', 'An der Ludwigsfeste 3', '76437', 'Rastatt', '07222/9780', '07222/978330', '76404', '76404', '1465', '66000000', '66001519', 'BBK KARLSRUHE', '66020020', '4150199000', 'BW BANK KARLSRUHE', 'MO-MI 8-15:30 UHR,DO 8-17:30 UHR,FR 8-12 UHR', 'poststelle@fa-rastatt.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2840', 'Mosbach ', 'Pfalzgraf-Otto-Str. 5', '74821', 'Mosbach', '06261/8070', '06261/807200', '74819', '', '', '62000000', '62001502', 'BBK HEILBRONN, NECKAR', '62030050', '5501964000', 'BW BANK HEILBRONN', 'MO-DO 08.00-16.00 UHR, DO-17.30,FR-12.00 UHR', 'poststelle@fa-mosbach.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2841', 'Pforzheim ', 'Moltkestr. 8', '75179', 'Pforzheim', '07231/1830', '(07231)183-1111', '75090', '', '', '66000000', '66001520', 'BBK KARLSRUHE', '66620020', '4812000000', 'BW BANK PFORZHEIM', 'MO-DO 7:30-15:30, DO bis 17:30, FR 7:30-12:00', 'poststelle@fa-pforzheim.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2842', 'Freudenstadt ', 'Musbacher Str. 33', '72250', 'Freudenstadt', '07441/560', '07441/561011', '', '', '', '66000000', '66001510', 'BBK KARLSRUHE', '64251060', '19565', 'KR SPK FREUDENSTADT', 'MO-MI 8.00-16.00,DO 8.00-17.30,FR 8.00-12.00', 'poststelle@fa-freudenstadt.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2843', 'Schwetzingen ', 'Schloss', '68723', 'Schwetzingen', '06202/810', '(06202) 81298', '68721', '', '', '67000000', '67001501', 'BBK MANNHEIM', '67250020', '25008111', 'SPK HEIDELBERG', 'ZIA:MO-DO 7.30-15.30,MI-17.30,FR.7.30-12.00', 'poststelle@fa-schwetzingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2844', 'Sinsheim ', 'Bahnhofstr. 27', '74889', 'Sinsheim', '07261/6960', '07261/696444', '74887', '', '', '67000000', '67001511', 'BBK MANNHEIM', '', '', '', 'MO-DO 7:30-15:30, MI bis 17:30, FR 7:30-12 UHR', 'poststelle@fa-sinsheim.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2845', 'Calw ', 'Klosterhof 1', '75365', 'Calw', '07051/5870', '07051/587111', '75363', '', '', '66000000', '66001521', 'BBK KARLSRUHE', '60651070', '1996', 'SPARKASSE PFORZHEIM CALW', 'MO-MI 7.30-15.30,DO 7.30-17.30,FR 7.30-12.00', 'poststelle@fa-calw.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2846', 'Walldürn ', 'Albert-Schneider-Str. 1', '74731', 'Walldürn', '06282/7050', '06282/705101', '74723', '74723', '1162', '62000000', '62001509', 'BBK HEILBRONN, NECKAR', '67450048', '8102204', 'SPK NECKARTAL-ODENWALD', 'MO-MI 7.30-15.30,DO 7.30-17.30,FR 7.30-12.00', 'poststelle@fa-wallduern.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2847', 'Weinheim ', 'Weschnitzstr. 2', '69469', 'Weinheim', '06201/6050', '(06201) 605-220/299 ', '69443', '69443', '100353', '67000000', '67001502', 'BBK MANNHEIM', '67050505', '63034444', 'SPK RHEIN NECKAR NORD', 'MO-MI 7.30-15.30 DO 7.30-17.30 FR 7.30-12', 'poststelle@fa-weinheim.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2848', 'Mühlacker ', 'Konrad-Adenauer-Platz 6', '75417', 'Mühlacker', '07041/8930', '07041/893999', '', '75415', '1153', '66000000', '660 015 22', 'BBK KARLSRUHE', '66650085', '961 000', 'SPARKASSE PFORZHEIM CALW', 'ZIA:MO-DO 8-12:30 13:30-15:30 DO bis 17:30 FR 8-12', 'poststelle@fa-muehlacker.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2849', 'Neuenbürg ', 'Wildbader Str. 107', '75305', 'Neuenbürg', '07082/7990', '07082/799166', '75301', '75301', '1165', '66600000', '66601503', 'BBK PFORZHEIM', '66650085', '998400', 'SPARKASSE PFORZHEIM CALW', 'MO-FR 7.30-12UHR,MO-MI 13-16UHR,DO 13-18UHR', 'poststelle@fa-neuenbuerg.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2850', 'Aalen / Württemberg ', 'Bleichgartenstr. 17', '73431', 'Aalen', '(07361) 9578-0', '(07361)9578-440', '73428', '', '', '63000000', '614 01500', 'BBK ULM, DONAU', '61450050', '110036902', 'KREISSPARKASSE OSTALB', 'MO-MI 7.30-16.00,DO 7.30-18.00,FR 7.30-12.00', 'poststelle@fa-aalen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2851', 'Backnang ', 'Stiftshof 20', '71522', 'Backnang', '07191/120', '07191/12221', '71522', '', '', '60000000', '60201501', 'BBK STUTTGART', '60250010', '244', 'KR SPK WAIBLINGEN', 'MO,DI,DO7.30-16.00MI7.30-18.00FR7.30-12.00', 'poststelle@fa-backnang.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2852', 'Bad Mergentheim ', 'Schloss 7', '97980', 'Bad Mergentheim', '07931/5300', '07931/530228', '97962', '97962', '1233', '62000000', '620 01508', 'BBK HEILBRONN, NECKAR', '67352565', '25866', 'SPK TAUBERFRANKEN', 'MO-DO 7.30-15.30,MI-17.30 UHR,FR 7.30-12 UHR', 'poststelle@fa-badmergentheim.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2853', 'Balingen ', 'Jakob-Beutter-Str. 4', '72336', 'Balingen', '07433/970', '07433/972099', '72334', '', '', '64000000', '653 01500', 'BBK REUTLINGEN', '65351260', '24000110', 'SPK ZOLLERNALB', 'Mo-Mi 7:45-16:00,Do 7:45-17:30,Fr 7:45-12:30', 'poststelle@fa-balingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2854', 'Biberach ', 'Bahnhofstr. 11', '88400', 'Biberach', '07351/590', '07351/59202', '88396', '', '', '63000000', '63001508', 'BBK ULM, DONAU', '65450070', '17', 'KR SPK BIBERACH', 'MO,DI,DO 8-15.30, MI 8-17.30, FR 8-12 UHR', 'poststelle@fa-biberach.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2855', 'Bietigheim-Bissingen ', 'Kronenbergstr. 13', '74321', 'Bietigheim-Bissingen', '07142/5900', '07142/590199', '74319', '', '', '60000000', '604 01501', 'BBK STUTTGART', '60490150', '427500001', 'VOLKSBANK LUDWIGSBURG', 'MO-MI(DO)7.30-15.30(17.30),FR 7.30-12.00 UHR', 'poststelle@fa-bietigheim-bissingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2856', 'Böblingen ', 'Talstr. 46', '71034', 'Böblingen', '(07031)13-01', '07031/13-3200', '71003', '71003', '1307', '60300000', '603 01500', 'BBK STUTTGART EH SINDELFING', '60350130', '220', 'KR SPK BOEBLINGEN', 'MO-MI 7.30-15.30,DO7.30-17.30,FR7.30-12.30', 'poststelle@fa-boeblingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2857', 'Crailsheim ', 'Schillerstr. 1', '74564', 'Crailsheim', '07951/4010', '07951/401220', '74552', '74552', '1252', '62000000', '620 01506', 'BBK HEILBRONN, NECKAR', '62250030', '282', 'SPARKASSE SCHWAEBISCH HALL', 'MO-DO:7.45-16.00,MI:-17.30,FR:7.45-12.30', 'poststelle@fa-crailsheim.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2858', 'Ehingen ', 'Hehlestr. 19', '89584', 'Ehingen', '07391/5080', '07391/508260', '89572', '89572', '1251', '63000000', '630 01502', 'BBK ULM, DONAU', '63050000', '9 300 691', 'SPARKASSE ULM', 'Mo-Mi 7.30-15.30,Do 7.30-17.30,Fr 7.30-12.00', 'poststelle@fa-ehingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2859', 'Esslingen ', 'Entengrabenstr. 11', '73728', 'Esslingen', '0711/39721', '0711/3972400', '73726', '', '', '61100000', '61101500', 'BBK STUTTGART EH ESSLINGEN', '61150020', '902139', 'KR SPK ESSLINGEN-NUERTINGEN', 'Infothek Mo-Mi 7-15.30,Do-17.30, Fr 7-12 Uhr', 'poststelle@fa-esslingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2861', 'Friedrichshafen ', 'Ehlersstr. 13', '88046', 'Friedrichshafen', '07541/7060', '07541/706111', '88041', '', '', '63000000', '65001504', 'BBK ULM, DONAU', '', '', '', 'MO-MI 8-15.30, DO 8-17.30, FR 8-12.30 Uhr', 'poststelle@fa-friedrichshafen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2862', 'Geislingen ', 'Schillerstr. 2', '73312', 'Geislingen', '07331/220', '07331/22200', '73302', '73302', '1253', '60000000', '61101504', 'BBK STUTTGART', '61050000', '6007203', 'KR SPK GOEPPINGEN', 'Mo-Mi 7-15:30, Do 7-17:30,Fr 7-12', 'poststelle@fa-geislingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2863', 'Göppingen ', 'Gartenstr. 42', '73033', 'Göppingen', '07161/63-0', '07161/632935', '', '73004', '420', '60000000', '61101503', 'BBK STUTTGART', '61050000', '1 023', 'KR SPK GOEPPINGEN', 'MO-MI.7-15.30 Uhr,DO.7-17.30 Uhr,FR.7-12 Uhr', 'poststelle@fa-goeppingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2864', 'Heidenheim ', 'Marienstr. 15', '89518', 'Heidenheim', '07321/380', '07321/381528', '89503', '89503', '1320', '63000000', '61401505', 'BBK ULM, DONAU', '63250030', '880433', 'KR SPK HEIDENHEIM', 'Mo-Mi 7.30-15.30 Do 7.30-17.30 Fr 7.30-12.30', 'poststelle@fa-heidenheim.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2865', 'Heilbronn ', 'Moltkestr. 91', '74076', 'Heilbronn', '07131/1041', '07131/1043000', '74064', '', '', '62000000', '620 01500', 'BBK HEILBRONN, NECKAR', '62050000', '123925', 'KR SPK HEILBRONN', 'Mo,Di,Do7:30-15:30,Mi7:30-17:30,Fr7:30-12:00', 'poststelle@fa-heilbronn.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2869', 'Kirchheim ', 'Alleenstr. 120', '73230', 'Kirchheim', '07021/5750', '575258', '73220', '73220', '1241', '61100000', '61101501', 'BBK STUTTGART EH ESSLINGEN', '61150020', '48317054', 'KR SPK ESSLINGEN-NUERTINGEN', 'KUNDENCENTER MO-MI 8-15.30,DO 8-17.30,FR8-12', 'poststelle@fa-kirchheim.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2870', 'Leonberg ', 'Schlosshof 3', '71229', 'Leonberg', '(07152) 15-1', '07152/15333', '71226', '', '', '60000000', '60301501', 'BBK STUTTGART', '60350130', '8619864', 'KR SPK BOEBLINGEN', 'MO-MI 7.30-15.30,DO 7.30-17.30,FR 7.30-12.30', 'poststelle@fa-leonberg.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2871', 'Ludwigsburg ', 'Alt-Württ.-Allee 40 (Neubau)', '71638', 'Ludwigsburg', '07141/180', '07141/182105', '71631', '', '', '60000000', '604 01500', 'BBK STUTTGART', '60450050', '7 759', 'KREISSPARKASSE LUDWIGSBURG', 'MO-MI 8-15.30,DO 8-18.00,FR 8-12.00', 'poststelle@fa-ludwigsburg.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2874', 'Nürtingen ', 'Sigmaringer Str. 15', '72622', 'Nürtingen', '07022/7090', '07022/709-120', '72603', '72603', '1309', '60000000', '61101502', 'BBK STUTTGART', '', '', '', 'MO-Mi 7.30-15.30 Do 7.30-17.30 Fr 7.30-12.00', 'poststelle@fa-nuertingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2876', 'Öhringen ', 'Haagweg 39', '74613', 'Öhringen', '07941/6040', '07941/604400', '74611', '', '', '62000000', '62001501', 'BBK HEILBRONN, NECKAR', '62251550', '40008', 'SPARKASSE HOHENLOHEKREIS', 'MO-DO 7.30-16.00UhrFR 7.30-12.00 Uhr', 'poststelle@fa-oehringen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2877', 'Ravensburg ', 'Broner Platz 12', '88250', 'Weingarten', '0751/4030', '403-303', '88248', '', '', '65000000', '650 015 00', 'BBK ULM EH RAVENSBURG', '65050110', '86 500 500', 'KR SPK RAVENSBURG', 'Mo,Di,Do 8-15.30Uhr,ZIA Mi 8-17.30,Fr8-12Uhr', 'poststelle@fa-ravensburg.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2878', 'Reutlingen ', 'Leonhardsplatz 1', '72764', 'Reutlingen', '07121/9400', '07121/9401002', '72705', '72705', '1543', '64000000', '64001500', 'BBK REUTLINGEN', '64050000', '64 905', 'KR SPK REUTLINGEN', 'Mo-Mi 7-15.30, Do 7-17.30, Fr 7-12.00 Uhr', 'poststelle@fa-reutlingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2879', 'Riedlingen ', 'Kirchstr. 30', '88499', 'Riedlingen', '07371/1870', '07371/1871000', '88491', '88491', '1164', '63000000', '63001509', 'BBK ULM, DONAU', '65450070', '400 600', 'KR SPK BIBERACH', 'INFOST. MO-MI 7.30-15.30,DO-17.30,FR-12 UHR', 'poststelle@fa-riedlingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2880', 'Tauberbischofsheim ', 'Dr.-Burger-Str. 1', '97941', 'Tauberbischofsheim', '09341/8040', '09341/804244', '97933', '97933', '1340', '62000000', '620 01507', 'BBK HEILBRONN, NECKAR', '67332551', '8282661100', 'BW BANK TAUBERBISCHOFSHEIM', 'MO-MI 7.30-15.30,DO 7.30-17.30,FR 7.30-12.00', 'poststelle@fa-tauberbischofsheim.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2881', 'Bad Saulgau ', 'Schulstr. 5', '88348', 'Bad Saulgau', '07581/504-0', '07581/504499', '88341', '88341', '1255', '65000000', '650 01501', 'BBK ULM EH RAVENSBURG', '65351050', '210058', 'LD BK KR SPK SIGMARINGEN', 'MO,DO,FR 8-12,DO 13.30-15.30UHR', 'poststelle@fa-badsaulgau.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2882', 'Schorndorf ', 'Johann-Philipp-Palm-Str. 28', '73614', 'Schorndorf', '07181/6010', '07181/601499', '73603', '73603', '1320', '60000000', '60201502', 'BBK STUTTGART', '60250010', '5014008', 'KR SPK WAIBLINGEN', 'MO,DI,DO 8-15.30,MI 8-17.30,FR 8-12.00', 'poststelle@fa-schorndorf.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2883', 'Schwäbisch Gmünd ', 'Augustinerstr. 6', '73525', 'Schwäbisch Gmünd', '(07171) 602-0', '07171/602266', '73522', '', '', '63000000', '61401501', 'BBK ULM, DONAU', '61450050', '440066604', 'KREISSPARKASSE OSTALB', 'MO,DI,DO 8-15.30 MI 8-17.30 FR 8-12.00 UHR', 'poststelle@fa-schwaebischgmuend.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2884', 'Schwäbisch Hall ', 'Bahnhofstr. 25', '74523', 'Schwäbisch Hall', '0791/752-0', '0791/7521115', '74502', '74502', '100260', '62000000', '62001503', 'BBK HEILBRONN, NECKAR', '62250030', '5070 011', 'SPARKASSE SCHWAEBISCH HALL', 'MO-MI 7.30-16.00 DO 7.30-17.30 FR 7.30-12.00', 'poststelle@fa-schwaebischhall.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2885', 'Sigmaringen ', 'Karlstr. 31', '72488', 'Sigmaringen', '07571/1010', '07571/101300', '72481', '72481', '1250', '65300000', '653 01501', 'BBK REUTLINGEN EH ALBSTADT', '65351050', '808 408', 'LD BK KR SPK SIGMARINGEN', 'MO-MI 7.45-15.30,DO 7.45-17.30,FR 7.45-12.00', 'poststelle@fa-sigmaringen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2886', 'Tübingen ', 'Steinlachallee 6 - 8', '72072', 'Tübingen', '07071/7570', '07071/7574500', '72005', '72005', '1520', '64000000', '64001505', 'BBK REUTLINGEN', '', '', '', 'Mo-Do 7.30-15.30,Mi -17.30,Fr 7.30-13.00 Uhr', 'poststelle@fa-tuebingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2887', 'Überlingen (Bodensee) ', 'Mühlenstr. 28', '88662', 'Überlingen', '07551/8360', '07551/836299', '88660', '', '', '69400000', '69001501', 'BBK VILLINGEN-SCHWENNINGEN', '69220020', '6426155500', 'BW BANK SINGEN', 'Mo-Mi 8.00-15.30,Do 8.00-17.30,Fr 8.00-12.00', 'poststelle@fa-ueberlingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2888', 'Ulm ', 'Wagnerstr. 2', '89077', 'Ulm', '0731/1030', '0731/103800', '', '89008', '1860', '63000000', '63001500', 'BBK ULM, DONAU', '63050000', '30001', 'SPARKASSE ULM', 'MO-MI 7.30-15.30,DO 7.30-17.30,FR 7.30-12.00', 'poststelle@fa-ulm.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2889', 'Bad Urach ', 'Graf-Eberhard-Platz 7', '72574', 'Bad Urach', '07125/1580', '(07125)158-300', '72562', '72562', '1149', '64000000', '640 01501', 'BBK REUTLINGEN', '64050000', '300 346', 'KR SPK REUTLINGEN', 'MO-MI 7.30-15.30 DO 7.30-17.30 FR 7.30-12.00', 'poststelle@fa-badurach.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2890', 'Waiblingen ', 'Fronackerstr. 77', '71332', 'Waiblingen', '07151/9550', '07151/955200', '71328', '', '', '60000000', '602 01500', 'BBK STUTTGART', '60250010', '200 398', 'KR SPK WAIBLINGEN', 'INFOTHEK MO-DO 7.30-15.30,MI-17.30,FR-12.00', 'poststelle@fa-waiblingen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2891', 'Wangen ', 'Lindauer Str.37', '88239', 'Wangen', '07522/710', '07522(714000)', '88228', '88228', '1262', '63000000', '650 01502', 'BBK ULM, DONAU', '65050110', '218 153', 'KR SPK RAVENSBURG', 'MO-MI 8-15.30, DO 8-17.30, FR 8-12 UHR', 'poststelle@fa-wangen.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2892', 'Stuttgart IV ', 'Seidenstr.23', '70174', 'Stuttgart', '0711/66730', '0711/66736060', '70049', '70049', '106052', '60000000', '600 01503', 'BBK STUTTGART', '60050101', '2 065 854', 'LANDESBANK BADEN-WUERTT', 'MO,MI,FR 8-12,MI 13.30-16 UHR', 'poststelle@fa-stuttgart4.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2893', 'Stuttgart I ', 'Rotebühlplatz 30', '70173', 'Stuttgart', '0711/66730', '6673 - 5010', '70049', '70049', '106055', '60000000', '600 01503', 'BBK STUTTGART', '60050101', '2 065 854', 'LANDESBANK BADEN-WUERTT', 'Mo,Die,Do: 8-15.30, Mi: 8-17.30, Fr: 8-12.00', 'poststelle@fa-stuttgart1.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2895', 'Stuttgart II ', 'Rotebühlstr. 40', '70178', 'Stuttgart', '0711/66730', '0711/66735610', '', '', '', '60000000', '60001503', 'BBK STUTTGART', '60050101', '2065854', 'LANDESBANK BADEN-WUERTT', 'MO-DO:8-15.30 FR:8-12 MI:15.30-17.30', 'poststelle@fa-stuttgart2.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2896', 'Stuttgart Zentrales Konzernprüfungsamt', 'Hackstr. 86', '70190', 'Stuttgart', '0711/9251-6', '0711/9251706', '', '', '', '', '', '', '', '', '', '', 'poststelle@zbp-stuttgart.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2897', 'Stuttgart III ', 'Rotebühlplatz 30', '70173', 'Stuttgart', '0711/66730', '0711/66735710', '', '70049', '106053', '60000000', '600 01503', 'BBK STUTTGART', '60050101', '2 065 854', 'LANDESBANK BADEN-WUERTT', 'Mo-Do:8-15.30 Mi:8-17.30 Fr:8-12.00 Uhr', 'poststelle@fa-stuttgart3.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('8', '2899', 'Stuttgart-Körpersch. ', 'Paulinenstr. 44', '70178', 'Stuttgart', '0711/66730', '0711/66736525', '70049', '70049', '106051', '60000000', '600 01503', 'BBK STUTTGART', '60050101', '2 065 854', 'LANDESBANK BADEN-WUERTT', 'MO-FR 8:00-12:00, MO-DO 13:00-15:30 Uhr', 'poststelle@fa-stuttgart-koerperschaften.fv.bwl.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3046', 'Potsdam-Stadt ', 'Am Bürohochhaus 2', '14478', 'Potsdam', '0331 287-0', '0331 287-1515', '', '14429', '80 03 22', '16000000', '16001501', 'BBK POTSDAM', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Potsdam-Stadt@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3047', 'Potsdam-Land ', 'Steinstr. 104 - 106', '14480', 'Potsdam', '0331 6469-0', '0331 6469-200', '', '14437', '90 01 45', '16000000', '16001502', 'BBK POTSDAM', '', '', '', 'täglich außer Mi: 08:00-12:30 Uhr, zusätzlich Di: 14:00-17:00 Uhr', 'poststelle.FA-Potsdam-Land@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3048', 'Brandenburg ', 'Magdeburger Straße 46', '14770', 'Brandenburg', '03381 397-100', '03381 397-200', '', '', '', '16000000', '16001503', 'BBK POTSDAM', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Brandenburg@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3049', 'Königs Wusterhausen ', 'Weg am Kreisgericht 9', '15711', 'Königs Wusterhausen', '03375 275-0', '03375 275-103', '', '', '', '16000000', '16001505', 'BBK POTSDAM', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Koenigs-Wusterhausen@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3050', 'Luckenwalde ', 'Industriestraße 2', '14943', 'Luckenwalde', '03371 606-0', '03371 606-200', '', '', '', '16000000', '16001504', 'BBK POTSDAM', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Luckenwalde@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3051', 'Nauen ', 'Ketziner Straße 3', '14641', 'Nauen', '03321 412-0', '03321 412-888', '', '14631', '11 61', '16000000', '16001509', 'BBK POTSDAM', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Nauen@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3052', 'Kyritz ', 'Perleberger Straße 1 - 2', '16866', 'Kyritz', '033971 65-0', '033971 65-200', '', '', '', '16000000', '16001507', 'BBK POTSDAM', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Kyritz@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3053', 'Oranienburg ', 'Heinrich-Grüber-Platz 3', '16515', 'Oranienburg', '03301 857-0', '03301 857-334', '', '', '', '16000000', '16001508', 'BBK POTSDAM', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Oranienburg@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3054', 'Pritzwalk ', 'Freyensteiner Chaussee 10', '16928', 'Pritzwalk', '03395 757-0', '03395 302110', '', '', '', '16000000', '16001506', 'BBK POTSDAM', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Pritzwalk@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3056', 'Cottbus ', 'Vom-Stein-Straße 29', '3050', 'Cottbus', '0355 4991-4100', '0355 4991-4150', '', '3004', '10 04 53', '18000000', '18001501', 'BBK COTTBUS', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Cottbus@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3057', 'Calau ', 'Springteichallee 25', '3205', 'Calau', '03541 83-0', '03541 83-100', '', '3201', '11 71', '18000000', '18001502', 'BBK COTTBUS', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Calau@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3058', 'Finsterwalde ', 'Leipziger Straße 61 - 67', '3238', 'Finsterwalde', '03531 54-0', '03531 54-180', '', '3231', '11 50', '18000000', '18001503', 'BBK COTTBUS', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Finsterwalde@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3061', 'Frankfurt (Oder) ', 'Müllroser Chaussee 53', '15236', 'Frankfurt (Oder)', '0335 560-1399', '0335 560-1202', '', '', '', '17000000', '17001502', 'BBK FRANKFURT (ODER)', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Frankfurt-Oder@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3062', 'Angermünde ', 'Jahnstraße 49', '16278', 'Angermünde', '03331 267-0', '03331 267-200', '', '', '', '17000000', '17001500', 'BBK FRANKFURT (ODER)', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Angermuende@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3063', 'Fürstenwalde ', 'Beeskower Chaussee 12', '15517', 'Fürstenwalde', '03361 595-0', '03361 2198', '', '', '', '17000000', '17001503', 'BBK FRANKFURT (ODER)', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Fuerstenwalde@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3064', 'Strausberg ', 'Prötzeler Chaussee 12 A', '15344', 'Strausberg', '03341 342-0', '03341 342-127', '', '', '', '17000000', '17001504', 'BBK FRANKFURT (ODER)', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Strausberg@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('12', '3065', 'Eberswalde ', 'Tramper Chaussee 5', '16225', 'Eberswalde', '03334 66-2000', '03334 66-2001', '', '', '', '17000000', '17001501', 'BBK FRANKFURT (ODER)', '', '', '', 'Mo, Mi, Do: 08:00-15:00 Uhr, Di: 08:00-17:00 Uhr, Fr: 08:00-13:30 Uhr', 'poststelle.FA-Eberswalde@fa.brandenburg.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3101', 'Magdeburg I ', 'Tessenowstraße 10', '39114', 'Magdeburg', '0391 885-29', '0391 885-1400', '', '39014', '39 62', '81000000', '810 015 06', 'BBK MAGDEBURG', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 14.00 - 18.00 Uhr', 'poststelle@fa-md1.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3102', 'Magdeburg II ', 'Tessenowstraße 6', '39114', 'Magdeburg', '0391 885-12', '0391 885-1000', '', '39006', '16 63', '81000000', '810 015 07', 'BBK MAGDEBURG', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 14.00 - 18.00 Uhr', 'poststelle@fa-md2.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3103', 'Genthin ', 'Berliner Chaussee 29 b', '39307', 'Genthin', '03933 908-0', '03933 908-499', '', '39302', '13 41', '81000000', '810 015 08', 'BBK MAGDEBURG', '', '', '', 'Mo., Di., Do., Fr.: 09.00 - 12.00 Uhr, Di.: 14.00 - 18.00 Uhr', 'poststelle@fa-gtn.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3104', 'Halberstadt ', 'R.-Wagner-Straße 51', '38820', 'Halberstadt', '03941 33-0', '03941 33-199', '', '38805', '15 26', '81000000', '268 015 01', 'BBK MAGDEBURG', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 14.00 - 18.00 Uhr', 'poststelle@fa-hbs.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3105', 'Haldensleben ', 'Jungfernstieg 37', '39340', 'Haldensleben', '03904 482-0', '03904 482-200', '', '39332', '10 02 09', '81000000', '810 015 10', 'BBK MAGDEBURG', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 13.00 - 18.00 Uhr', 'poststelle@fa-hdl.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3106', 'Salzwedel ', 'Buchenallee 2', '29410', 'Salzwedel', '03901 857-0', '03901 857-100', '', '29403', '21 51', '81000000', '810 015 05', 'BBK MAGDEBURG', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 14.00 - 18.00 Uhr', 'poststelle@fa-saw.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3107', 'Staßfurt ', 'Atzendorfer Straße 20', '39418', 'Staßfurt', '03925 980-0', '03925 980-101', '', '39404', '13 55', '81000000', '810 015 12', 'BBK MAGDEBURG', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 13.30 - 18.00 Uhr', 'poststelle@fa-sft.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3108', 'Stendal ', 'Scharnhorststraße 87', '39576', 'Stendal', '03931 57-1000', '03931 57-2000', '', '39551', '10 11 31', '81000000', '810 015 13', 'BBK MAGDEBURG', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 14.00 - 18.00 Uhr', 'poststelle@fa-sdl.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3109', 'Wernigerode ', 'Gustav-Petri-Straße 14', '38855', 'Wernigerode', '03943 657-0', '03943 657-150', '', '38842', '10 12 51', '81000000', '268 015 03', 'BBK MAGDEBURG', '', '', '', 'Mo., Di., Do., Fr.: 09.00 - 12.00 Uhr, Do.: 14.00 - 18.00 Uhr', 'poststelle@fa-wrg.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3110', 'Halle-Süd ', 'Blücherstraße 1', '6122', 'Halle', '0345 6923-5', '0345 6923-600', '6103', '', '', '80000000', '800 015 02', 'BBK HALLE', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 14.00 - 18.00 Uhr, Do.: 14.00', 'poststelle@fa-ha-s.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3111', 'Halle-Nord ', 'Blücherstraße 1', '6122', 'Halle', '0345 6924-0', '0345 6924-400', '6103', '', '', '80000000', '800 015 01', 'BBK HALLE', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 14.00 - 18.00 Uhr, Do.: 14.00', 'poststelle@fa-ha-n.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3112', 'Merseburg ', 'Bahnhofstraße 10', '6217', 'Merseburg', '03461 282-0', '03461 282-199', '', '6203', '13 51', '80000000', '800 015 09', 'BBK HALLE', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 13.00 - 18.00 Uhr', 'poststelle@fa-msb.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3113', 'Bitterfeld ', 'Röhrenstraße 33', '6749', 'Bitterfeld', '03493 347-0', '03493 347-247', '', '6732', '12 64', '80000000', '805 015 05', 'BBK HALLE', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 13.00 - 18.00 Uhr', 'poststelle@fa-btf.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3114', 'Dessau ', 'Kühnauer Straße 166', '6846', 'Dessau', '0340 6513-0', '0340 6513-403', '', '6815', '18 25', '80000000', '805 015 26', 'BBK HALLE', '', '', '', 'Mo. - Fr.: 08.00 - 12.00 Uhr, Di.: 13.00 - 18.00 Uhr', 'poststelle@fa-des.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3115', 'Wittenberg ', 'Dresdener Straße 40', '6886', 'Wittenberg', '03491 430-0', '03491 430-113', '', '6872', '10 02 54', '80000000', '805 015 07', 'BBK HALLE', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 13.00 - 18.00 Uhr', 'poststelle@fa-wbg.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3116', 'Köthen ', 'Zeppelinstraße 15', '6366', 'Köthen', '03496 44-0', '03496 44-2900', '', '6354', '14 52', '80000000', '805 015 06', 'BBK HALLE', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 14.00 - 18.00 Uhr', 'poststelle@fa-kot.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3117', 'Quedlinburg ', 'Adelheidstraße 2', '6484', 'Quedlinburg', '03946 976-0', '03946 976-400', '', '6472', '14 20', '81000000', '268 015 02', 'BBK MAGDEBURG', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 13.00 - 17.30 Uhr', 'poststelle@fa-qlb.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3118', 'Eisleben ', 'Bahnhofsring 10 a', '6295', 'Eisleben', '03475 725-0', '03475 725-109', '6291', '', '', '80000000', '800 015 08', 'BBK HALLE', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 13.00 - 18.00 Uhr', 'poststelle@fa-eil.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3119', 'Naumburg ', 'Oststraße 26/26 a', '6618', 'Naumburg', '03445 753-0', '03445 753-999', '', '6602', '12 51', '80000000', '800 015 27', 'BBK HALLE', '', '', '', 'Mo., Di., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 13.00 - 18.00 Uhr', 'poststelle@fa-nbg.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3120', 'Zeitz ', 'Friedensstraße 80', '6712', 'Zeitz', '03441 864-0', '03441 864-480', '', '6692', '12 08', '80000000', '800 015 04', 'BBK HALLE', '', '', '', 'Mo., Do., Fr.: 08.00 - 12.00 Uhr, Di.: 08.00 - 18.00 Uhr', 'poststelle@fa-ztz.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('15', '3121', 'Sangerhausen ', 'Alte Promenade 27', '6526', 'Sangerhausen', '03464 539-0', '03464 539-539', '', '6512', '10 12 24', '80000000', '800 015 25', 'BBK HALLE', '', '', '', 'Di., Do., Fr.: 09.00 - 12.00 Uhr, Di.: 14.00 - 18.00 Uhr, Do.: 14.00 -', 'poststelle@fa-sgh.ofd.mf.lsa-net.de', 'http://www.finanzamt.sachsen-anhalt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3201', 'Dresden I ', 'Lauensteiner Str. 37', '1277', 'Dresden', '0351 2567-0', '0351 2567-111', '1264', '', '', '85000000', '85001502', 'BBK DRESDEN', '', '', '', 'Mo 8:00-15:00, Di 8:00-18:00, Mi 8:00-15:00, Do 8:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-dresden1.smf.sachsen.de', 'http://www.Finanzamt-Dresden-I.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3202', 'Dresden II ', 'Gutzkowstraße 10', '1069', 'Dresden', '0351 4655-0', '0351 4655-269', '1056', '', '', '85000000', '85001503', 'BBK DRESDEN', '', '', '', 'Mo - Fr 8:00-12:00 Uhr, Di 14:00-18:00, Do 14:00-18:00 Uhr', 'poststelle@fa-dresden2.smf.sachsen.de', 'http://www.Finanzamt-Dresden-II.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3203', 'Dresden III ', 'Rabenerstr.1', '1069', 'Dresden', '0351 4691-0', '0351 4717 369', '', '1007', '120641', '85000000', '85001504', 'BBK DRESDEN', '', '', '', 'Mo 8:00-15:00, Di 8:00-18:00, Mi 8:00-15:00, Do 8:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-dresden3.smf.sachsen.de', 'http://www.Finanzamt-Dresden-III.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3204', 'Bautzen ', 'Wendischer Graben 3', '2625', 'Bautzen', '03591 488-0', '03591 488-888', '2621', '', '', '85000000', '85001505', 'BBK DRESDEN', '', '', '', 'Mo 8:00-15:30, Di 8:00-17:00, Mi 8:00-15:30, Do 8:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-bautzen.smf.sachsen.de', 'http://www.Finanzamt-Bautzen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3205', 'Bischofswerda ', 'Kirchstraße 25', '1877', 'Bischofswerda', '03594 754-0', '03594 754-444', '', '1871', '1111', '85000000', '85001506', 'BBK DRESDEN', '', '', '', 'Mo 8:00-15:30, Di 8:00-17:00, Mi 8:00-15:30, Do 8:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-bischofswerda.smf.sachsen.de', 'http://www.Finanzamt-Bischofswerda.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3206', 'Freital ', 'Coschützer Straße 8-10', '1705', 'Freital', '0351 6478-0', '0351 6478-428', '', '1691', '1560', '85000000', '85001507', 'BBK DRESDEN', '', '', '', 'Mo 8:00-15:00, Di 8:00-18:00, Mi 8:00-15:00, Do 8:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-freital.smf.sachsen.de', 'http://www.Finanzamt-Freital.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3207', 'Görlitz ', 'Sonnenstraße 7', '2826', 'Görlitz', '03581 875-0', '03581 875-100', '', '2807', '300235', '85000000', '85001512', 'BBK DRESDEN', '', '', '', 'Mo 8:00-15:30, Di 8:00-18:00, Mi 8:00-15:30, Do 8:00-17:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-goerlitz.smf.sachsen.de', 'http://www.Finanzamt-Goerlitz.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3208', 'Löbau ', 'Georgewitzer Str.40', '2708', 'Löbau', '03585 455-0', '03585 455-100', '', '2701', '1165', '85000000', '85001509', 'BBK DRESDEN', '', '', '', 'Mo 8:00-15:30, Di 8:00-18:00, Mi 8:00-15:30, Do 8:00-17:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-loebau.smf.sachsen.de', 'http://www.Finanzamt-Loebau.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3209', 'Meißen ', 'Hermann-Grafe-Str.30', '1662', 'Meißen', '03521 745-30', '03521 745-450', '', '1651', '100151', '85000000', '85001508', 'BBK DRESDEN', '', '', '', 'Mo - Fr 8:00-12:00 Uhr Di 13:00-18:00, Do 13:00-17:00 Uhr', 'poststelle@fa-meissen.smf.sachsen.de', 'http://www.Finanzamt-Meissen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3210', 'Pirna ', 'Emil-Schlegel-Str. 11', '1796', 'Pirna', '03501 551-0', '03501 551-201', '', '1781', '100143', '85000000', '85001510', 'BBK DRESDEN', '', '', '', 'Mo - Fr 8:00-12:00 Uhr, Di 13:30-18:00, Do 13:30-17:00 Uhr', 'poststelle@fa-pirna.smf.sachsen.de', 'http://www.Finanzamt-Pirna.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3211', 'Riesa ', 'Stahlwerkerstr.3', '1591', 'Riesa', '03525 714-0', '03525 714-133', '', '1571', '24', '85000000', '85001511', 'BBK DRESDEN', '', '', '', 'Mo 8:00-15:30, Di 8:00-18:00, Mi 8:00-15:30, Do 8:00-17:00 , Fr 8:00-12:00 Uhr', 'poststelle@fa-riesa.smf.sachsen.de', 'http://www.Finanzamt-Riesa.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3213', 'Hoyerswerda ', 'Pforzheimer Platz 1', '2977', 'Hoyerswerda', '03571 460-0', '03571 460-115', '', '2961', '1161/1162 ', '85000000', '85001527', 'BBK DRESDEN', '', '', '', 'Mo 7:30-15:30, Di 7:30-17:00, Mi 7:30-13:00, Do 7:30-18:00, Fr 7:30-12:00 Uhr', 'poststelle@fa-hoyerswerda.smf.sachsen.de', 'http://www.Finanzamt-Hoyerswerda.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3214', 'Chemnitz-Süd ', 'Paul-Bertz-Str. 1', '9120', 'Chemnitz', '0371 279-0', '0371 227065', '9097', '', '', '87000000', '87001501', 'BBK CHEMNITZ', '', '', '', 'Mo 8:00-16:00, Di 8:00-18:00, Mi 8:00-13:00, Do 8:00-18:00, Fr 8:00-13:00 Uhr', 'poststelle@fa-chemnitz-sued.smf.sachsen.de', 'http://www.Finanzamt-Chemnitz-Sued.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3215', 'Chemnitz-Mitte ', 'August-Bebel-Str. 11/13', '9113', 'Chemnitz', '0371 467-0', '0371 415830', '9097', '', '', '87000000', '87001502', 'BBK CHEMNITZ', '', '', '', 'Mo 8:00-16:00, Di 8:00-18:00, Mi 8:00-14:00, Do 8:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-chemnitz-mitte.smf.sachsen.de', 'http://www.Finanzamt-Chemnitz-Mitte.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3216', 'Chemnitz-Land ', 'Reichenhainer Str. 31-33', '9126', 'Chemnitz', '0371 5360-0', '0371 5360-317', '9097', '', '', '87000000', '87001503', 'BBK CHEMNITZ', '', '', '', 'täglich 8:00-12:00, Di 13:30-17.00, Do 13:30-18:00 Uhr', 'poststelle@fa-chemnitz-land.smf.sachsen.de', 'http://www.Finanzamt-Chemnitz-Land.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3217', 'Annaberg ', 'Magazingasse 16', '9456', 'Annaberg-B.', '03733 4270', '03733 427-217', '', '9453', '100631', '87000000', '87001504', 'BBK CHEMNITZ', '', '', '', 'Mo 8:00-15:30, Di 8:00-18:00, Mi 8:00-15:30, Do 8:00-17:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-annaberg.smf.sachsen.de', 'http://www.Finanzamt-Annaberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3218', 'Schwarzenberg ', 'Karlsbader Str.23', '8340', 'Schwarzenberg', '03774 161-0', '03774 161-100', '', '8332', '1209', '87000000', '87001505', 'BBK CHEMNITZ', '', '', '', 'Mo 8:00-15:30, Di 8:00-18:00, Mi 8:00-15:30, Do 8:00-17:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-schwarzenberg.smf.sachsen.de', 'http://www.Finanzamt-Schwarzenberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3219', 'Auerbach ', 'Schulstraße 3, Haus 1', '8209', 'Auerbach', '03744 824-0', '03744 824-200', '', '8202', '10132', '87000000', '87001506', 'BBK CHEMNITZ', '', '', '', 'Mo 7:30-15:30, Di 7:30-18:00, Mi 7:30-12:00, Do 7:30-18:00, Fr 7:30-12:00 Uhr', 'poststelle@fa-aucherbach.smf.sachsen.de', 'http://www.Finanzamt-Auerbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3220', 'Freiberg ', 'Brückenstr.1', '9599', 'Freiberg', '03731 379-0', '03731 379-999', '9596', '', '', '87000000', '87001507', 'BBK CHEMNITZ', '', '', '', 'Mo - Fr 7:30-12:30, Mo 13:30-15:30, Di 13:00-18:00, Mi 13:30-15:30, Do 13:00-17:00 Uhr', 'poststelle@fa-freiberg.smf.sachsen.de', 'http://www.Finanzamt-Freiberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3221', 'Hohenstein-Ernstthal ', 'Schulstraße 34', '9337', 'Hohenstein-E.', '03723 745-0', '03723 745-399', '', '9332', '1246', '87000000', '87001510', 'BBK CHEMNITZ', '', '', '', 'Mo - Fr 8:00-12:00, Mo 12:30-15:30, Di 12:30-18:00, Do 12:30-17:00', 'poststelle@fa-hohenstein-ernstthal.smf.sachsen.de', 'http://www.Finanzamt-Hohenstein-Ernstthal.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3222', 'Mittweida ', 'Robert-Koch-Str. 17', '9648', 'Mittweida', '03727 987-0', '03727 987-333', '', '9641', '1157', '87000000', '87001509', 'BBK CHEMNITZ', '', '', '', 'Mo 7:30-15:00, Di 7:30-18:00, Mi 7:30-13:00, Do 7:30-18:00, Fr 7:30-12:00 Uhr', 'poststelle@fa-mittweida.smf.sachsen.de', 'http://www.Finanzamt-Mittweida.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3223', 'Plauen ', 'Europaratstraße 17', '8523', 'Plauen', '03741 10-0', '03741 10-2000', '', '8507', '100384', '87000000', '87001512', 'BBK CHEMNITZ', '', '', '', 'Mo 7:30-14:00, Di 7:30-18:00, Mi 7:30-14:00, Do 7:30-18:00, Fr 7:30-12:00 Uhr', 'poststelle@fa-plauen.smf.sachsen.de', 'http://www.Finanzamt-Plauen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3224', 'Stollberg ', 'HOHENSTEINER STRASSE 54', '9366', 'Stollberg', '037296 522-0', '037296 522-199', '', '9361', '1107', '87000000', '87001508', 'BBK CHEMNITZ', '', '', '', 'Mo 7:30-15:30, Di 7:30-17:00, Mi 7:30-13:00, Do 7:30-18:00, Fr 7:30-12:00 Uhr', 'poststelle@fa-stollberg.smf.sachsen.de', 'http://www.Finanzamt-Stollberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3226', 'Zwickau-Stadt ', 'Dr.-Friedrichs-Ring 21', '8056', 'Zwickau', '0375 3529-0', '0375 3529-444', '', '8070', '100452', '87000000', '87001513', 'BBK CHEMNITZ', '', '', '', 'Mo 7:30-15:30, Di 7:30-18:00, Mi 7:30-12:00, Do 7:30-18:00, Fr 7:30-12:00 Uhr', 'poststelle@fa-zwickau-stadt.smf.sachsen.de', 'http://www.Finanzamt-Zwickau-Stadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3227', 'Zwickau-Land ', 'Äußere Schneeberger Str. 62', '8056', 'Zwickau', '0375 4440-0', '0375 4440-222', '', '8067', '100150', '87000000', '87001514', 'BBK CHEMNITZ', '', '', '', 'Mo 8:00-15:30, Di 8:00-18:00, Mi 8:00-15:30, Do 8:00-17:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-zwickau-land.smf.sachsen.de', 'http://www.Finanzamt-Zwickau-Land.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3228', 'Zschopau ', 'August-Bebel-Str.17', '9405', 'Zschopau', '03725 293-0', '03725 293-111', '', '9402', '58', '87000000', '87001515', 'BBK CHEMNITZ', '', '', '', 'Mo7:30-12:00/13:00-16:30,Di 7:30-12:00/13:00-18:00Mi u. Fr 7:30-13:00, Do 7:30-12:00/13:00-18:00 Uhr', 'poststelle@fa-zschopau.smf.sachsen.de', 'http://www.Finanzamt-Zschopau.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3230', 'Leipzig I ', 'Wilhelm-Liebknecht-Platz 3/4', '4105', 'Leipzig', '0341 559-0', '0341 559-1540', '', '4001', '100105', '86000000', '86001501', 'BBK LEIPZIG', '', '', '', 'Mo 7:30-14:00, Di 7:30-18:00, Mi 7:30-14:00, Do 7:30-18:00, Fr 7:30-12:00 Uhr', 'poststelle@fa-leipzig1.smf.sachsen.de', 'http://www.Finanzamt-Leipzig-I.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3231', 'Leipzig II ', 'Erich-Weinert-Str. 20', '4105', 'Leipzig', '0341 559-0', '0341 559-2505', '', '4001', '100145', '86000000', '86001502', 'BBK LEIPZIG', '', '', '', 'Mo 7:30-14:00, Di 7:30-18:00, Mi 7:30-14:00, Do 7:30-18:00, Fr 7:30-12:00 Uhr', 'poststelle@fa-leipzig2.smf.sachsen.de', 'http://www.Finanzamt-Leipzig-II.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3232', 'Leipzig III ', 'Wilhelm-Liebknecht-Platz 3/4', '4105', 'Leipzig', '0341 559-0', '0341 559-3640', '', '4002', '100226', '86000000', '86001503', 'BBK LEIPZIG', '', '', '', 'Mo 7:30-14:00, Di 7:30-18:00, Mi 7:30-14:00, Do 7:30-18:00, Fr 7:30-12:00 Uhr', 'poststelle@fa-leipzig3.smf.sachsen.de', 'http://www.Finanzamt-Leipzig-III.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3235', 'Borna ', 'Brauhausstr.8', '4552', 'Borna', '03433 872-0', '03433 872-255', '', '4541', '1325', '86000000', '86001509', 'BBK LEIPZIG', '', '', '', 'Mo 8:00-15:00, Di 8:00-18:00, Mi 8:00-15:00, Do 8:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-borna.smf.sachsen.de', 'http://www.Finanzamt-Borna.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3236', 'Döbeln ', 'Burgstr.31', '4720', 'Döbeln', '03431 653-30', '03431 653-444', '', '4713', '2346', '86000000', '86001507', 'BBK LEIPZIG', '', '', '', 'Mo 7:30-15:30, Di 7:30-18:00, Mi 7:30-13:00, Do 7:30-17:00, Fr 7:30-12:00 Uhr', 'poststelle@fa-doebeln.smf.sachsen.de', 'http://www.Finanzamt-Doebeln.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3237', 'Eilenburg ', 'Walther-Rathenau-Straße 8', '4838', 'Eilenburg', '03423 660-0', '03423 660-460', '', '4831', '1133', '86000000', '86001506', 'BBK LEIPZIG', '', '', '', 'Mo 8:00-16:00, Di 8:00-18:00, Mi 8:00-14:00, Do 8:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-eilenburg.smf.sachsen.de', 'http://www.Finanzamt-Eilenburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3238', 'Grimma ', 'Lausicker Straße 2', '4668', 'Grimma', '03437 940-0', '03437 940-500', '', '4661', '1126', '86000000', '86001508', 'BBK LEIPZIG', '', '', '', 'Mo 7:30-15:00, Di 7:30-18:00, Mi 7:30-13:30, Do 7:30-17:00, Fr 7:30-12:00 Uhr', 'poststelle@fa-grimma.smf.sachsen.de', 'http://www.Finanzamt-Grimma.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('14', '3239', 'Oschatz ', 'Dresdener Str.77', '4758', 'Oschatz', '03435 978-0', '03435 978-366', '', '4752', '1265', '86000000', '86001511', 'BBK LEIPZIG', '', '', '', 'Mo 8:00-16:00, Di 8:00-17:00, Mi 8:00-15:00, Do 8:00-18:00, Fr 8:00-12:00 Uhr', 'poststelle@fa-oschatz.smf.sachsen.de', 'http://www.Finanzamt-Oschatz.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4071', 'Malchin ', 'Schratweg 33', '17139', 'Malchin', '03994/6340', '03994/634322', '', '17131', '1101', '15000000', '15001511', 'BBK NEUBRANDENBURG', '', '', '', 'Mo Di Fr 08-12 Uhr Di 13-17 Uhr und Do 13-16 UhrMittwoch geschlossen', 'poststelle@fa-mc.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4072', 'Neubrandenburg ', 'Neustrelitzer Str. 120', '17033', 'Neubrandenburg', '0395/380 1000', '0395/3801059', '', '17041', '110164', '15000000', '15001518', 'BBK NEUBRANDENBURG', '', '', '', 'Mo Di Do Fr 08-12 Uhr und Di 13.00-17.30 Uhr Mittwoch geschlossen', 'poststelle@fa-nb.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4074', 'Pasewalk ', 'Torgelower Str. 32', '17309', 'Pasewalk', '(03973) 224-0', '03973/2241199', '', '17301', '1102', '15000000', '15001512', 'BBK NEUBRANDENBURG', '', '', '', 'Mo bis Fr 09.00-12.00 Uhr Di 14.00-18.00 Uhr', 'poststelle@fa-pw.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4075', 'Waren ', 'Einsteinstr. 15', '17192', 'Waren (Müritz)', '03991/1740', '(03991)174499', '', '17183', '3154', '15000000', '15001515', 'BBK NEUBRANDENBURG', '', '', '', 'Mo-Mi 08.00-16.00 Uhr Do 08.00-18.00 Uhr Fr 08.-13.00 Uhr', 'poststelle@fa-wrn.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4079', 'Rostock ', 'Möllner Str. 13', '18109', 'Rostock', '(0381)7000-0', '(0381)7000444', '', '18071', '201062', '13000000', '13001508', 'BBK ROSTOCK', '', '', '', 'Mo Di Fr 8.30-12.00 Di 13.30-17.00 Do 13.30-16.00', 'poststelle@fa-hro.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4080', 'Wismar ', 'Philosophenweg 1', '23970', 'Wismar', '03841444-0', '03841/444222', '', '', '', '14000000', '14001516', 'BBK SCHWERIN', '', '', '', 'Mo Di Fr 08.00-12.00 Uhr Di Do 14.00-17.00 Uhr Mittwoch geschlossen', 'poststelle@fa-wis.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4081', 'Ribnitz-Damgarten ', 'Sandhufe 3', '18311', 'Ribnitz-Damgarten', '(03821)884-0', '(03821)884140', '', '18301', '1061', '13000000', '13001510', 'BBK ROSTOCK', '', '', '', 'MO Di Mi DO 08.30-12.00 UHR DI 13.00-17.00 UHR Freitag geschlossen', 'poststelle@fa-rdg.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4082', 'Stralsund ', 'Lindenstraße 136', '18435', 'Stralsund', '03831/3660', '(03831)366245 / 188 ', '', '18409', '2241', '13000000', '13001513', 'BBK ROSTOCK', '', '', '', 'Mo Di Do Fr 08.00-12.00 Uhr Di 14.00 - 18.00 UhrMittwoch geschlossen', 'poststelle@fa-hst.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4083', 'Bergen ', 'Wasserstr. 15 d', '18528', 'Bergen (Rügen)', '03838/4000', '03838/22217', '18522', '18522', '1242', '13000000', '13001512', 'BBK ROSTOCK', '', '', '', 'Mo Di Do Fr 8.30-12.00 Di 13.00-18.00 Mittwoch geschlossen', 'poststelle@fa-brg.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4084', 'Greifswald ', 'Am Gorzberg Haus 11', '17489', 'Greifswald', '03834/5590', '03834-559315/316', '17462', '17462', '3254', '15000000', '15001528', 'BBK NEUBRANDENBURG', '', '', '', 'Mo Di Do Fr 8.30-12.00 Uhr Di 13.00-17.30 Uhr Mittwoch geschlossen', 'poststelle@fa-hgw.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4085', 'Wolgast ', 'Pestalozzistr. 45', '17438', 'Wolgast', '03836/254-0', '03836/254300 /254100', '', '17431', '1139', '15000000', '15001529', 'BBK NEUBRANDENBURG', '', '', '', 'Mo Di Mi Do Fr 08.00-12.00 Uhr', 'poststelle@fa-wlg.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4086', 'Güstrow ', 'Klosterhof 1', '18273', 'Güstrow', '03843/2620', '03843/262111', '18271', '', '', '13000000', '13001501', 'BBK ROSTOCK', '', '', '', 'Mo-Do 09.00-12.00 Uhr Do 13.00-18.00 Uhr Freitag geschlossen', 'poststelle@fa-gue.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4087', 'Hagenow ', 'Steegener Chaussee 8', '19230', 'Hagenow', '03883/6700', '03883 670216 /670217', '', '19222', '1242', '14000000', '14001504', 'BBK SCHWERIN', '', '', '', 'Mo Di Do Fr 08.30-12.00 Di 13.00-17.30 Mittwoch geschlossen', 'poststelle@fa-hgn.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4089', 'Parchim ', 'Ludwigsluster Chaussee 5', '19370', 'Parchim', '03871/4650', '03871/443131', '', '19363', '1351', '14000000', '14001506', 'BBK SCHWERIN', '', '', '', 'Mo Di Mi 08.30-15.00 Uhr Do 08.30-18.00 Uhr Fr 08.30-13.00 Uhr', 'poststelle@fa-pch.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('13', '4090', 'Schwerin ', 'Johannes-Stelling-Str.9-11', '19053', 'Schwerin', '0385/54000', '0385/5400300', '', '19091', '160131', '14000000', '14001502', 'BBK SCHWERIN', '', '', '', ' Di Do Fr 08.30 - 12.00 Uhr Mo 13.00 - 16.00 Uhr Do 14.00', 'poststelle@fa-sn.ofd-hro.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4151', 'Erfurt ', 'Mittelhäuser Str. 64f', '99091', 'Erfurt', '(0361)378-00', '0361/3782800', '', '99001', '100121', '82050000', '3001111586', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'DI. 8- 12/ 13.30 -18 MI./FR. 8 - 12 UHR', 'poststelle@finanzamt-erfurt.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4152', 'Sömmerda ', 'Uhlandstrasse 3', '99610', 'Sömmerda', '03634/363-0', '03634/363200', '', '99609', '100', '82050000', '3001111628', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO/MI/DO 8-16 UHR DI 8-18,FR 8-12 UHR', 'poststelle@finanzamt-soemmerda.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4153', 'Weimar ', 'Jenaer Str.2a', '99425', 'Weimar', '03643/5500', '(03643)903811', '', '99421', '3676', '82050000', '3001111586', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO,MI,DO 8-15.30 UHR DI 8-18,FR 8-12 UHR', 'poststelle@finanzamt-weimar.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4154', 'Ilmenau ', 'Wallgraben 1', '98693', 'Ilmenau', '(03677) 861-0', '03677/861111', '', '98686', '100754', '82050000', '3001111685', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO,MI 8-15.30 UHR, DI 8-18 UHR DO 8-16 UHR, FR 8-12 UHR', 'poststelle@finanzamt-ilmenau.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4155', 'Eisenach ', 'Ernst-Thaelmann-Str. 70', '99817', 'Eisenach', '03691/687-0', '03691/687250', '', '99804', '101454', '82050000', '3001111586', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO-FR: 8-12 UHR, MO-MI: 13-16 UHR, DO: 13-18 UHR', 'poststelle@finanzamt-eisenach.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4156', 'Gotha ', 'Reuterstr. 2a', '99867', 'Gotha', '(03621)33-0', '03621/332000', '', '99853', '100301', '82050000', '3001111586', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO - MI 8-15.30 UHR DO 8-18,FR 8-12 UHR', 'poststelle@finanzamt-gotha.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4157', 'Mühlhausen ', 'Martinistr. 22', '99974', 'Mühlhausen', '(03601)456-0', '03601/456100', '', '99961', '1155', '82050000', '3001111628', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO/MI/DO 7.30-15 UHR DI.7.30-18,FR.7.30-12', 'poststelle@finanzamt-muehlhausen.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4158', 'Nordhausen ', 'Gerhart-Hauptmann-Str. 3', '99734', 'Nordhausen', '03631/427-0', '03631/427174', '', '99729', '1120', '82050000', '3001111628', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO,DI,MI 8-12, 13.30-16 UHR DO 8-12,14-18 FR 8-12 UHR', 'poststelle@finanzamt-nordhausen.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4159', 'Sondershausen ', 'Schillerstraße 6', '99706', 'Sondershausen', '(03632)742-0', '03632/742555', '', '99702', '1265', '82050000', '3001111628', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO/MI/DO 8-15.30 UHR DI 8-18, FR 8-12 UHR', 'poststelle@finanzamt-sondershausen.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4160', 'Worbis ', 'Bahnhofstr. 18', '37339', 'Worbis', '036074/37-0', '036074/37219', '', '37334', '173', '82050000', '3001111628', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO-MI 7.30-15 UHR DO 7.30-18,FR 7.30-12', 'poststelle@finanzamt-worbis.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4161', 'Gera ', 'Hermann-Drechsler-Str.1', '7548', 'Gera', '0365/639-0', '0365/6391491', '', '7490', '3044', '82050000', '3001111578', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO,MI 7.30-15 DI,DO 7.30- 18 UHR FR 7.30-12 UHR', 'poststelle@finanzamt-gera.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4162', 'Jena ', 'Leutragraben 8', '7743', 'Jena', '(03641)378-0', '03641/378653', '', '7740', '500', '82050000', '3001111602', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO-MI 8-15.30 DO 8-18 FR 8-12.00UHR', 'poststelle@finanzamt-jena.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4163', 'Rudolstadt ', 'Mörlaer Str. 2', '7407', 'Rudolstadt', '(03672)443-0', '(03672)443100', '', '7391', '100155', '82050000', '3001111578', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO-MI 7.30-12, 13-15 DO 7.30-12, 13-18 UHR FR 7.30-12 UHR', 'poststelle@finanzamt-rudolstadt.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4164', 'Greiz ', 'Rosa-Luxemburg-Str. 23', '7973', 'Greiz', '03661/700-0', '03661/700300', '', '7962', '1365', '82050000', '3001111578', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO/DI/MI 8-16UHR DO 8-18,FR 8-12UHR', 'poststelle@finanzamt-greiz.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4165', 'Pößneck ', 'Gerberstr. 65', '7381', 'Pößneck', '(03647)446-0', '(03647)446430', '', '7372', '1253', '82050000', '3001111578', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO-FR 8-12 MO,MI,DO 13-15 UHR DI 13-18 UHR', 'poststelle@finanzamt-poessneck.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4166', 'Altenburg ', 'Wenzelstr. 45', '4600', 'Altenburg', '03447/593-0', '03447/593200', '', '4582', '1251', '82050000', '3001111511', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO,MI,DO 7.30-15.30 DI 7.30-18 UHR FR 7.30-12 UHR', 'poststelle@finanzamt-altenburg.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4168', 'Bad Salzungen ', 'August-Bebel-Str.2', '36433', 'Bad Salzungen', '(03695)668-0', '03695/622496', '', '36421', '1153', '82050000', '3001111586', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO-MI 7.30-15 UHR DO 7.30-18,FR 7.30-12', 'poststelle@finanzamt-badsalzungen.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4169', 'Meiningen ', 'Charlottenstr. 2', '98617', 'Meiningen', '03693/461-0', '(03693)461322', '', '98606', '100661', '82050000', '3001111610', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO-MI 7.30-15 UHR DO 7.30-18,FR 7.30-12', 'poststelle@finanzamt-meiningen.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4170', 'Sonneberg ', 'Köppelsdorfer Str.86', '96515', 'Sonneberg', '03675/884-0', '03675/884254', '', '96502', '100241', '82050000', '3001111685', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO-MI 7.30-15.00 UHR DO 7.30-18 FR 7.30-12', 'poststelle@finanzamt-sonneberg.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('16', '4171', 'Suhl ', 'Karl-Liebknecht-Str. 4', '98527', 'Suhl', '03681/73-0', '03681/733512', '', '98490', '100153', '82050000', '3001111685', 'LD BK HESS-THUER GZ ERFURT', '', '', '', 'MO - MI 8-16 UHR, DO 8-13 u. 14-18 UHR , FR 8-12 UHR', 'poststelle@finanzamt-suhl.thueringen.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5101', 'Dinslaken ', 'Schillerstr. 71', '46535', 'Dinslaken', '02064/445-0', '0800 10092675101', '', '46522', '100220', '35000000', '35201501', 'BBK DUISBURG', '35251000', '100123', 'SPK DINSLAKEN-VOERDE-HUENXE', 'Mo-Fr 08.30-12.00 Uhr,Di auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5101.fin-nrw.de', 'www.finanzamt-Dinslaken.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5102', 'Viersen ', 'Eindhovener Str. 71', '41751', 'Viersen', '02162/955-0', '0800 10092675102', '', '41726', '110263', '31000000', '31001503', 'BBK MOENCHENGLADBACH', '32050000', '59203406', 'SPARKASSE KREFELD', 'Mo-Fr 8:30 bis 12:00 Uhr,Di auch 13:30 bis 15:00 Uhr,und nach Vereinbarung', 'Service@FA-5102.fin-nrw.de', 'www.finanzamt-Viersen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5103', 'Düsseldorf-Altstadt ', 'Kaiserstr. 52', '40479', 'Düsseldorf', '0211/4974-0', '0800 10092675103', '', '40001', '101021', '30000000', '30001504', 'BBK DUESSELDORF', '30050110', '10124006', 'ST SPK DUESSELDORF', 'Mo-Fr 08.30 - 12.00 Uhr,Di auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5103.fin-nrw.de', 'www.finanzamt-Duesseldorf-Altstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5105', 'Düsseldorf-Nord ', 'Roßstr. 68', '40476', 'Düsseldorf', '0211/4496-0', '0800 10092675105', '', '40403', '300314', '30000000', '30001501', 'BBK DUESSELDORF', '30050110', '10124501', 'ST SPK DUESSELDORF', 'Mo-Fr 08.30-12.00 Uhr,Di auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5105.fin-nrw.de', 'www.finanzamt-Duesseldorf-Nord.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5106', 'Düsseldorf-Süd ', 'Kruppstr.110- 112', '40227', 'Düsseldorf', '0211/779-9', '0800 10092675106', '', '40001', '101025', '30000000', '30001502', 'BBK DUESSELDORF', '30050110', '10125003', 'ST SPK DUESSELDORF', 'Mo-Fr 8.30-12.00 Uhr,Di auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5106.fin-nrw.de', 'www.finanzamt-Duesseldorf-Sued.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5107', 'Duisburg-Hamborn ', 'Hufstr. 25', '47166', 'Duisburg', '0203/5445-0', '0800 10092675107', '', '47142', '110264', '35000000', '35001502', 'BBK DUISBURG', '', '', '', 'Mo-Fr 08.30 - 12.00 Uhr,Di auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5107.fin-nrw.de', 'www.finanzamt-Duisburg-Hamborn.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5109', 'Duisburg-Süd ', 'Landfermannstr 25', '47051', 'Duisburg', '0203/3001-0', '0800 10092675109', '', '47015', '101502', '35000000', '35001500', 'BBK DUISBURG', '35050000', '200403020', 'SPK DUISBURG', 'Mo-Fr 08:30 Uhr - 12:00 Uhr,Di auch 13:30 Uhr - 15:00 Uhr', 'Service@FA-5109.fin-nrw.de', 'www.finanzamt-Duisburg-Sued.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5110', 'Essen-Nord ', 'Altendorfer Str. 129', '45143', 'Essen', '0201/1894-0', '0800 10092675110', '', '45011', '101155', '36000000', '36001500', 'BBK ESSEN', '36050105', '275008', 'SPARKASSE ESSEN', 'Mo-Fr 08.30-12.00 Uhr,Di auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5110.fin-nrw.de', 'www.finanzamt-Essen-Nord.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5111', 'Essen-Ost ', 'Altendorfer Str. 129', '45143', 'Essen', '0201/1894-0', '0800 10092675111', '45116', '45012', '101262', '36000000', '36001501', 'BBK ESSEN', '36050105', '261800', 'SPARKASSE ESSEN', 'Mo-Fr,Di', 'Service@FA-5111.fin-nrw.de', 'www.finanzamt-Essen-Ost.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5112', 'Essen-Süd ', 'Altendorfer Str. 129', '45143', 'Essen', '0201/1894-0', '0800 10092675112', '', '45011', '101145', '36000000', '36001502', 'BBK ESSEN', '36050105', '203000', 'SPARKASSE ESSEN', 'Mo-Fr 08.30-12.00 Uhr, Di auch 13.30-15.00 Uhr, und nach Vereinbarung', 'Service@FA-5112.fin-nrw.de', 'www.finanzamt-Essen-Sued.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5113', 'Geldern ', 'Gelderstr 32', '47608', 'Geldern', '02831/127-0', '0800 10092675113', '', '47591', '1163', '32000000', '32001502', 'BBK MOENCHENGLADBACH EH KRE', '32051370', '112011', 'SPARKASSE GELDERN', 'Montag - Freitag 8:30 - 12:00,Uhr,Dienstag auch 13:00 - 15:00 U,hr und nach Vereinbarung', 'Service@FA-5113.fin-nrw.de', 'www.finanzamt-Geldern.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5114', 'Grevenbroich ', 'Erckensstr. 2', '41515', 'Grevenbroich', '02181/607-0', '0800 10092675114', '', '41486', '100264', '30000000', '30001507', 'BBK DUESSELDORF', '30550000', '101683', 'SPARKASSE NEUSS', 'Mo-Fr 8:30-12:00 Uhr,Di auch 13:30-15:00 Uhr,und nach Vereinbarung', 'Service@FA-5114.fin-nrw.de', 'www.finanzamt-Grevenbroich.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5115', 'Kempen ', 'Arnoldstr 13', '47906', 'Kempen', '02152/919-0', '0800 10092675115', '', '47880', '100329', '31000000', '32001501', 'BBK MOENCHENGLADBACH', '', '', '', 'MO.-DO. 8.30-12.00 UHR,FREITAGS GESCHLOSSEN', 'Service@FA-5115.fin-nrw.de', 'www.finanzamt-Kempen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5116', 'Kleve ', 'Emmericher Str. 182', '47533', 'Kleve', '02821/803-1', '0800 10092675116', '', '47512', '1251', '35000000', '32401501', 'BBK DUISBURG', '32450000', '5013628', 'SPARKASSE KLEVE', 'Mo - Fr 08.30 - 12.00 Uhr,Di auch 13.30 - 15.00 Uhr', 'Service@FA-5116.fin-nrw.de', 'www.finanzamt-Kleve.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5117', 'Krefeld ', 'Grenzstr 100', '47799', 'Krefeld', '02151/854-0', '0800 10092675117', '', '47706', '100665', '31000000', '32001500', 'BBK MOENCHENGLADBACH', '', '', '', 'Mo-Fr 08.30-12.00 Uhr,Di auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5117.fin-nrw.de', 'www.finanzamt-Krefeld.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5119', 'Moers ', 'Unterwallstr 1', '47441', 'Moers', '02841/208-0', '0800 10092675119', '47439', '47405', '101520', '35000000', '35001505', 'BBK DUISBURG', '35450000', '1101000121', 'SPARKASSE MOERS', 'Montag-Freitag von 8.30-12.00,Dienstag von 13.30-15.00', 'Service@FA-5119.fin-nrw.de', 'www.finanzamt-Moers.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5120', 'Mülheim an der Ruhr ', 'Wilhelmstr 7', '45468', 'Mülheim an der Ruhr', '0208/3001-1', '0800 10092675120', '', '45405', '100551', '36000000', '36201500', 'BBK ESSEN', '36250000', '300007007', 'SPK MUELHEIM AN DER RUHR', 'Mo-Fr,Di auch 13:30-15:00 Uhr,und nach Vereinbarung', 'Service@FA-5120.fin-nrw.de', 'www.finanzamt-Muelheim-Ruhr.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5121', 'Mönchengladbach-Mitte ', 'Kleiststr. 1', '41061', 'Mönchengladbach', '02161/189-0', '0800 10092675121', '', '41008', '100813', '31000000', '31001500', 'BBK MOENCHENGLADBACH', '31050000', '8888', 'ST SPK MOENCHENGLADBACH', 'Mo - Fr,Di auch,und nach Vereinbarung', 'Service@FA-5121.fin-nrw.de', 'www.finanzamt-Moenchengladbach-Mitte.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5122', 'Neuss II ', 'Hammfelddamm 9', '41460', 'Neuss', '02131/6656-0', '0800 10092675122', '', '41405', '100502', '30000000', '30001509', 'BBK DUESSELDORF', '30550000', '123000', 'SPARKASSE NEUSS', 'Mo,Di,Do,Fr von 8.30-12.00,Di von 13.30-15.00', 'Service@FA-5122.fin-nrw.de', 'www.finanzamt-Neuss2.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5123', 'Oberhausen-Nord ', 'Gymnasialstr. 16', '46145', 'Oberhausen', '0208/6499-0', '0800 10092675123', '', '46122', '110220', '36000000', '36501501', 'BBK ESSEN', '36550000', '260125', 'ST SPK OBERHAUSEN', 'Mo-Fr 08:30-12:00 Uhr,Di auch 13:30-15:00 Uhr,und nach Vereinbarung', 'Service@FA-5123.fin-nrw.de', 'www.finanzamt-Oberhausen-Nord.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5124', 'Oberhausen-Süd ', 'Schwartzstr. 7-9', '46045', 'Oberhausen', '0208/8504-0', '0800 10092675124', '', '46004', '100447', '36000000', '36501500', 'BBK ESSEN', '36550000', '138156', 'ST SPK OBERHAUSEN', 'Mo - Fr 08.30 - 12.00 Uhr,Di auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5124.fin-nrw.de', 'www.finanzamt-Oberhausen-Sued.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5125', 'Neuss I ', 'Schillerstr 80', '41464', 'Neuss', '02131/943-0', '0800 10092675125', '41456', '41405', '100501', '30000000', '30001508', 'BBK DUESSELDORF', '30550000', '129999', 'SPARKASSE NEUSS', 'Mo-Fr 08.30-12.00 Uhr,Mo auch 13.30-15.00 Uhr', 'Service@FA-5125.fin-nrw.de', 'www.finanzamt-Neuss1.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5126', 'Remscheid ', 'Wupperstr 10', '42897', 'Remscheid', '02191/961-0', '0800 10092675126', '', '42862', '110269', '33000000', '33001505', 'BBK WUPPERTAL', '34050000', '113001', 'ST SPK REMSCHEID', 'Mo-Fr 08.30-12.00Uhr,Di auch 13.30-15.00Uhr,und nach Vereinbarung', 'Service@FA-5126.fin-nrw.de', 'www.finanzamt-Remscheid.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5127', 'Mönchengladbach-Rheydt ', 'Wilhelm-Strauß-Str. 50', '41236', 'Mönchengladbach', '02166/450-0', '0800 10092675127', '', '41204', '200442', '31000000', '31001502', 'BBK MOENCHENGLADBACH', '31050000', '295600', 'ST SPK MOENCHENGLADBACH', 'MO - FR 08.30 - 12.00 Uhr,DI auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5127.fin-nrw.de', 'www.finanzamt-Moenchengladbach-Rheydt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5128', 'Solingen-Ost ', 'Goerdelerstr.24- 26', '42651', 'Solingen', '0212/282-1', '0800 10092675128', '42648', '42609', '100984', '33000000', '33001503', 'BBK WUPPERTAL', '34250000', '22707', 'ST SPK SOLINGEN', 'Mo.-Fr.,Mo. auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5128.fin-nrw.de', 'www.finanzamt-Solingen-Ost.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5129', 'Solingen-West ', 'Merscheider Busch 23', '42699', 'Solingen', '0212/2351-0', '0800 10092675129', '', '42663', '110340', '33000000', '33001501', 'BBK WUPPERTAL', '34250000', '130005', 'ST SPK SOLINGEN', 'MO-FR 08.30 - 12.00 Uhr,und nach Vereinbarung', 'Service@FA-5129.fin-nrw.de', 'www.finanzamt-Solingen-West.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5130', 'Wesel ', 'Poppelbaumstr. 5-7', '46483', 'Wesel', '0281/105-0', '0800 10092675130', '', '46461', '100136', '35000000', '35601500', 'BBK DUISBURG', '35650000', '208660', 'VERB SPK WESEL', 'Mo-Fr 08.30 - 12.00 Uhr,Di auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5130.fin-nrw.de', 'www.finanzamt-Wesel.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5131', 'Wuppertal-Barmen ', 'Unterdörnen 96', '42283', 'Wuppertal', '0202/9543-0', '0800 10092675131', '42271', '42208', '200853', '33000000', '33001502', 'BBK WUPPERTAL', '', '', '', 'Mo - Fr,Do auch,und nach Vereinbarung', 'Service@FA-5131.fin-nrw.de', 'www.finanzamt-Wuppertal-Barmen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5132', 'Wuppertal-Elberfeld ', 'Kasinostr. 12', '42103', 'Wuppertal', '0202/489-0', '0800 10092675132', '', '42002', '100209', '33000000', '33001500', 'BBK WUPPERTAL', '', '', '', 'Mo-Fr 08.30-12.00 Uhr,Do auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5132.fin-nrw.de', 'www.finanzamt-Wuppertal-Elberfeld.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5133', 'Düsseldorf-Mitte ', 'Kruppstr. 110', '40227', 'Düsseldorf', '0211/779-9', '0800 10092675133', '', '40001', '101024', '30000000', '30001505', 'BBK DUESSELDORF', '30050110', '10123008', 'ST SPK DUESSELDORF', '', 'Service@FA-5133.fin-nrw.de', 'www.finanzamt-Duesseldorf-Mitte.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5134', 'Duisburg-West ', 'Friedrich-Ebert-Str 133', '47226', 'Duisburg', '02065/307-0', '0800 10092675134', '', '47203', '141355', '35000000', '35001503', 'BBK DUISBURG', '', '', '', 'Mo - Fr 08.30 - 12.00 Uhr,Di auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5134.fin-nrw.de', 'www.finanzamt-Duisburg-West.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5135', 'Hilden ', 'Neustr. 60', '40721', 'Hilden', '02103/917-0', '0800 10092675135', '', '40710', '101046', '30000000', '30001506', 'BBK DUESSELDORF', '', '', '', 'Mo-Fr 08.30-12.00 Uhr,Di auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5135.fin-nrw.de', 'www.finanzamt-Hilden.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5139', 'Velbert ', 'Nedderstraße 38', '42549', 'Velbert', '02051/47-0', '0800 10092675139', '', '42513', '101310', '33000000', '33001504', 'BBK WUPPERTAL', '33450000', '26205500', 'SPARKASSE HRV', 'Mo-Fr 08.30-12.00 Uhr,Mo auch 13.30-15.00 Uhr', 'Service@FA-5139.fin-nrw.de', 'www.finanzamt-Velbert.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5147', 'Düsseldorf-Mettmann ', 'Harkortstr. 2-4', '40210', 'Düsseldorf', '0211/3804-0', '0800 10092675147', '', '40001', '101023', '30000000', '30001500', 'BBK DUESSELDORF', '30050000', '4051017', 'WESTLB DUESSELDORF', 'Montag bis Freitag,08.30 bis 12.00 Uhr,und nach Vereinbarung', 'Service@FA-5147.fin-nrw.de', 'www.finanzamt-Duesseldorf-Mettmann.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5149', 'Rechenzentrum d. FinVew NRW ', 'Roßstraße 131', '40476', 'Düsseldorf', '0211/4572-0', '0211/4572-302', '', '40408', '300864', '', '', '', '', '', '', '', 'Service@FA-5149.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5170', 'Düsseldorf I für Groß- und Konzernbetriebsprüfung', 'Werftstr. 16', '40549', 'Düsseldorf', '0211/56354-01', '0800 10092675170', '', '40525', '270264', '', '', '', '', '', '', '', 'Service@FA-5170.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5171', 'Düsseldorf II für Groß- und Konzernbetriebsprüfung', 'Werftstr. 16', '40549', 'Düsseldorf', '0211/56354-0', '0800 10092675171', '', '40525', '270264', '', '', '', '', '', '', '', 'Service@FA-5171.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5172', 'Essen für Groß- und Konzernbetriebsprüfung', 'In der Hagenbeck 64', '45143', 'Essen', '0201/6300-1', '0800 10092675172', '', '45011', '101155', '', '', '', '', '', '', '', 'Service@FA-5172.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5173', 'Krefeld für Groß- und Konzernbetriebsprüfung', 'Steinstr. 137', '47798', 'Krefeld', '02151/8418-0', '0800 10092675173', '', '', '', '', '', '', '', '', '', '', 'Service@FA-5173.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5174', 'Berg. Land für Groß- und Konzernbetriebsprüfung', 'Bendahler Str. 29', '42285', 'Wuppertal', '0202/2832-0', '0800 10092675174', '42271', '', '', '', '', '', '', '', '', '', 'Service@FA-5174.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5176', 'Mönchengladbach für Groß- und  Konzernbetriebsprüfung', 'Aachener Str. 114', '41061', 'Mönchengladbach', '02161/3535-0', '0800 10092675176', '', '41017', '101715', '', '', '', '', '', '', '', 'Service@FA-5176.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5181', 'Düsseldorf f. Steuerfahndung und Steuerstrafsachen', 'Kruppstr.110 -112', '40227', 'Düsseldorf', '0211/779-9', '0800 10092675181', '', '40001', '101024', '30000000', '30001502', 'BBK DUESSELDORF', '30050110', '10125003', 'ST SPK DUESSELDORF', 'Mo - Di 07.30 - 16.30 Uhr,Mi - Fr 07.30 - 16.00 Uhr', 'Service@FA-5181.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5182', 'Essen f. Steuerfahndung und Steuerstrafsachen', 'In der Hagenbeck 64', '45143', 'Essen', '0201/6300-1', '0800 10092675182', '', '45011', '101155', '36000000', '36001502', 'BBK ESSEN', '36050105', '203000', 'SPARKASSE ESSEN', '', 'Service@FA-5182.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5183', 'Wuppertal f. Steuerfahndung und Steuerstrafsachen', 'Unterdörnen 96', '42283', 'Wuppertal', '0202/9543-0', '0800 10092675183', '', '42205', '200553', '33000000', '33001502', 'BBK WUPPERTAL', '33050000', '135004', 'ST SPK WUPPERTAL', '', 'Service@FA-5183.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5201', 'Aachen-Innenstadt ', 'Mozartstr 2-10', '52064', 'Aachen', '0241/469-0', '0800 10092675201', '', '52018', '101833', '39000000', '39001501', 'BBK AACHEN', '39050000', '26', 'SPARKASSE AACHEN', 'Mo - Fr 08.30 - 12.00 Uhr,Mo auch 13.30 -15.00 Uhr,und nach Vereinbarung', 'Service@FA-5201.fin-nrw.de', 'www.finanzamt-Aachen-Innenstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5202', 'Aachen-Kreis ', 'Beverstr 17', '52066', 'Aachen', '0241/940-0', '0800 10092675202', '', '52018', '101829', '39000000', '39001500', 'BBK AACHEN', '39050000', '311118', 'SPARKASSE AACHEN', 'Mo.-Fr. 08.30 - 12.00 Uhr,Mo.,und nach Vereinbarung', 'Service@FA-5202.fin-nrw.de', 'www.finanzamt-Aachen-Kreis.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5203', 'Bergheim ', 'Rathausstrasse 3', '50126', 'Bergheim', '02271/82-0', '0800 10092675203', '', '50101', '1120', '39500000', '39501501', 'BBK AACHEN EH DUEREN', '', '', '', 'Mo-Fr 08:30-12:00 Uhr,Di 13:30-15:00 Uhr,und nach Vereinbarung', 'Service@FA-5203.fin-nrw.de', 'www.finanzamt-Bergheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5204', 'Bergisch Gladbach ', 'Refrather Weg 35', '51469', 'Bergisch Gladbach', '02202/9342-0', '0800 10092675204', '', '51433', '200380', '37000000', '37001508', 'BBK KOELN', '', '', '', 'Mo.-Fr. 8.30-12.00 Uhr', 'Service@FA-5204.fin-nrw.de', 'www.finanzamt-Bergisch-Gladbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5205', 'Bonn-Innenstadt ', 'Welschnonnenstr. 15', '53111', 'Bonn', '0228/718-0', '0800 10092675205', '', '53031', '180120', '38000000', '38001500', 'BBK BONN', '38050000', '17079', 'SPARKASSE BONN', 'Mo-Mi 08.30-12.00 Uhr,Do 07.00-17.00 Uhr,Freitag geschlossen', 'Service@FA-5205.fin-nrw.de', 'www.finanzamt-Bonn-Innenstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5206', 'Bonn-Außenstadt ', 'Bachstr. 36', '53115', 'Bonn', '0228/7268-0', '0800 10092675206', '', '53005', '1580', '38000000', '38001501', 'BBK BONN', '38050000', '22004', 'SPARKASSE BONN', 'Mo-Do,Do auch 13:30 bis 17:30 Uhr,Freitags geschlossen', 'Service@FA-5206.fin-nrw.de', 'www.finanzamt-Bonn-Aussenstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5207', 'Düren ', 'Goethestrasse 7', '52349', 'Düren', '02421/947-0', '0800 10092675207', '', '52306', '100646', '39500000', '39501500', 'BBK AACHEN EH DUEREN', '39550110', '188300', 'SPARKASSE DUEREN', 'Mo-Fr 08:30 - 12:00 Uhr,Di auch 13:30 - 15:00 Uhr,und nach Vereinbarung', 'Service@FA-5207.fin-nrw.de', 'www.finanzamt-Dueren.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5208', 'Erkelenz ', 'Südpromenade 37', '41812', 'Erkelenz', '02431/801-0', '0800 10092675208', '', '41806', '1651', '31000000', '31001501', 'BBK MOENCHENGLADBACH', '31251220', '402800', 'KR SPK HEINSBERG ERKELENZ', 'Mo - Fr 8.30 - 12.00 Uhr,Di auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5208.fin-nrw.de', 'www.finanzamt-Erkelenz.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5209', 'Euskirchen ', 'Thomas-Mann-Str. 2', '53879', 'Euskirchen', '02251/982-0', '0800 10092675209', '', '53864', '1487', '38000000', '38001505', 'BBK BONN', '38250110', '1000330', 'KREISSPARKASSE EUSKIRCHEN', 'Mo - Fr 08.30 - 12.00 Uhr,Mo auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5209.fin-nrw.de', 'www.finanzamt-Euskirchen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5210', 'Geilenkirchen ', 'H.-Wilh.-Str 45', '52511', 'Geilenkirchen', '02451/623-0', '0800 10092675210', '', '52501', '1193', '39000000', '39001502', 'BBK AACHEN', '31251220', '5397', 'KR SPK HEINSBERG ERKELENZ', 'Mo.-Fr. 8.30 - 12.00 Uhr,nachmittags nur tel. von,13.30 - 15.00 Uhr', 'Service@FA-5210.fin-nrw.de', 'www.finanzamt-Geilenkirchen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5211', 'Schleiden ', 'Kurhausstr. 7', '53937', 'Schleiden', '02444/85-0', '0800 10092675211', '', '53929', '1140', '38000000', '38001506', 'BBK BONN', '38250110', '3200235', 'KREISSPARKASSE EUSKIRCHEN', 'Mo-Fr 08.30 - 12.00 Uhr,Di auch 13.30 - 15.00 Uhr,sowie nach Vereinbarung', 'Service@FA-5211.fin-nrw.de', 'www.finanzamt-Schleiden.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5212', 'Gummersbach ', 'Mühlenbergweg 5', '51645', 'Gummersbach', '02261/86-0', '0800 10092675212', '51641', '', '', '37000000', '37001506', 'BBK KOELN', '', '', '', 'Mo - Fr 08.30-12.00 Uhr,Mo auch 13.30-15.00 Uhr', 'Service@FA-5212.fin-nrw.de', 'www.finanzamt-Gummersbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5213', 'Jülich ', 'Wilhelmstr 5', '52428', 'Jülich', '02461/685-0', '0800 10092675213', '', '52403', '2180', '39000000', '39701500', 'BBK AACHEN', '39550110', '25023', 'SPARKASSE DUEREN', 'Mo.-Fr. 08.00-12.00 Uhr,Di. 13.30-15.00 Uhr', 'Service@FA-5213.fin-nrw.de', 'www.finanzamt-Juelich.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5214', 'Köln-Altstadt ', 'Am Weidenbach 2-4', '50676', 'Köln', '0221/2026-0', '0800 10092675214', '', '50517', '250140', '37000000', '37001501', 'BBK KOELN', '37050198', '70052964', 'STADTSPARKASSE KOELN', 'Mo - Fr 8.30 - 12.00 Uhr,Di auch 13.00 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5214.fin-nrw.de', 'www.finanzamt-Koeln-Altstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5215', 'Köln-Mitte ', 'Blaubach 7', '50676', 'Köln', '0221/92400-0', '0800 10092675215', '', '50524', '290208', '37000000', '37001505', 'BBK KOELN', '37050198', '70062963', 'STADTSPARKASSE KOELN', 'MO-FR 08.30 - 12.00 UHR', 'Service@FA-5215.fin-nrw.de', 'www.finanzamt-Koeln-Mitte.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5216', 'Köln-Porz ', 'Klingerstr. 2-6', '51143', 'Köln', '02203/598-0', '0800 10092675216', '', '51114', '900469', '37000000', '37001524', 'BBK KOELN', '', '', '', 'Mo-Fr08.30-12.00 Uhr,Di auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5216.fin-nrw.de', 'www.finanzamt-Koeln-Porz.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5217', 'Köln-Nord ', 'Innere Kanalstr. 214', '50670', 'Köln', '0221/97344-0', '0800 10092675217', '', '50495', '130164', '37000000', '37001502', 'BBK KOELN', '37050198', '70102967', 'STADTSPARKASSE KOELN', 'Mo - Fr 8.30 - 12.00 Uhr,und nach Vereinbarung', 'Service@FA-5217.fin-nrw.de', 'www.finanzamt-Koeln-Nord.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5218', 'Köln-Ost ', 'Siegesstrasse 1', '50679', 'Köln', '0221/9805-0', '0800 10092675218', '', '50529', '210340', '37000000', '37001503', 'BBK KOELN', '37050198', '70082961', 'STADTSPARKASSE KOELN', 'Mo-Fr 08.30-12.00 Uhr,Di auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5218.fin-nrw.de', 'www.finanzamt-Koeln-Ost.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5219', 'Köln-Süd ', 'Am Weidenbach 6', '50676', 'Köln', '0221/2026-0', '0800 10092675219', '', '50517', '250160', '37000000', '37001504', 'BBK KOELN', '37050198', '70032966', 'STADTSPARKASSE KOELN', 'Mo-Fr,Di auch 13.00-15.00 Uhr', 'Service@FA-5219.fin-nrw.de', 'www.finanzamt-Koeln-Sued.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5220', 'Siegburg ', 'Mühlenstr 19', '53721', 'Siegburg', '02241/105-0', '0800 10092675220', '', '53703', '1351', '38000000', '38001503', 'BBK BONN', '', '', '', 'Mo.-Fr. 08.30-12.00 Uhr,Mo. auch 13.30-17.00 Uhr,und nach Vereinbarung', 'Service@FA-5220.fin-nrw.de', 'www.finanzamt-Siegburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5221', 'Wipperfürth ', 'Am Stauweiher 3', '51688', 'Wipperfürth', '02267/870-0', '0800 10092675221', '', '51676', '1240', '37000000', '37001513', 'BBK KOELN', '', '', '', 'Mo-Fr 08.30-12.00 Uhr,Di auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5221.fin-nrw.de', 'www.finanzamt-Wipperfuerth.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5222', 'Sankt Augustin ', 'Hubert-Minz-Str 10', '53757', 'Sankt Augustin', '02241/242-1', '0800 10092675222', '', '53730', '1229', '38000000', '38001504', 'BBK BONN', '', '', '', 'Mo - Fr 8.30-12.00 Uhr,Di auch 13.30-15.00 Uhr', 'Service@FA-5222.fin-nrw.de', 'www.finanzamt-Sankt-Augustin.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5223', 'Köln-West ', 'Haselbergstr 20', '50931', 'Köln', '0221/5734-0', '0800 10092675223', '', '50864', '410469', '37000000', '37001523', 'BBK KOELN', '37050198', '70022967', 'STADTSPARKASSE KOELN', '', 'Service@FA-5223.fin-nrw.de', 'www.finanzamt-Koeln-West.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5224', 'Brühl ', 'Kölnstr. 104', '50321', 'Brühl', '02232/703-0', '0800 10092675224', '50319', '', '', '37000000', '37001507', 'BBK KOELN', '', '', '', 'Mo-Fr 08.30 - 12.00,Die zusätzlich 13.30 - 15.00 ,und nach Vereinbarung', 'Service@FA-5224.fin-nrw.de', 'www.finanzamt-Bruehl.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5225', 'Aachen-Außenstadt ', 'Beverstraße', '52066', 'Aachen', '0241/940-0', '0800 10092675225', '', '52018', '101825', '39000000', '39001503', 'BBK AACHEN', '39050000', '1099', 'SPARKASSE AACHEN', 'Mo - Fr 08.30 - 12.00 Uhr,Mo auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5225.fin-nrw.de', 'www.finanzamt-Aachen-Aussenstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5230', 'Leverkusen ', 'Haus-Vorster-Str 12', '51379', 'Leverkusen', '02171/407-0', '0800 10092675230', '51367', '', '', '37000000', '37001511', 'BBK KOELN', '37551440', '118318500', 'SPARKASSE LEVERKUSEN', 'Mo-Do 8.30 - 12.00 Uhr,Di.: 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5230.fin-nrw.de', 'www.finanzamt-Leverkusen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5270', 'KonzBP Köln für Groß- und Konzernbetriebsprüfung', 'Riehler Platz 2', '50668', 'Köln', '0221/2021-0', '0800 10092675270', '', '', '', '', '', '', '', '', '', '', 'Service@FA-5270.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5271', 'Aachen für Groß- und Konzernbetriebsprüfung', 'Beverstr. 17', '52066', 'Aachen', '0241/940-0', '0800 10092675271', '', '52017', '101744', '', '', '', '', '', '', '', 'Service@FA-5271.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5272', 'Bonn für Groß- und Konzernbetriebsprüfung', 'Am Propsthof 17', '53121', 'Bonn', '0228/7223-0', '0800 10092675272', '', '', '', '', '', '', '', '', '', '', 'Service@FA-5272.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5281', 'Aachen f. Steuerfahndung und Steuerstrafsachen', 'Beverstr 17', '52066', 'Aachen', '0241/940-0', '0800 10092675281', '', '52017', '101722', '39000000', '39001500', 'BBK AACHEN', '39050000', '311118', 'SPARKASSE AACHEN', '', 'Service@FA-5281.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5282', 'Bonn f. Steuerfahndung und Steuerstrafsachen', 'Theaterstr. 1', '53111', 'Bonn', '0228/718-0', '0800 10092675282', '', '', '', '38000000', '38001500', 'BBK BONN', '38050000', '17079', 'SPARKASSE BONN', '', 'Service@FA-5282.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5283', 'Köln f. Steuerfahndung und Steuerstrafsachen', 'Am Gleisdreieck 7- 9', '50823', 'Köln', '0221/5772-0', '0800 10092675283', '', '50774', '300451', '37000000', '37001502', 'BBK KOELN', '37050198', '70102967', 'STADTSPARKASSE KOELN', '', 'Service@FA-5283.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5301', 'Ahaus ', 'Vredener Dyk 2', '48683', 'Ahaus', '02561/929-0', '0800 10092675301', '', '48662', '1251', '40000000', '40001503', 'BBK MUENSTER, WESTF', '40154530', '51027902', 'SPARKASSE WESTMUENSTERLAND', 'Mo - Fr 08.30 - 12.00 Uhr,zudem Mo 13.30 - 15.00 Uhr,sowie Do 13.30 -', 'Service@FA-5301.fin-nrw.de', 'www.finanzamt-Ahaus.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5302', 'Altena ', 'Winkelsen 11', '58762', 'Altena', '02352/917-0', '0800 10092675302', '', '58742', '1253', '45000000', '45001501', 'BBK HAGEN', '45851020', '80020001', 'VER SPK PLETTENBERG', 'Mo,Di-Do,und nach Vereinbarung', 'Service@FA-5302.fin-nrw.de', 'www.finanzamt-Altena.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5303', 'Arnsberg ', 'Rumbecker Straße 36', '59821', 'Arnsberg', '02931/875-0', '0800 10092675303', '59818', '59802', '5245', '41000000', '46401501', 'BBK HAMM, WESTF', '46650005', '1020007', 'SPK ARNSBERG-SUNDERN', 'Mo-Mi 08.30 - 12.00 Uhr,Fr,und nach Vereinbarung', 'Service@FA-5303.fin-nrw.de', 'www.finanzamt-Arnsberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5304', 'Beckum ', 'Elisabethstraße 19', '59269', 'Beckum', '02521/25-0', '0800 10092675304', '59267', '59244', '1452', '41000000', '41001501', 'BBK HAMM, WESTF', '41250035', '1000223', 'SPK BECKUM-WADERSLOH', 'MO-FR 08.30-12.00 UHR,MO AUCH 13.30-15.00 UHR,UND NACH VEREINBARUNG', 'Service@FA-5304.fin-nrw.de', 'www.finanzamt-Beckum.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5305', 'Bielefeld-Innenstadt ', 'Ravensberger Straße 90', '33607', 'Bielefeld', '0521/548-0', '0800 10092675305', '', '33503', '100371', '48000000', '48001500', 'BBK BIELEFELD', '48050161', '109', 'SPK BIELEFELD', 'Mo - Fr 8.30 - 12.00 Uhr,Di auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5305.fin-nrw.de', 'www.finanzamt-Bielefeld-Innenstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5306', 'Bochum-Mitte ', 'Castroper Str. 40 - 42', '44791', 'Bochum', '0234/514-0', '0800 10092675306', '', '44707', '100729', '43000000', '43001500', 'BBK BOCHUM', '43050001', '1300011', 'SPARKASSE BOCHUM', 'Mo-Fr 08:30 - 12:00 Uhr,Di auch 13:30 - 15:00 Uhr,Individuelle Terminver-,einbarungen sind möglich', 'Service@FA-5306.fin-nrw.de', 'www.finanzamt-Bochum-Mitte.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5307', 'Borken ', 'Nordring 184', '46325', 'Borken', '02861/938-0', '0800 10092675307', '46322', '46302', '1240', '40000000', '40001514', 'BBK MUENSTER, WESTF', '40154530', '51021137', 'SPARKASSE WESTMUENSTERLAND', 'Mo-Fr 8.30 - 12.00 Uhr,Mo 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5307.fin-nrw.de', 'www.finanzamt-Borken.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5308', 'Bottrop ', 'Scharnhölzstraße 32', '46236', 'Bottrop', '02041/691-0', '0800 10092675308', '', '46205', '100553', '43000000', '42401501', 'BBK BOCHUM', '42451220', '10009', 'SPK BOTTROP', 'Mo-Mi 08.00-12.00 Uhr,Do 07.30-12.00 u 13.30-15.00 ,Freitags geschlossen', 'Service@FA-5308.fin-nrw.de', 'www.finanzamt-Bottrop.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5309', 'Brilon ', 'Steinweg 30', '59929', 'Brilon', '02961/788-0', '0800 10092675309', '', '59915', '1260', '48000000', '47201502', 'BBK BIELEFELD', '41651770', '17004', 'SPK HOCHSAUERLAND BRILON', 'Mo - Fr 08:30 - 12:00 Uhr,Di auch 13:30 - 15:00 Uhr,und nach Vereinbarung', 'Service@FA-5309.fin-nrw.de', 'www.finanzamt-Brilon.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5310', 'Bünde ', 'Lettow-Vorbeck-Str 2-10', '32257', 'Bünde', '05223/169-0', '0800 10092675310', '', '32216', '1649', '48000000', '48001502', 'BBK BIELEFELD', '49450120', '210003000', 'SPARKASSE HERFORD', '', 'Service@FA-5310.fin-nrw.de', 'www.finanzamt-Buende.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5311', 'Steinfurt ', 'Ochtruper Straße 2', '48565', 'Steinfurt', '02551/17-0', '0800 10092675311', '48563', '48542', '1260', '40000000', '40301500', 'BBK MUENSTER, WESTF', '', '', '', 'Mo-Fr 08.00-12.00 Uhr,Mo auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5311.fin-nrw.de', 'www.finanzamt-Steinfurt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5312', 'Coesfeld ', 'Friedrich-Ebert-Str. 8', '48653', 'Coesfeld', '02541/732-0', '0800 10092675312', '', '48633', '1344', '40000000', '40001505', 'BBK MUENSTER, WESTF', '40154530', '59001644', 'SPARKASSE WESTMUENSTERLAND', 'Mo - Fr 08.30 - 12.00 Uhr,Mo auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5312.fin-nrw.de', 'www.finanzamt-Coesfeld.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5313', 'Detmold ', 'Wotanstraße 8', '32756', 'Detmold', '05231/972-0', '0800 10092675313', '32754', '32706', '1664', '48000000', '48001504', 'BBK BIELEFELD', '47650130', '4002', 'SPK DETMOLD', 'Mo. bis Fr.,Montags,und nach Vereinbarung', 'Service@FA-5313.fin-nrw.de', 'www.finanzamt-Detmold.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5314', 'Dortmund-West ', 'Märkische Straße 124', '44141', 'Dortmund', '0231/9581-0', '0800 10092675314', '', '44047', '105041', '44000000', '44001500', 'BBK DORTMUND', '44050199', '301001886', 'SPARKASSE DORTMUND', 'Montags geschlossen,Di - Fr 8.30 - 12.00,Do zusätzlich 13.30 - 15.00', 'Service@FA-5314.fin-nrw.de', 'www.finanzamt-Dortmund-West.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5315', 'Dortmund-Hörde ', 'Niederhofener Str 3', '44263', 'Dortmund', '0231/4103-0', '0800 10092675315', '', '44232', '300255', '44000000', '44001503', 'BBK DORTMUND', '44050199', '21003468', 'SPARKASSE DORTMUND', 'Mo-Do 8.30-12.00 Uhr,und nach Vereinbarung', 'Service@FA-5315.fin-nrw.de', 'www.finanzamt-Dortmund-Hoerde.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5316', 'Dortmund-Unna ', 'Rennweg 1', '44143', 'Dortmund', '0231/5188-1', '0800 10092675316', '', '44047', '105020', '44000000', '44001501', 'BBK DORTMUND', '44050199', '1060600', 'SPARKASSE DORTMUND', 'Mo-Fr 08.30-12.00 Uhr,und nach Vereinbarung', 'Service@FA-5316.fin-nrw.de', 'www.finanzamt-Dortmund-Unna.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5317', 'Dortmund-Ost ', 'Nußbaumweg 210', '44143', 'Dortmund', '0231/5188-1', '0800 10092675317', '', '44047', '105039', '44000000', '44001502', 'BBK DORTMUND', '44050199', '301001827', 'SPARKASSE DORTMUND', 'Mo - Fr 8.30 - 12.00 Uhr,und nach Vereinbarung', 'Service@FA-5317.fin-nrw.de', 'www.finanzamt-Dortmund-Ost.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5318', 'Gelsenkirchen-Nord ', 'Rathausplatz 1', '45894', 'Gelsenkirchen', '0209/368-1', '0800 10092675318', '', '45838', '200351', '43000000', '42001501', 'BBK BOCHUM', '42050001', '160012007', 'SPARKASSE GELSENKIRCHEN', 'Mo-Fr 08.30-12.00 Uhr,Mo auch 13.30-15.00Uhr', 'Service@FA-5318.fin-nrw.de', 'www.finanzamt-Gelsenkirchen-Nord.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5319', 'Gelsenkirchen-Süd ', 'Zeppelinallee 9-13', '45879', 'Gelsenkirchen', '0209/173-1', '0800 10092675319', '', '45807', '100753', '43000000', '42001500', 'BBK BOCHUM', '42050001', '101050003', 'SPARKASSE GELSENKIRCHEN', 'Mo - Fr 08.30 - 12.00 Uhr,Mo auch 13.30 - 15.00 Uhr', 'Service@FA-5319.fin-nrw.de', 'www.finanzamt-Gelsenkirchen-Sued.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5320', 'Gladbeck ', 'Jovyplatz 4', '45964', 'Gladbeck', '02043/270-1', '0800 10092675320', '', '45952', '240', '43000000', '42401500', 'BBK BOCHUM', '42450040', '91', 'ST SPK GLADBECK', 'MO-FR 08.30-12.00 UHR,DO AUCH 13.30-15.00 UHR,UND NACH VEREINBARUNG', 'Service@FA-5320.fin-nrw.de', 'www.finanzamt-Gladbeck.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5321', 'Hagen ', 'Schürmannstraße 7', '58097', 'Hagen', '02331/180-0', '0800 10092675321', '', '58041', '4145', '45000000', '45001500', 'BBK HAGEN', '45050001', '100001580', 'SPARKASSE HAGEN', 'Mo-Fr,Mo auch 13.30-15.00 Uhr', 'Service@FA-5321.fin-nrw.de', 'www.finanzamt-Hagen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5322', 'Hamm ', 'Grünstraße 2', '59065', 'Hamm', '02381/918-0', '0800 10092675322', '59061', '59004', '1449', '41000000', '41001500', 'BBK HAMM, WESTF', '41050095', '90001', 'SPARKASSE HAMM', 'Mo-Do 8.30-12.00 Uhr,Mi auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5322.fin-nrw.de', 'www.finanzamt-Hamm.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5323', 'Hattingen ', 'Rathausplatz 19', '45525', 'Hattingen', '02324/208-0', '0800 10092675323', '', '45502', '800257', '43000000', '43001501', 'BBK BOCHUM', '', '', '', 'Mo-Fr,Di auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5323.fin-nrw.de', 'www.finanzamt-Hattingen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5324', 'Herford ', 'Wittekindstraße 5', '32051', 'Herford', '05221/188-0', '0800 10092675324', '', '32006', '1642', '48000000', '48001503', 'BBK BIELEFELD', '49450120', '36004', 'SPARKASSE HERFORD', 'Mo,Di,Fr 7.30-12.00 Uhr,Do 7.30-17.00 Uhr,Mi geschlossen,und nach Vereinbarung', 'Service@FA-5324.fin-nrw.de', 'www.finanzamt-Herford.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5325', 'Herne-Ost ', 'Markgrafenstraße 12', '44623', 'Herne', '02323/598-0', '0800 10092675325', '', '44602', '101220', '43000000', '43001502', 'BBK BOCHUM', '43250030', '1012004', 'HERNER SPARKASSE', 'Rückfragen bitte nur,telefonisch oder nach,vorheriger Rücksprache mit,dem Bearbeiter', 'Service@FA-5325.fin-nrw.de', 'www.finanzamt-Herne-Ost.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5326', 'Höxter ', 'Bismarckstraße 11', '37671', 'Höxter', '05271/969-0', '0800 10092675326', '37669', '37652', '100239', '48000000', '47201501', 'BBK BIELEFELD', '47251550', '3008521', 'SPK HOEXTER BRAKEL', 'Mo - Do,Do auch,und nach Vereinbarung', 'Service@FA-5326.fin-nrw.de', 'www.finanzamt-Hoexter.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5327', 'Ibbenbüren ', 'Uphof 10', '49477', 'Ibbenbüren', '05451/920-0', '0800 10092675327', '', '49462', '1263', '40000000', '40301501', 'BBK MUENSTER, WESTF', '40351060', '2469', 'KR SPK STEINFURT', 'Mo - Fr,Di auch', 'Service@FA-5327.fin-nrw.de', 'www.finanzamt-Ibbenbueren.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5328', 'Iserlohn ', 'Zollernstraße 16', '58636', 'Iserlohn', '02371/969-0', '0800 10092675328', '58634', '58585', '1554', '45000000', '45001503', 'BBK HAGEN', '44550045', '44008', 'SPK DER STADT ISERLOHN', 'Mo - Do 08.30 - 12.00 Uhr,Do auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5328.fin-nrw.de', 'www.finanzamt-Iserlohn.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5329', 'Lemgo ', 'Engelb.-Kämpfer Str. 18', '32657', 'Lemgo', '05261/253-1', '0800 10092675329', '', '32632', '240', '48000000', '48001505', 'BBK BIELEFELD', '48250110', '45005', 'SPARKASSE LEMGO', 'Mo - Fr,Do auch,und nach Vereinbarung', 'Service@FA-5329.fin-nrw.de', 'www.finanzamt-Lemgo.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5330', 'Lippstadt ', 'Im Grünen Winkel 3', '59555', 'Lippstadt', '02941/982-0', '0800 10092675330', '', '59525', '1580', '41000000', '46401505', 'BBK HAMM, WESTF', '41650001', '15008', 'ST SPK LIPPSTADT', 'Mo - Fr 08.30 - 12.00,Do zusätzlich 13.30 - 15.00', 'Service@FA-5330.fin-nrw.de', 'www.finanzamt-Lippstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5331', 'Lübbecke ', 'Bohlenstraße 102', '32312', 'Lübbecke', '05741/334-0', '0800 10092675331', '', '32292', '1244', '49000000', '49001501', 'BBK MINDEN, WESTF', '49050101', '141', 'SPARKASSE MINDEN-LUEBBECKE', 'Mo - Fr 08.30 - 12.00 Uhr,Mo auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5331.fin-nrw.de', 'www.finanzamt-Luebbecke.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5332', 'Lüdenscheid ', 'Bahnhofsallee 16', '58507', 'Lüdenscheid', '02351/155-0', '0800 10092675332', '58505', '58465', '1589', '45000000', '45001502', 'BBK HAGEN', '45850005', '18', 'SPK LUEDENSCHEID', 'Mo-Fr 08.30-12.00 Uhr,Do auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5332.fin-nrw.de', 'www.finanzamt-Luedenscheid.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5333', 'Lüdinghausen ', 'Bahnhofstraße 32', '59348', 'Lüdinghausen', '02591/930-0', '0800 10092675333', '', '59332', '1243', '40000000', '40001506', 'BBK MUENSTER, WESTF', '40154530', '1008', 'SPARKASSE WESTMUENSTERLAND', 'vormittags: Mo.-Fr.8.30-12.00,nachmittags: Di. 13.30-15.00', 'Service@FA-5333.fin-nrw.de', 'www.finanzamt-Luedinghausen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5334', 'Meschede ', 'Fritz-Honsel-Straße 4', '59872', 'Meschede', '0291/950-0', '0800 10092675334', '', '59852', '1265', '41000000', '46401502', 'BBK HAMM, WESTF', '46451012', '13003', 'SPK MESCHEDE', 'Mo-Fr 08:30 - 12:00,und nach Vereinbarung', 'Service@FA-5334.fin-nrw.de', 'www.finanzamt-Meschede.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5335', 'Minden ', 'Heidestraße 10', '32427', 'Minden', '0571/804-1', '0800 10092675335', '', '32380', '2340', '49000000', '49001500', 'BBK MINDEN, WESTF', '49050101', '40018145', 'SPARKASSE MINDEN-LUEBBECKE', 'Mo - Fr 08.30 - 12.00 Uhr,Mo auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5335.fin-nrw.de', 'www.finanzamt-Minden.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5336', 'Münster-Außenstadt ', 'Friedrich-Ebert-Str. 46', '48153', 'Münster', '0251/9729-0', '0800 10092675336', '', '48136', '6129', '40000000', '40001501', 'BBK MUENSTER, WESTF', '40050150', '95031001', 'SPK MUENSTERLAND OST', 'Mo-Fr 08.30-12.00 Uhr,Mo auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5336.fin-nrw.de', 'www.finanzamt-Muenster-Aussenstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5337', 'Münster-Innenstadt ', 'Münzstr. 10', '48143', 'Münster', '0251/416-1', '0800 10092675337', '', '48136', '6103', '40000000', '40001502', 'BBK MUENSTER, WESTF', '40050150', '300004', 'SPK MUENSTERLAND OST', '', 'Service@FA-5337.fin-nrw.de', 'www.finanzamt-Muenster-Innenstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5338', 'Olpe ', 'Am Gallenberg 20', '57462', 'Olpe', '02761/963-0', '0800 10092675338', '', '57443', '1320', '45000000', '46001501', 'BBK HAGEN', '', '', '', 'Mo-Do 08.30 - 12.00 Uhr,Mo auch 13.30 - 15.00 Uhr,Freitag keine Sprechzeit', 'Service@FA-5338.fin-nrw.de', 'www.finanzamt-Olpe.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5339', 'Paderborn ', 'Bahnhofstraße 28', '33102', 'Paderborn', '05251/100-0', '0800 10092675339', '', '33045', '1520', '48000000', '47201500', 'BBK BIELEFELD', '47250101', '1001353', 'SPARKASSE PADERBORN', '', 'Service@FA-5339.fin-nrw.de', 'www.finanzamt-Paderborn.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5340', 'Recklinghausen ', 'Westerholter Weg 2', '45657', 'Recklinghausen', '02361/583-0', '0800 10092675340', '', '45605', '100553', '43000000', '42601500', 'BBK BOCHUM', '42650150', '90034158', 'SPK RECKLINGHAUSEN', 'Mo - Fr 08:30 bis 12:00,Mi auch 13:30 bis 15:00,und nach Vereinbarung', 'Service@FA-5340.fin-nrw.de', 'www.finanzamt-Recklinghausen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5341', 'Schwelm ', 'Bahnhofplatz 6', '58332', 'Schwelm', '02336/803-0', '0800 10092675341', '', '58316', '340', '45000000', '45001520', 'BBK HAGEN', '45451555', '80002', 'ST SPK SCHWELM', 'Mo-Fr 8.30-12.00 Uhr,Mo,und nach Vereinbarung', 'Service@FA-5341.fin-nrw.de', 'www.finanzamt-Schwelm.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5342', 'Siegen ', 'Weidenauer Straße 207', '57076', 'Siegen', '0271/4890-0', '0800 10092675342', '', '57025', '210148', '45000000', '46001500', 'BBK HAGEN', '46050001', '1100114', 'SPK SIEGEN', 'Mo-Fr,Do auch 13:30 - 17:00 Uhr,und nach Vereinbarung', 'Service@FA-5342.fin-nrw.de', 'www.finanzamt-Siegen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5343', 'Soest ', 'Waisenhausstraße 11', '59494', 'Soest', '02921/351-0', '0800 10092675343', '59491', '59473', '1364', '41000000', '46401504', 'BBK HAMM, WESTF', '41450075', '208', 'SPARKASSE SOEST', 'Mo-Fr 0830-1200Uhr,und nach Vereinbarung', 'Service@FA-5343.fin-nrw.de', 'www.finanzamt-Soest.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5344', 'Herne-West ', 'Edmund-Weber-Str. 210', '44651', 'Herne', '02325/696-0', '0800 10092675344', '', '44632', '200262', '43000000', '43001503', 'BBK BOCHUM', '43250030', '17004', 'HERNER SPARKASSE', 'Mo-Fr 08.30-12.00 Uhr,Mo 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5344.fin-nrw.de', 'www.finanzamt-Herne-West.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5345', 'Warburg ', 'Sternstraße 33', '34414', 'Warburg', '05641/771-0', '0800 10092675345', '', '34402', '1226', '48000000', '47201503', 'BBK BIELEFELD', '47251550', '25005521', 'SPK HOEXTER BRAKEL', '', 'Service@FA-5345.fin-nrw.de', 'www.finanzamt-Warburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5346', 'Warendorf ', 'Düsternstraße 43', '48231', 'Warendorf', '02581/924-0', '0800 10092675346', '', '48205', '110361', '40000000', '40001504', 'BBK MUENSTER, WESTF', '40050150', '182', 'SPK MUENSTERLAND OST', 'Mo-Fr 08.30-12.00 Uhr,Do auch 13.30-15.00 Uhr,und nach Vereinbarung', 'Service@FA-5346.fin-nrw.de', 'www.finanzamt-Warendorf.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5347', 'Wiedenbrück ', 'Hauptstraße 34', '33378', 'Rheda-Wiedenbrück', '05242/934-0', '0800 10092675347', '33372', '33342', '1429', '48000000', '47801500', 'BBK BIELEFELD', '47853520', '5231', 'KREISSPARKASSE WIEDENBRUECK', 'Mo - Fr 08.30 - 12.00 Uhr,Do auch 13.30 - 14.30 Uhr', 'Service@FA-5347.fin-nrw.de', 'www.finanzamt-Wiedenbrueck.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5348', 'Witten ', 'Ruhrstraße 43', '58452', 'Witten', '02302/921-0', '0800 10092675348', '', '58404', '1420', '43000000', '43001505', 'BBK BOCHUM', '45250035', '6007', 'ST SPK WITTEN', 'Mo - Fr 08.30 - 12.00 Uhr,Mo auch 13.30 - 15.00 Uhr,und nach Vereinbarung', 'Service@FA-5348.fin-nrw.de', 'www.finanzamt-Witten.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5349', 'Bielefeld-Außenstadt ', 'Ravensberger Straße 125', '33607', 'Bielefeld', '0521/548-0', '0800 10092675349', '', '33503', '100331', '48000000', '48001501', 'BBK BIELEFELD', '48050161', '180000', 'SPK BIELEFELD', 'Mo - Fr 08:30 - 12:00 Uhr,Do auch 13:30 - 15:00 Uhr,und nach Vereinbarung', 'Service@FA-5349.fin-nrw.de', 'www.finanzamt-Bielefeld-Aussenstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5350', 'Bochum-Süd ', 'Königsallee 21', '44789', 'Bochum', '0234/3337-0', '0800 10092675350', '', '44707', '100764', '43000000', '43001504', 'BBK BOCHUM', '43050001', '1307792', 'SPARKASSE BOCHUM', 'Mo-Fr 08:30-12:00 Uhr,Di auch 13:30-15:00 Uhr', 'Service@FA-5350.fin-nrw.de', 'www.finanzamt-Bochum-Sued.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5351', 'Gütersloh ', 'Neuenkirchener Str. 86', '33332', 'Gütersloh', '05241/3071-0', '0800 10092675351', '', '33245', '1565', '48000000', '48001506', 'BBK BIELEFELD', '', '', '', 'Mo - Fr 08.30 - 12.00 Uhr,Do auch 13.30 - 15.00 Uhr', 'Service@FA-5351.fin-nrw.de', 'www.finanzamt-Guetersloh.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5359', 'Marl ', 'Brassertstraße 1', '45768', 'Marl', '02365/516-0', '0800 10092675359', '45765', '45744', '1420', '43000000', '42601501', 'BBK BOCHUM', '42650150', '40020000', 'SPK RECKLINGHAUSEN', '', 'Service@FA-5359.fin-nrw.de', 'www.finanzamt-Marl.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5371', 'Bielefeld für Groß- und Konzernbetriebsprüfung', 'Ravensberger Str. 90', '33607', 'Bielefeld', '0521/548-0', '0800 10092675371', '', '33511', '101150', '', '', '', '', '', '', '', 'Service@FA-5371.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5372', 'Herne für Groß- und Konzernbetriebsprüfung', 'Hauptstr. 123', '44651', 'Herne', '02325/693-0', '0800 10092675372', '', '44636', '200620', '', '', '', '', '', '', '', 'Service@FA-5372.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5373', 'Detmold für Groß- und Konzernbetriebsprüfung', 'Richthofenstrasse 94', '32756', 'Detmold', '05231/974-300', '0800 10092675373', '', '32706', '1664', '', '', '', '', '', '', '', 'Service@FA-5373.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5374', 'Dortmund für Groß- und Konzernbetriebsprüfung', 'Nußbaumweg 210', '44143', 'Dortmund', '0231/5188-8953', '0800 10092675374', '', '44047', '105039', '', '', '', '', '', '', '', 'Service@FA-5374.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5375', 'Hagen für Groß- und Konzernbetriebsprüfung', 'Hochstr. 43 - 45', '58095', 'Hagen', '02331/3760-0', '0800 10092675375', '', '', '', '', '', '', '', '', '', '', 'Service@FA-5375.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5376', 'Münster für Groß- und Konzernbetriebsprüfung', 'Andreas-Hofer-Straße 50', '48145', 'Münster', '0251/934-2115', '0800 10092675376', '', '', '', '', '', '', '', '', '', '', 'Service@FA-5376.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5381', 'Bielefeld f. Steuerfahndung und Steuerstrafsachen', 'Ravensberger Str. 90', '33607', 'Bielefeld', '0521/548-0', '0800 10092675381', '', '33511', '101173', '48000000', '48001500', 'BBK BIELEFELD', '48050161', '109', 'SPK BIELEFELD', '', 'Service@FA-5381.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5382', 'Bochum f. Steuerfahndung und Steuerstrafsachen', 'Uhlandstr. 37', '44791', 'Bochum', '0234/5878-0', '0800 10092675382', '', '44707', '100768', '43000000', '43001500', 'BBK BOCHUM', '43050001', '1300011', 'SPARKASSE BOCHUM', '', 'Service@FA-5382.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5383', 'Hagen f. Steuerfahndung und Steuerstrafsachen', 'Becheltestr. 32', '58089', 'Hagen', '02331/3089-0', '0800 10092675383', '', '58041', '4143', '45000000', '145001500', 'BBK HAGEN', '45050001', '100001580', 'SPARKASSE HAGEN', '', 'Service@FA-5383.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('5', '5384', 'Münster f. Steuerfahndung und Steuerstrafsachen', 'Hohenzollernring 80', '48145', 'Münster', '0251/9370-0', '0800 10092675384', '', '', '', '40000000', '40001501', 'BBK MUENSTER, WESTF', '40050150', '95031001', 'SPK MUENSTERLAND OST', '', 'Service@FA-5384.fin-nrw.de', '');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9101', 'Augsburg-Stadt Arbeitnehmerbereich', 'Prinzregentenpl. 2', '86150', 'Augsburg', '0821 506-01', '0821 506-2222', '', '86135', '10 00 65', '72000000', '72001500', 'BBK AUGSBURG', '72050000', '24109', 'ST SPK AUGSBURG', 'Servicezentrum: Mo-Mi 7:30-15:00 Uhr, Do 7:30-17:30 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-a-s.bayern.de', 'www.finanzamt-augsburg-stadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9102', 'Augsburg-Land ', 'Peutingerstr. 25', '86152', 'Augsburg', '0821 506-02', '0821 506-3270', '86144', '86031', '11 06 69', '72000000', '72001501', 'BBK AUGSBURG', '72050101', '8003', 'KR SPK AUGSBURG', 'Mo, Di, Do, Fr 8:00-12:00 Uhr, Mi geschlossen', 'poststelle@fa-a-l.bayern.de', 'www.finanzamt-augsburg-land.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9103', 'Augsburg-Stadt ', 'Prinzregentenpl. 2', '86150', 'Augsburg', '0821 506-01', '0821 506-2222', '', '86135', '10 00 65', '72000000', '72001500', 'BBK AUGSBURG', '72050000', '24109', 'ST SPK AUGSBURG', 'Servicezentrum: Mo-Mi 7:30-15:00 Uhr, Do 7:30-17:30 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-a-s.bayern.de', 'www.finanzamt-augsburg-stadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9104', 'Bad Tölz -Außenstelle des Finanzamts Wolfratshausen-', 'Prof.-Max-Lange-Platz 2', '83646', 'Bad Tölz', '08041 8005-0', '08041 8005-185', '', '83634', '1420', '70000000', '70001505', 'BBK MUENCHEN', '70054306', '31054', 'SPK BAD TOELZ-WOLFRATSHAUSE', 'Servicezentrum: Mo 7:30-18:00 Uhr, Di-Do 7:30-13:00 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-toel.bayern.de', 'www.finanzamt-bad-toelz.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9105', 'Berchtesgaden ', 'Salzburger Str. 6', '83471', 'Berchtesgaden', '08652 960-0', '08652 960-100', '', '83461', '1154', '71000000', '71001500', 'BBK MUENCHEN EH B REICHENHA', '71050000', '350009', 'SPK BERCHTESGADENER LAND', 'Servicezentrum: Mo-Do 7:30-13:30 Uhr (Nov-Mai Do 7:30-18:00 Uhr), Fr 7:30-12:00 Uhr', 'poststelle@fa-bgd.bayern.de', 'www.finanzamt-berchtesgaden.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9106', 'Burghausen ', 'Tittmoninger Str. 1', '84489', 'Burghausen', '08677 8706-0', '08677 8706-100', '', '84480', '1257', '71000000', '71001501', 'BBK MUENCHEN EH B REICHENHA', '71051010', '250001', 'KR SPK ALTOETTING-BURGHAUSE', 'Servicezentrum: Mo-Mi 7:45-15:00 Uhr Do 7:45-17:00 Uhr, Fr 7:45-12:00 Uhr', 'poststelle@fa-burgh.bayern.de', 'www.finanzamt-burghausen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9107', 'Dachau ', 'Bürgermeister-Zauner-Ring 2', '85221', 'Dachau', '08131 701-0', '08131 701-111', '85219', '85202', '1280', '70000000', '70001507', 'BBK MUENCHEN', '70051540', '908327', 'SPARKASSE DACHAU', 'Servicezentrum: Mo, Di, Do 7:30-15:00 Uhr (Nov-Mai Do 7:30-18:00 Uhr), Mi,Fr 7:30-12:00 Uhr', 'poststelle@fa-dah.bayern.de', 'www.finanzamt-dachau.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9108', 'Deggendorf ', 'Pfleggasse 18', '94469', 'Deggendorf', '0991 384-0', '0991 384-150', '', '94453', '1355', '75000000', '75001506', 'BBK REGENSBURG', '74150000', '380019950', 'SPK DEGGENDORF', 'Servicezentrum: Mo, Di, Do 7:45-15:00 Uhr (Jan-Mai Do 7:45-18:00 Uhr), Mi, Fr 7:45-12:00 Uhr', 'poststelle@fa-deg.bayern.de', 'www.finanzamt-deggendorf.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9109', 'Dillingen ', 'Schloßstr. 3', '89407', 'Dillingen', '09071 507-0', '09071 507-300', '89401', '', '', '72000000', '72001503', 'BBK AUGSBURG', '72251520', '24066', 'KR U ST SPK DILLINGEN', 'Servicezentrum: Mo, Di, Mi, Fr 7:30-13:00 Uhr, Do 7:30-13:00 Uhr u. 14:00-18:00 Uhr', 'poststelle@fa-dlg.bayern.de', 'www.finanzamt-dillingen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9110', 'Dingolfing ', 'Obere Stadt 44', '84130', 'Dingolfing', '08731 504-0', '08731 504-190', '', '84122', '1156', '74300000', '74301501', 'BBK REGENSBURG EH LANDSHUT', '74351310', '100017805', 'SPK DINGOLFING-LANDAU', 'Servicezentrum: Mo-Di 7:30-15:00 Uhr, Mi, Fr 7:30-12:00 Uhr, Do 7:30-17:00 Uhr', 'poststelle@fa-dgf.bayern.de', 'www.finanzamt-dingolfing.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9111', 'Donauwörth -Außenstelle des Finanzamts Nördlingen-', 'Sallingerstr. 2', '86609', 'Donauwörth', '0906 77-0', '0906 77-150', '86607', '', '', '72000000', '72001502', 'BBK AUGSBURG', '70010080', '1632-809', 'POSTBANK -GIRO- MUENCHEN', 'Servicezentrum: Mo-Mi 7:30-13:30 Uhr, Do 7:30-18:00 Uhr, Fr 7:30 -13:00 Uhr', 'poststelle@fa-don.bayern.de', 'www.finanzamt-donauwoerth.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9112', 'Ebersberg ', 'Schloßplatz 1-3', '85560', 'Ebersberg', '08092 267-0', '08092 267-102', '', '', '', '70000000', '70001508', 'BBK MUENCHEN', '70051805', '75', 'KR SPK EBERSBERG', 'Servicezentrum: Mo-Do 7:30-13:00 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-ebe.bayern.de', 'www.finanzamt-ebersberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9113', 'Eggenfelden ', 'Pfarrkirchner Str. 71', '84307', 'Eggenfelden', '08721 981-0', '08721 981-200', '', '84301', '1160', '74300000', '74301502', 'BBK REGENSBURG EH LANDSHUT', '74351430', '5603', 'SPK ROTTAL-INN EGGENFELDEN', 'Servicezentrum: Mo, Di, Do 7:45-15:00 Uhr (Jan-Mai Do 7:45-17:00 Uhr), Mi, Fr 7:30-12:00 Uhr', 'poststelle@fa-eg.bayern.de', 'www.finanzamt-eggenfelden.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9114', 'Erding ', 'Münchener Str. 31', '85435', 'Erding', '08122 188-0', '08122 188-150', '', '85422', '1262', '70000000', '70001509', 'BBK MUENCHEN', '70051995', '8003', 'SPK ERDING-DORFEN', 'Servicezentrum: Mo-Mi 7:30-14:00 Uhr Do 7:30-18:00 Uhr, Fr 7:30 -12:00 Uhr', 'poststelle@fa-ed.bayern.de', 'www.finanzamt-erding.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9115', 'Freising ', 'Prinz-Ludwig-Str. 26', '85354', 'Freising', '08161 493-0', '08161 493-106', '85350', '85313', '1343', '70000000', '70001510', 'BBK MUENCHEN', '70021180', '4001010', 'HYPOVEREINSBK FREISING', 'Servicezentrum: Mo-Di 7:30-15:00 Uhr, Mi, Fr 7:30-12:00 Uhr, Do 7:30-18:00 Uhr', 'poststelle@fa-fs.bayern.de', 'www.finanzamt-freising.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9117', 'Fürstenfeldbruck ', 'Münchner Str.36', '82256', 'Fürstenfeldbruck', '08141 60-0', '08141 60-150', '', '82242', '1261', '70000000', '70001511', 'BBK MUENCHEN', '70053070', '8007221', 'SPK FUERSTENFELDBRUCK', 'Servicezentrum: Mo-Mi 7:30-14:30 Uhr, Do 7:30-17:30 Uhr, Fr 7:30 -12:30 Uhr', 'poststelle@fa-ffb.bayern.de', 'www.finanzamt-fuerstenfeldbruck.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9118', 'Füssen -Außenstelle des Finanzamts Kaufbeuren-', 'Rupprechtstr. 1', '87629', 'Füssen', '08362 5056-0', '08362 5056-290', '', '87620', '1460', '73300000', '73301510', 'BBK AUGSBURG EH KEMPTEN', '73350000', '310500525', 'SPARKASSE ALLGAEU', 'Servicezentrum: Mo-Mi 8:00-15:00 Uhr, Do 8:00-18:00 Uhr, Fr 8:00-13:00 Uhr', 'poststelle@fa-fues.bayern.de', 'www.finanzamt-fuessen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9119', 'Garmisch-Partenkirchen ', 'Von-Brug-Str. 5', '82467', 'Garmisch-Partenkirchen', '08821 700-0', '08821 700-111', '', '82453', '1363', '70000000', '70001520', 'BBK MUENCHEN', '70350000', '505', 'KR SPK GARMISCH-PARTENKIRCH', 'Servicezentrum: Mo-Mi 7:30-14:00 Uhr, Do 7:30-18:00 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-gap.bayern.de', 'www.finanzamt-garmisch-partenkirchen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9120', 'Bad Griesbach -Außenstelle des Finanzamts Passau-', 'Schloßhof 5-6', '94086', 'Bad Griesbach', '0851 504-0', '0851 504-2222', '', '94083', '1222', '74000000', '74001500', 'BBK REGENSBURG EH PASSAU', '74050000', '16170', 'SPK PASSAU', 'Servicezentrum: Mo-Mi 7:30-14:00 Uhr, Do 7:30-17:00 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-griesb.bayern.de', 'www.finanzamt-bad-griesbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9121', 'Günzburg ', 'Schloßpl. 4', '89312', 'Günzburg', '08221 902-0', '08221 902-209', '', '89302', '1241', '72000000', '72001505', 'BBK AUGSBURG', '72051840', '18', 'SPK GUENZBURG-KRUMBACH', 'Servicezentrum: Mo-Di 7:45-12:30 u. 13:30-15:30, Mi, Fr 7:45-12:30, Do 7:45-12:30 u. 13:30-18:00', 'poststelle@fa-gz.bayern.de', 'www.finanzamt-guenzburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9123', 'Immenstadt -Außenstelle des Finanzamts Kempten-', 'Rothenfelsstr. 18', '87509', 'Immenstadt', '08323 801-0', '08323 801-235', '', '87502', '1251', '73300000', '73301520', 'BBK AUGSBURG EH KEMPTEN', '73350000', '113464', 'SPARKASSE ALLGAEU', 'Servicezentrum: Mo-Do 7:30-14:00 Uhr (Okt-Mai Do 7:30-18:00 Uhr), Fr 7:30-12:00 Uhr', 'poststelle@fa-immen.bayern.de', 'www.finanzamt-immenstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9124', 'Ingolstadt ', 'Esplanade 38', '85049', 'Ingolstadt', '0841 311-0', '0841 311-133', '', '85019', '210451', '72100000', '72101500', 'BBK MUENCHEN EH INGOLSTADT', '72150000', '25 080', 'SPARKASSE INGOLSTADT', 'Servicezentrum: Mo-Di 7:15-13:30, Mi 7:15-12:30, Do 7:15-17:30, Fr 7:15-12:00', 'poststelle@fa-in.bayern.de', 'www.finanzamt-ingolstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9125', 'Kaufbeuren ', 'Remboldstr. 21', '87600', 'Kaufbeuren', '08341 802-0', '08341 802-221', '', '87572', '1260', '73300000', '73401500', 'BBK AUGSBURG EH KEMPTEN', '73450000', '25700', 'KR U ST SPK KAUFBEUREN', 'Servicezentrum: Mo-Mi 7:30-14:00 Uhr, Do 7:30-18:00 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-kf.bayern.de', 'www.finanzamt-kaufbeuren.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9126', 'Kelheim ', 'Klosterstr. 1', '93309', 'Kelheim', '09441 201-0', '09441 201-201', '', '93302', '1252', '75000000', '75001501', 'BBK REGENSBURG', '75051565', '190201301', 'KREISSPARKASSE KELHEIM', 'Servicezentrum: Mo-Mi 7:30-15:00 Uhr, Do 7:30-17:00 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-keh.bayern.de', 'www.finanzamt-kelheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9127', 'Kempten (Allgäu) ', 'Am Stadtpark 3', '87435', 'Kempten', '0831 256-0', '0831 256-260', '', '87405', '1520', '73300000', '73301500', 'BBK AUGSBURG EH KEMPTEN', '73350000', '117', 'SPARKASSE ALLGAEU', 'Servicezentrum: Mo-Do 7:30-14:30 Uhr (Nov-Mai Do 7:20-17:00 Uhr), Fr 7:30-12:00 Uhr', 'poststelle@fa-ke.bayern.de', 'www.finanzamt-kempten.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9131', 'Landsberg ', 'Israel-Beker-Str. 20', '86899', 'Landsberg', '08191 332-0', '08191 332-108', '86896', '', '', '72000000', '72001504', 'BBK AUGSBURG', '70052060', '158', 'SPK LANDSBERG-DIESSEN', 'Servicezentrum: Mo-Mi 7:30-15:00 Uhr, Do 7:30-16:00 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-ll.bayern.de', 'www.finanzamt-landsberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9132', 'Landshut ', 'Maximilianstr. 21', '84028', 'Landshut', '0871 8529-000', '0871 8529-360', '', '', '', '74300000', '74301500', 'BBK REGENSBURG EH LANDSHUT', '74350000', '10111', 'SPK LANDSHUT', 'Servicezentrum: Mo-Di 8:00-15:00 Uhr, Mi, Fr 8:00-12:00 Uhr, Do 8:00-18:00 Uhr', 'poststelle@fa-la.bayern.de', 'www.finanzamt-landshut.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9133', 'Laufen - Außenstelle des Finanzamts Berchtesgaden-', 'Rottmayrstr. 13', '83410', 'Laufen', '08682 918-0', '08682 918-100', '', '83406', '1251', '71000000', '71001502', 'BBK MUENCHEN EH B REICHENHA', '71050000', '59998', 'SPK BERCHTESGADENER LAND', 'Servicezentrum: Mo-Do 7:30-13:30 Uhr (Nov-Mai Do 7:30-18:00 Uhr), Fr 7:30-12:00 Uhr', 'poststelle@fa-lauf.bayern.de', 'www.finanzamt-laufen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9134', 'Lindau ', 'Brettermarkt 4', '88131', 'Lindau', '08382 916-0', '08382 916-100', '', '88103', '1320', '73300000', '73501500', 'BBK AUGSBURG EH KEMPTEN', '73150000', '620018333', 'SPK MEMMINGEN-LINDAU-MINDEL', 'Servicezentrum: Mo-Do 7:30-14:00 Uhr (Nov-Mai Do 7:30-18:00 Uhr), Fr 7:30-12:00 Uhr', 'poststelle@fa-li.bayern.de', 'www.finanzamt-lindau.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9138', 'Memmingen ', 'Bodenseestr. 6', '87700', 'Memmingen', '08331 608-0', '08331 608-165', '', '87683', '1345', '73100000', '73101500', 'BBK AUGSBURG EH MEMMINGEN', '73150000', '210005', 'SPK MEMMINGEN-LINDAU-MINDEL', 'Servicezentrum: Mo-Do 7:30-14:00 Uhr, (Nov-Mai Do 7:30-18:00 Uhr), Fr 7:30-12:00 Uhr', 'poststelle@fa-mm.bayern.de', 'www.finanzamt-memmingen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9139', 'Miesbach ', 'Schlierseer Str. 5', '83714', 'Miesbach', '08025 709-0', '08025 709-500', '', '83711', '302', '70000000', '70001512', 'BBK MUENCHEN', '71152570', '4002', 'KR SPK MIESBACH-TEGERNSEE', 'Servicezentrum: Mo, Di, Mi, Fr 7:30-14:00 Uhr, Do 7:30-18:00 Uhr', 'poststelle@fa-mb.bayern.de', 'www.finanzamt-miesbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9140', 'Mindelheim -Außenstelle des Finanzamts Memmingen-', 'Bahnhofstr. 16', '87719', 'Mindelheim', '08261 9912-0', '08261 9912-300', '', '87711', '1165', '73100000', '73101502', 'BBK AUGSBURG EH MEMMINGEN', '73150000', '810004788', 'SPK MEMMINGEN-LINDAU-MINDEL', 'Servicezentrum: Mo-Mi 7:30-12:00 u. 13:30-15:30, Do 7:30-12:00 u. 13:30-17:30, Fr 7:30-12:00', 'poststelle@fa-mn.bayern.de', 'www.finanzamt-mindelheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9141', 'Mühldorf ', 'Katharinenplatz 16', '84453', 'Mühldorf', '08631 616-0', '08631 616-100', '', '84445', '1369', '71100000', '71101501', 'BBK MUENCHEN EH ROSENHEIM', '71151020', '885', 'KR SPK MUEHLDORF', 'Servicezentrum: Mo-Mi 7:30-14:00 Uhr, Do 7:30-18:00 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-mue.bayern.de', 'www.finanzamt-muehldorf.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9142', 'München f. Körpersch. Bewertung des Grundbesitzes', 'Meiserstr. 4', '80333', 'München', '089 1252-0', '089 1252-7777', '80275', '80008', '20 09 26', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Mo, Di, Do, Fr 8:00-12:00 Uhr, Mi geschlossen', 'poststelle@fa-m-koe.bayern.de', 'www.finanzamt-muenchen-koerperschaften.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9143', 'München f. Körpersch. Körperschaftsteuer', 'Meiserstr. 4', '80333', 'München', '089 1252-0', '089 1252-7777', '80275', '80008', '20 09 26', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Mo, Di, Do, Fr 8:00-12:00 Uhr, Mi geschlossen', 'poststelle@fa-m-koe.bayern.de', 'www.finanzamt-muenchen-koerperschaften.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9144', 'München I ', 'Karlstr. 9-11', '80333', 'München', '089 1252-0', '089 1252-1111', '80276', '80008', '20 09 05', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Servicezentrum Deroystr. 6: Mo-Mi 7:30-16:00, Do 7:30-18:00, Fr 7:30-12:30 (i. Ü. nach Vereinb.)', 'poststelle@fa-m1.bayern.de', 'www.finanzamt-muenchen-I.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9145', 'München III ', 'Deroystr. 18', '80335', 'München', '089 1252-0', '089 1252-3333', '80301', '', '', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Servicezentrum Deroystr. 6: Mo-Mi 7:30-16:00, Do 7:30-18:00, Fr 7:30-12:30 (i. Ü. nach Vereinb.)', 'poststelle@fa-m3.bayern.de', 'www.finanzamt-muenchen-III.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9146', 'München IV ', 'Deroystr. 4 Aufgang I', '80335', 'München', '089 1252-0', '089 1252-4000', '80302', '', '', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Servicezentrum Deroystr. 6: Mo-Mi 7:30-16:00, Do 7:30-18:00, Fr 7:30-12:30 (i. Ü. nach Vereinb.)', 'poststelle@fa-m4.bayern.de', 'www.finanzamt-muenchen-IV.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9147', 'München II ', 'Deroystr. 20', '80335', 'München', '089 1252-0', '089 1252-2222', '80269', '', '', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Servicezentrum Deroystr. 6: Mo-Mi 7:30-16:00, Do 7:30-18:00, Fr 7:30-12:30 (i. Ü. nach Vereinb.)', 'poststelle@fa-m2.bayern.de', 'www.finanzamt-muenchen-II.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9148', 'München V ', 'Deroystr. 4 Aufgang II', '80335', 'München', '089 1252-0', '089 1252-5281', '80303', '', '', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Servicezentrum Deroystr. 6: Mo-Mi 7:30-16:00, Do 7:30-18:00, Fr 7:30-12:30 (i. Ü. nach Vereinb.)', 'poststelle@fa-m5.bayern.de', 'www.finanzamt-muenchen-V.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9149', 'München-Zentral Erhebung, Vollstreckung', 'Winzererstr. 47a', '80797', 'München', '089 3065-0', '089 3065-1900', '80784', '', '', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Mo, Di, Do, Fr 8:00-12:00 Uhr, Mi geschlossen', 'poststelle@fa-m-zfa.bayern.de', 'www.finanzamt-muenchen-zentral.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9150', 'Neuburg -Außenstelle des Finanzamts Schrobenhausen-', 'Fünfzehnerstr. 7', '86633', 'Neuburg', '08252 918-0', '08252 918-222', '', '86618', '1320', '72100000', '72101505', 'BBK MUENCHEN EH INGOLSTADT', '72151880', '104000', 'ST SPK SCHROBENHAUSEN', 'Servicezentrum: Mo-Mi 7:30-15:00 Uhr, Do 7:30-18:00 Uhr, Fr 7:30-12:30 Uhr', 'poststelle@fa-nd.bayern.de', 'www.finanzamt-neuburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9151', 'Neu-Ulm ', 'Nelsonallee 5', '89231', 'Neu-Ulm', '0731 7045-0', '0731 7045-500', '89229', '89204', '1460', '63000000', '63001501', 'BBK ULM, DONAU', '73050000', '430008425', 'SPK NEU-ULM ILLERTISSEN', 'Servicezentrum: Mo, Di, Mi, Fr 8:00-13:00 Uhr, Do 8:00-13:00 Uhr u. 14:00-18:00 Uhr', 'poststelle@fa-nu.bayern.de', 'www.finanzamt-neu-ulm.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9152', 'Nördlingen ', 'Tändelmarkt 1', '86720', 'Nördlingen', '09081 215-0', '09081 215-100', '', '86715', '1521', '72000000', '72001506', 'BBK AUGSBURG', '72250000', '111500', 'SPARKASSE NOERDLINGEN', 'Servicezentrum: Mo, Di, Mi, Fr 7:30-13:00 Uhr, Do 7:30-13:00 Uhr u. 14:00-18:00 Uhr', 'poststelle@fa-noe.bayern.de', 'www.finanzamt-noerdlingen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9153', 'Passau mit Außenstellen ', 'Innstr. 36', '94032', 'Passau', '0851 504-0', '0851 504-1410', '', '94030', '1450', '74000000', '740 01500', 'BBK REGENSBURG EH PASSAU', '74050000', '16170', 'SPK PASSAU', 'Servicezentrum: Mo-Mi 7:30-15:00 Uhr, Do 7:30-17:00 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-pa.bayern.de', 'www.finanzamt-passau.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9154', 'Pfaffenhofen ', 'Schirmbeckstr. 5', '85276', 'Pfaffenhofen a. d. Ilm', '08441 77-0', '08441 77-199', '', '85265', '1543', '72100000', '72101504', 'BBK MUENCHEN EH INGOLSTADT', '72151650', '7302', 'VER SPK PFAFFENHOFEN', 'Servicezentrum: Mo-Mi 7:30-14:30 Uhr, Do 7:30-17:30 Uhr, Fr 7:30-12:30 Uhr', 'poststelle@fa-paf.bayern.de', 'www.finanzamt-pfaffenhofen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9156', 'Rosenheim m. ASt Wasserburg ', 'Wittelsbacherstr. 25', '83022', 'Rosenheim', '08031 201-0', '08031 201-222', '', '83002', '100255', '71100000', '71101500', 'BBK MUENCHEN EH ROSENHEIM', '71150000', '34462', 'SPK ROSENHEIM', 'Servicezentrum: Mo-Do 7:30-14:00 Uhr, (Okt-Mai Do 7:30-17:00 Uhr), Fr 7:30-12.00 Uhr', 'poststelle@fa-ro.bayern.de', 'www.finanzamt-rosenheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9157', 'Grafenau ', 'Friedhofstr. 1', '94481', 'Grafenau', '08552 423-0', '08552 423-170', '', '', '', '75000000', '75001507', 'BBK REGENSBURG', '70010080', '1621-806', 'POSTBANK -GIRO- MUENCHEN', 'Servicezentrum: Mo, Di 7:30-15:00 Uhr, Mi, Fr 7:30-12:00 Uhr, Do 7:30-18:00 Uhr', 'poststelle@fa-gra.bayern.de', 'www.finanzamt-grafenau.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9158', 'Schongau - Außenstelle des Finanzamts Weilheim-Schongau -', 'Rentamtstr. 1', '86956', 'Schongau', '0881 184-0', '0881 184-373', '', '86951', '1147', '70000000', '70001521', 'BBK MUENCHEN', '70351030', '20149', 'VER SPK WEILHEIM', 'Servicezentrum: Mo-Do 7:30-14:00 Uhr (Okt-Jun Do 7:30-17:30 Uhr), Fr 7:30-12:00 Uhr', 'poststelle@fa-sog.bayern.de', 'www.finanzamt-schongau.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9159', 'Schrobenhausen m. ASt Neuburg  ', 'Rot-Kreuz-Str. 2', '86529', 'Schrobenhausen', '08252 918-0', '08252 918-430', '', '86522', '1269', '72100000', '72101505', 'BBK MUENCHEN EH INGOLSTADT', '72151880', '104000', 'ST SPK SCHROBENHAUSEN', 'Servicezentrum: Mo-Mi 7:30-15:00 Uhr, Do 7:30-18:00 Uhr, Fr 7:30-12:30 Uhr', 'poststelle@fa-sob.bayern.de', 'www.finanzamt-schrobenhausen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9161', 'Starnberg ', 'Schloßbergstr.', '82319', 'Starnberg', '08151 778-0', '08151 778-250', '', '82317', '1251', '70000000', '70001513', 'BBK MUENCHEN', '70250150', '430064295', 'KR SPK MUENCHEN STARNBERG', 'Servicezentrum: Mo-Mi 7:30-15:00 Uhr, Do 7:30-18:00 Uhr, Fr 7:30-13:00 Uhr', 'poststelle@fa-sta.bayern.de', 'www.finanzamt-starnberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9162', 'Straubing ', 'Fürstenstr. 9', '94315', 'Straubing', '09421 941-0', '09421 941-272', '', '94301', '151', '75000000', '75001502', 'BBK REGENSBURG', '74250000', '240017707', 'SPK STRAUBING-BOGEN', 'Servicezentrum: Mo, Di, Mi, Fr 7:30-13:00 Uhr, Do 7:30-18:00 Uhr', 'poststelle@fa-sr.bayern.de', 'www.finanzamt-straubing.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9163', 'Traunstein ', 'Herzog-Otto-Str. 6', '83278', 'Traunstein', '0861 701-0', '0861 701-338', '83276', '83263', '1309', '71000000', '71001503', 'BBK MUENCHEN EH B REICHENHA', '71052050', '7070', 'KR SPK TRAUNSTEIN-TROSTBERG', 'Servicezentrum: Mo-Do 7:30-14:00 Uhr (Okt.-Mai Do 7:30-18:00 Uhr), Fr 7:30-12:00 Uhr', 'poststelle@fa-ts.bayern.de', 'www.finanzamt-traunstein.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9164', 'Viechtach -Außenstelle des Finanzamts Zwiesel-', 'Mönchshofstr. 27', '94234', 'Viechtach', '09922 507-0', '09922 507-399', '', '94228', '1162', '75000000', '75001508', 'BBK REGENSBURG', '74151450', '240001008', 'SPARKASSE REGEN-VIECHTACH', 'Servicezentrum: Mo-Di 7:45-15:00 Uhr, Mi, Fr 7:45-12:00 Uhr, Do 7:45-18:00 Uhr', 'poststelle@fa-viech.bayern.de', 'www.finanzamt-viechtach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9166', 'Vilshofen -Außenstelle des Finanzamts Passau-', 'Kapuzinerstr. 36', '94474', 'Vilshofen', '0851 504-0', '0851 504-2465', '', '', '', '74000000', '74001500', 'BBK REGENSBURG EH PASSAU', '74050000', '16170', 'SPK PASSAU', 'Servicezentrum: Mo-Mi 7:30-14:00 Uhr, Do 7:30-17:00 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-vof.bayern.de', 'www.finanzamt-vilshofen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9167', 'Wasserburg -Außenstelle des Finanzamts Rosenheim-', 'Rosenheimer Str. 16', '83512', 'Wasserburg', '08037 201-0', '08037 201-150', '', '83502', '1280', '71100000', '71101500', 'BBK MUENCHEN EH ROSENHEIM', '71150000', '34462', 'SPK ROSENHEIM', 'Servicezentrum: Mo-Do 7:30-14:00 Uhr, (Okt-Mai Do 7:30-17:00 Uhr), Fr 7:30-12.00 Uhr', 'poststelle@fa-ws.bayern.de', 'www.finanzamt-wasserburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9168', 'Weilheim-Schongau ', 'Hofstr. 23', '82362', 'Weilheim', '0881 184-0', '0881 184-500', '', '82352', '1264', '70000000', '70001521', 'BBK MUENCHEN', '70351030', '20149', 'VER SPK WEILHEIM', 'Servicezentrum: Mo-Do 7:30-14:00 Uhr (Okt-Jun Do 7:30-17:30 Uhr), Fr 7:30-12:00 Uhr', 'poststelle@fa-wm.bayern.de', 'www.finanzamt-weilheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9169', 'Wolfratshausen ', 'Heimgartenstr. 5', '82515', 'Wolfratshausen', '08171 25-0', '08171 25-150', '', '82504', '1444', '70000000', '70001514', 'BBK MUENCHEN', '70054306', '505', 'SPK BAD TOELZ-WOLFRATSHAUSE', 'Servicezentrum: Mo-MI 7:30-14:00 Uhr, Do 7:30-17:00 Uhr, Fr 7:30-12:30 Uhr', 'poststelle@fa-wor.bayern.de', 'www.finanzamt-wolfratshausen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9170', 'Zwiesel m. ASt Viechtach ', 'Stadtplatz 16', '94227', 'Zwiesel', '09922 507-0', '09922 507-200', '', '94221', '1262', '75000000', '75001508', 'BBK REGENSBURG', '74151450', '240001008', 'SPARKASSE REGEN-VIECHTACH', 'Servicezentrum: Mo-Di 7:45-15:00 Uhr, Mi, Fr 7:45-12:00 Uhr, Do 7:45-18:00 Uhr', 'poststelle@fa-zwi.bayern.de', 'www.finanzamt-zwiesel.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9171', 'Eichstätt ', 'Residenzplatz 8', '85072', 'Eichstätt', '08421 6007-0', '08421 6007-400', '85071', '85065', '1163', '72100000', '72101501', 'BBK MUENCHEN EH INGOLSTADT', '72151340', '1214', 'SPARKASSE EICHSTAETT', 'Servicezentrum: Mo, Di, Mi 7:30-14:00 Uhr, Do 7:30-18:00 Uhr, Fr 7:30-12:00 Uhr', 'poststelle@fa-ei.bayern.de', 'www.finanzamt-eichstaett.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9180', 'München f. Körpersch. ', 'Meiserstr. 4', '80333', 'München', '089 1252-0', '089 1252-7777', '80275', '80008', '20 09 26', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Mo, Di, Do, Fr 8:00-12:00 Uhr, Mi geschlossen', 'poststelle@fa-m-koe.bayern.de', 'www.finanzamt-muenchen-koerperschaften.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9181', 'München I Arbeitnehmerbereich', 'Karlstr. 9/11', '80333', 'München', '089 1252-0', '089 1252-1111', '80276', '80008', '20 09 05', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Servicezentrum Deroystr. 6: Mo-Mi 7:30-16:00, Do 7:30-18:00, Fr 7:30-12:30 (i. Ü. nach Vereinb.)', 'Poststelle@fa-m1-BS.bayern.de', 'www.finanzamt-muenchen-I.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9182', 'München II Arbeitnehmerbereich', 'Deroystr. 20', '80335', 'München', '089 1252-0', '089 1252-2888', '80269', '', '', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Servicezentrum Deroystr. 6: Mo-Mi 7:30-16:00, Do 7:30-18:00, Fr 7:30-12:30 (i. Ü. nach Vereinb.)', 'Poststelle@fa-m2-BS.bayern.de', 'www.finanzamt-muenchen-II.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9183', 'München III Arbeitnehmerbereich', 'Deroystr. 18', '80335', 'München', '089 1252-0', '089 1252-3788', '80301', '', '', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Servicezentrum Deroystr. 6: Mo-Mi 7:30-16:00, Do 7:30-18:00, Fr 7:30-12:30 (i. Ü. nach Vereinb.)', 'Poststelle@fa-m3-BS.bayern.de', 'www.finanzamt-muenchen-III.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9184', 'München IV Arbeitnehmerbereich', 'Deroystr. 4 Aufgang I', '80335', 'München', '089 1252-0', '089 1252-4820', '80302', '', '', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Servicezentrum Deroystr. 6: Mo-Mi 7:30-16:00, Do 7:30-18:00, Fr 7:30-12:30 (i. Ü. nach Vereinb.)', 'Poststelle@fa-m4-BS.bayern.de', 'www.finanzamt-muenchen-IV.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9185', 'München V Arbeitnehmerbereich', 'Deroystr. 4 Aufgang II', '80335', 'München', '089 1252-0', '089 1252-5799', '80303', '', '', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Servicezentrum Deroystr. 6: Mo-Mi 7:30-16:00, Do 7:30-18:00, Fr 7:30-12:30 (i. Ü. nach Vereinb.)', 'Poststelle@fa-m5-BS.bayern.de', 'www.finanzamt-muenchen-V.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9187', 'München f. Körpersch. ', 'Meiserstr. 4', '80333', 'München', '089 1252-0', '089 1252-7777', '80275', '80008', '20 09 26', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Mo, Di, Do, Fr 8:00-12:00 Uhr, Mi geschlossen', 'poststelle@fa-m-koe.bayern.de', 'www.finanzamt-muenchen-koerperschaften.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9189', 'München-Zentral Kraftfahrzeugsteuer', 'Winzererstr. 47a', '80797', 'München', '089 3065-0', '089 3065-1900', '80784', '', '', '70050000', '24962', 'BAYERNLB MUENCHEN', '70000000', '70001506', 'BBK MUENCHEN', 'Mo, Di, Do, Fr 8:00-12:00 Uhr, Mi geschlossen', 'poststelle@fa-m-zfa.bayern.de', 'www.finanzamt-muenchen-zentral.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9201', 'Amberg ', 'Kirchensteig 2', '92224', 'Amberg', '09621 36-0', '09621 36-413', '', '92204', '1452', '75300000', '75301503', 'BBK REGENSBURG EH WEIDEN', '75250000', '190011122', 'SPARKASSE AMBERG-SULZBACH', 'Servicezentrum: Mo, Die, Mi, Fr: 07:30 - 12:00 UhrDo: 07:30 - 17:30 Uhr', 'poststelle@fa-am.bayern.de', 'www.finanzamt-amberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9202', 'Obernburg a. Main mit Außenstelle Amorbach', 'Schneeberger Str. 1', '63916', 'Amorbach', '09373 202-0', '09373 202-100', '', '63912', '1160', '79500000', '79501502', 'BBK WUERZBURG EH ASCHAFFENB', '79650000', '620300111', 'SPK MILTENBERG-OBERNBURG', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-amorb.bayern.de', 'www.finanzamt-amorbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9203', 'Ansbach mit Außenstellen', 'Mozartstr. 25', '91522', 'Ansbach', '0981 16-0', '0981 16-333', '', '91511', '608', '76500000', '76501500', 'BBK NUERNBERG EH ANSBACH', '76550000', '215004', 'VER SPK ANSBACH', 'Servicezentrum: Mo - Mi: 08:00 - 14:00 Uhr, Do: 08:00 - 18:00 Uhr, Fr: 08:00', 'poststelle@fa-an.bayern.de', 'www.finanzamt-ansbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9204', 'Aschaffenburg ', 'Auhofstr. 13', '63741', 'Aschaffenburg', '06021 492-0', '06021 492-1000', '63736', '', '', '79500000', '79501500', 'BBK WUERZBURG EH ASCHAFFENB', '79550000', '8375', 'SPK ASCHAFFENBURG ALZENAU', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 8:00 - 18:00 Uhr, Fr: 08:00', 'poststelle@fa-ab.bayern.de', 'www.finanzamt-aschaffenburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9205', 'Bad Kissingen ', 'Bibrastr. 10', '97688', 'Bad Kissingen', '0971 8021-0', '0971 8021-200', '', '97663', '1360', '79300000', '79301501', 'BBK WUERZBURG EH SCHWEINFUR', '79351010', '10009', 'SPK BAD KISSINGEN', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-kg.bayern.de', '/www.finanzamt-bad-kissingen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9206', 'Bad Neustadt a.d.S. ', 'Meininger Str. 39', '97616', 'Bad Neustadt', '09771 9104-0', '09771 9104-444', '97615', '', '', '79300000', '79301502', 'BBK WUERZBURG EH SCHWEINFUR', '79353090', '7005', 'SPK BAD NEUSTADT A D SAALE', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-nes.bayern.de', 'www.finanzamt-bad-neustadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9207', 'Bamberg ', 'Martin-Luther-Str. 1', '96050', 'Bamberg', '0951 84-0', '0951 84-230', '96045', '', '', '77000000', '77001500', 'BBK NUERNBERG EH BAMBERG', '77050000', '30700', 'SPK BAMBERG', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 18:00 Uhr, Fr: 08:00', 'poststelle@fa-ba.bayern.de', 'www.finanzamt-bamberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9208', 'Bayreuth ', 'Maximilianstr. 12/14', '95444', 'Bayreuth', '0921 609-0', '0921 609-254', '', '95422', '110361', '77300000', '773 01500', 'BBK BAYREUTH', '77350110', '9033333', 'SPARKASSE BAYREUTH', 'Servicezentrum: Mo - Mi: 07:30 - 14:00 Uhr, Do: 07:30 - 17:00 Uhr, Fr: 07:30', 'poststelle@fa-bt.bayern.de', 'www.finanzamt-bayreuth.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9211', 'Cham mit Außenstellen ', 'Reberstr. 2', '93413', 'Cham', '09971 488-0', '09971 488-199', '', '93402', '1253', '74221170', '344 755 205', 'HYPOVEREINSBK CHAM, OBERPF', '76010085', '1735-858', 'POSTBANK NUERNBERG', 'Servicezentrum: Mo - Mi: 07:30 - 15:00 Uhr, Do: 07:30 - 18:00 Uhr, Fr: 07:30', 'poststelle@fa-cha.bayern.de', 'www.finanzamt-cham.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9212', 'Coburg ', 'Rodacher Straße 4', '96450', 'Coburg', '09561 646-0', '09561 646-130', '', '96406', '1653', '77000000', '78301500', 'BBK NUERNBERG EH BAMBERG', '78350000', '7450', 'VER SPK COBURG', 'Servicezentrum: Mo - Fr: 08:00 - 13:00 Uhr, Do: 14:00 - 18:00 Uhr', 'poststelle@fa-co.bayern.de', 'www.finanzamt-coburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9213', 'Dinkelsbühl - Außenstelle des  Finanzamts Ansbach -', 'Föhrenberggasse 30', '91550', 'Dinkelsbühl', '0981 16-0', '09851 5737-607', '', '', '', '76500000', '76501500', 'BBK NUERNBERG EH ANSBACH', '76550000', '215004', 'VER SPK ANSBACH', 'Servicezentrum: Mo - Mi: 08:00 - 14:00, Do: 08:00 - 18:00 Uhr, Fr: 08:00 -', 'poststelle@fa-dkb.bayern.de', 'www.finanzamt-dinkelsbuehl.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9214', 'Ebern - Außenstelle des Finanzamts Zeil -', 'Rittergasse 1', '96104', 'Ebern', '09524 824-0', '09524 824-225', '', '', '', '79300000', '79301505', 'BBK WUERZBURG EH SCHWEINFUR', '79351730', '500900', 'SPK OSTUNTERFRANKEN', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-ebn.bayern.de', 'www.finanzamt-ebern.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9216', 'Erlangen ', 'Schubertstr 10', '91052', 'Erlangen', '09131 121-0', '09131 121-369', '91051', '', '', '76000000', '76001507', 'BBK NUERNBERG', '76350000', '2929', 'ST U KR SPK ERLANGEN', 'Servicezentrum: Mo - Mi: 08:00 - 14:00 Uhr, Do: 08:00 - 18:00 Uhr, Fr: 08:00', 'poststelle@fa-er.bayern.de', 'www.finanzamt-erlangen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9217', 'Forchheim ', 'Dechant-Reuder-Str. 6', '91301', 'Forchheim', '09191 626-0', '09191 626-200', '91299', '', '', '76000000', '76001508', 'BBK NUERNBERG', '76351040', '91', 'SPARKASSE FORCHHEIM', 'Servicezentrum: Mo - Mi: 08:00 - 13:00 Uhr, Do: 08:00 - 17:30, Fr: 08:00 -', 'poststelle@fa-fo.bayern.de', 'www.finanzamt-forchheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9218', 'Fürth ', 'Herrnstraße 69', '90763', 'Fürth', '0911 7435-0', '0911 7435-350', '90744', '', '', '76000000', '76201500', 'BBK NUERNBERG', '76250000', '18200', 'SPK FUERTH', 'Servicezentrum: Mo - Mi: 08:00 - 14:00 Uhr, Do: 08:00 - 18:00 Uhr, Fr: 08:00', 'poststelle@fa-fue.bayern.de', 'www.finanzamt-fuerth.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9220', 'Gunzenhausen ', 'Hindenburgplatz 1', '91710', 'Gunzenhausen', '09831 8009-0', '09831 8009-77', '91709', '', '', '76500000', '76501502', 'BBK NUERNBERG EH ANSBACH', '76551540', '109785', 'VER SPK GUNZENHAUSEN', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-gun.bayern.de', 'www.finanzamt-gunzenhausen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9221', 'Hersbruck ', 'Amberger Str. 76 (Haus B)', '91217', 'Hersbruck', '09151 731-0', '09151 731-200', '', '91211', '273', '76000000', '76001505', 'BBK NUERNBERG', '76050101', '190016618', 'SPARKASSE NUERNBERG', 'Servicezentrum: Mo - Mi: 08:00 - 15:30 Uhr, Do: 08:00 - 18:00 Uhr, Fr: 08:00', 'poststelle@fa-heb.bayern.de', 'www.finanzamt-hersbruck.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9222', 'Hilpoltstein ', 'Spitalwinkel 3', '91161', 'Hilpoltstein', '09174 469-0', '09174 469-100', '', '91155', '1180', '76000000', '76401520', 'BBK NUERNBERG', '76450000', '240000026', 'SPK MITTELFRANKEN-SUED', 'Servicezentrum: Mo - Fr: 08:00 - 12:30 Uhr, Do: 14:00 - 18:00 Uhr', 'poststelle@fa-hip.bayern.de', 'www.finanzamt-hilpoltstein.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9223', 'Hof mit Außenstellen ', 'Ernst-Reuter-Str. 60', '95030', 'Hof', '09281 929-0', '09281 929-1500', '', '95012', '1368', '78000000', '78001500', 'BBK BAYREUTH EH HOF', '78050000', '380020750', 'KR U ST SPK HOF', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-ho.bayern.de', 'www.finanzamt-hof.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9224', 'Hofheim - Außenstelle des Finanzamts Zeil -', 'Marktplatz 1', '97457', 'Hofheim', '09524 824-0', '09524 824-250', '', '', '', '79300000', '79301505', 'BBK WUERZBURG EH SCHWEINFUR', '79351730', '500900', 'SPK OSTUNTERFRANKEN', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-hoh.bayern.de', 'www.finanzamt-hofheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9225', 'Karlstadt - Außenstelle des Finanzamts Lohr -', 'Gemündener Str. 3', '97753', 'Karlstadt', '09353 949-0', '09353 949-2250', '', '', '', '79000000', '79001504', 'BBK WUERZBURG', '79050000', '2246', 'SPK MAINFRANKEN WUERZBURG', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-kar.bayern.de', 'www.finanzamt-karlstadt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9227', 'Kitzingen ', 'Moltkestr. 24', '97318', 'Kitzingen', '09321 703-0', '09321 703-444', '', '97308', '660', '79000000', '79101500', 'BBK WUERZBURG', '79050000', '42070557', 'SPK MAINFRANKEN WUERZBURG', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-kt.bayern.de', 'www.finanzamt-kitzingen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9228', 'Kronach ', 'Amtsgerichtsstr. 13', '96317', 'Kronach', '09261 510-0', '09261 510-199', '', '96302', '1262', '77300000', '77101501', 'BBK BAYREUTH', '77151640', '240006007', 'SPK KRONACH-LUDWIGSSTADT', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08.00 - 17:30 Uhr, Fr: 08:00', 'poststelle@fa-kc.bayern.de', 'www.finanzamt-kronach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9229', 'Kulmbach ', 'Georg-Hagen-Str. 17', '95326', 'Kulmbach', '09221 650-0', '09221 650-283', '', '95304', '1420', '77300000', '77101500', 'BBK BAYREUTH', '77150000', '105445', 'SPARKASSE KULMBACH', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08.00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-ku.bayern.de', 'www.finanzamt-kulmbach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9230', 'Lichtenfels ', 'Kronacher Str. 39', '96215', 'Lichtenfels', '09571 764-0', '09571 764-420', '', '96206', '1680', '77000000', '77001502', 'BBK NUERNBERG EH BAMBERG', '77051860', '2345', 'KR SPK LICHTENFELS', 'Servicezentrum: Mo - Fr: 08:00 - 13:00 Uhr, Do: 14:00 - 17:00 Uhr', 'poststelle@fa-lif.bayern.de', 'www.finanzamt-lichtenfels.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9231', 'Lohr a. Main mit Außenstellen  ', 'Rexrothstr. 14', '97816', 'Lohr', '09352 850-0', '09352 850-1300', '', '97804', '1465', '79000000', '79001504', 'BBK WUERZBURG', '79050000', '2246', 'SPK MAINFRANKEN WUERZBURG', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-loh.bayern.de', 'www.finanzamt-lohr.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9232', 'Marktheidenfeld - Außenstelle  des Finanzamts Lohr -', 'Ringstr. 24/26', '97828', 'Marktheidenfeld', '09391 506-0', '09391 506-3299', '', '', '', '79000000', '79001504', 'BBK WUERZBURG', '79050000', '2246', 'SPK MAINFRANKEN WUERZBURG', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-mar.bayern.de', 'www.finanzamt-marktheidenfeld.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9233', 'Münchberg - Außenstelle des Finanzamts Hof -', 'Hofer Str. 1', '95213', 'Münchberg', '09281 929-0', '09281 929-3505', '', '', '', '78000000', '78001500', 'BBK BAYREUTH EH HOF', '78050000', '380020750', 'KR U ST SPK HOF', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-mueb.bayern.de', 'www.finanzamt-muenchberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9234', 'Naila - Außenstelle des Finanzamts Hof -', 'Carl-Seyffert-Str. 3', '95119', 'Naila', '09281 929-0', '09281 929-2506', '', '', '', '78000000', '78001500', 'BBK BAYREUTH EH HOF', '78050000', '380020750', 'KR U ST SPK HOF', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-nai.bayern.de', 'www.finanzamt-naila.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9235', 'Neumarkt i.d.Opf. ', 'Ingolstädter Str. 3', '92318', 'Neumarkt', '09181 692-0', '09181 692-1200', '', '', '', '76000000', '76001506', 'BBK NUERNBERG', '76052080', '6296', 'SPK NEUMARKT I D OPF-PARSBG', 'Servicezentrum: Mo - Do: 07:30 - 15:00 Uhr, Fr: 07:30 - 12:00 Uhr', 'poststelle@fa-nm.bayern.de', '/www.finanzamt-neumarkt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9236', 'Neunburg v. W. - Außenstelle des Finanzamts Schwandorf -', 'Krankenhausstr. 6', '92431', 'Neunburg vorm Wald', '09431 382-0', '09431 382-539', '', '92428', '1000', '75300000', '75301502', 'BBK REGENSBURG EH WEIDEN', '75051040', '380019000', 'SPK IM LANDKREIS SCHWANDORF', 'Servicezentrum: Mo-Mi: 07:30-12:30 u. 13:30-15:30,Do: 07:30-12:30 u. 13:30-17:00, Fr: 07:30-12:30 h ', 'poststelle@fa-nen.bayern.de', 'www.finanzamt-neunburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9238', 'Nürnberg-Nord ', 'Kirchenweg 10', '90419', 'Nürnberg', '0911 3998-0', '0911 3998-296', '90340', '', '', '76000000', '76001502', 'BBK NUERNBERG', '76050000', '20161', 'BAYERNLB NUERNBERG', 'Servicezentrum: Mo - Mi: 08:00 - 14:00 Uhr, Do: 08:00 - 18:00 Uhr, Fr: 08:00', 'poststelle@fa-n-n.bayern.de', 'www.finanzamt-nuernberg-nord.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9240', 'Nürnberg-Süd ', 'Sandstr. 20', '90443', 'Nürnberg', '0911 248-0', '0911 248-2299/2599', '90339', '', '', '76000000', '76001503', 'BBK NUERNBERG', '76050101', '3648043', 'SPARKASSE NUERNBERG', 'Servicezentrum: Mo - Mi: 08:00 - 14:00 Uhr, Do: 08:00 - 18:00 Uhr, Fr: 08:00', 'poststelle@fa-n-s.bayern.de', 'www.finanzamt-nuernberg-sued.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9241', 'Nürnberg-Zentral ', 'Voigtländerstr. 7/9', '90489', 'Nürnberg', '0911 5393-0', '0911 5393-2000', '', '', '', '76000000', '76001501', 'BBK NUERNBERG', '76050101', '1025008', 'SPARKASSE NUERNBERG', 'Servicezentrum: Mo - Do: 08:00 - 12:30 h, Di und Do: 13:30 - 15:00 h,', 'poststelle@fa-n-zfa.bayern.de', 'www.zentralfinanzamt-nuernberg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9242', 'Ochsenfurt - Außenstelle des Finanzamts Würzburg -', 'Völkstr.1', '97199', 'Ochsenfurt', '09331 904-0', '09331 904-200', '', '97196', '1263', '79000000', '79001500', 'BBK WUERZBURG', '79020076', '801283', 'HYPOVEREINSBK WUERZBURG', 'Servicezentrum: Mo - Mi: 07:30 - 13:00 Uhr, Do: 07:30 - 17:00 uhr, Fr: 07:30', 'poststelle@fa-och.bayern.de', 'www.finanzamt-ochsenfurt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9244', 'Regensburg ', 'Landshuter Str. 4', '93047', 'Regensburg', '0941 5024-0', '0941 5024-1199', '93042', '', '', '75000000', '75001500', 'BBK REGENSBURG', '75050000', '111500', 'SPK REGENSBURG', 'Servicezentrum: Mo - Mi: 07:30 - 15:00 Uhr, Do: 07:30 - 17:00 Uhr, Fr: 07:30', 'poststelle@fa-r.bayern.de', 'www.finanzamt-regensburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9246', 'Rothenburg - Außenstelle des Finanzamts Ansbach -', 'Ludwig-Siebert-Str. 31', '91541', 'Rothenburg o.d.T.', '0981 16-0', '09861 706-511', '', '', '', '76500000', '76501500', 'BBK NUERNBERG EH ANSBACH', '76550000', '215004', 'VER SPK ANSBACH', 'Servicezentrum: Mo - Mi: 08:00 - 14:00 Uhr, Do: 08:00 - 18:00 Uhr, Fr: 08:00', 'poststelle@fa-rot.bayern.de', 'www.finanzamt-rothenburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9247', 'Schwabach ', 'Theodor-Heuss-Str. 63', '91126', 'Schwabach', '09122 928-0', '09122 928-100', '91124', '', '', '76000000', '76401500', 'BBK NUERNBERG', '76450000', '55533', 'SPK MITTELFRANKEN-SUED', 'Servicezentrum: Mo - Mi: 08:00 - 13:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-sc.bayern.de', 'www.finanzamt-schwabach.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9248', 'Schwandorf mit Außenstelle Neunburg v. W.', 'Friedrich-Ebert-Str.59', '92421', 'Schwandorf', '09431 382-0', '09431 382-111', '92419', '', '', '75300000', '75301502', 'BBK REGENSBURG EH WEIDEN', '75051040', '380019000', 'SPK IM LANDKREIS SCHWANDORF', 'Servicezentrum: Mo-Mi: 07:30-12:30 u. 13:30-15:30,Do: 07:30-12:30 u. 13:30-17:00, Fr: 07:30-12:30 h ', 'poststelle@fa-sad.bayern.de', 'www.finanzamt-schwandorf.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9249', 'Schweinfurt ', 'Schrammstr. 3', '97421', 'Schweinfurt', '09721 2911-0', '09721 2911-5070', '97420', '', '', '79300000', '79301500', 'BBK WUERZBURG EH SCHWEINFUR', '79350101', '15800', 'KR SPK SCHWEINFURT', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-sw.bayern.de', 'www.finanzamt-schweinfurt.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9250', 'Selb - Außenstelle des Finanzamts Wunsiedel -', 'Wittelsbacher Str. 8', '95100', 'Selb', '09232 607-0', '09232 607-300', '', '', '', '78000000', '78101512', 'BBK BAYREUTH EH HOF', '78055050', '620006254', 'SPK FICHTELGEBIRGE', 'Servicezentrum: Mo-Mi: 07:30-12:30 u. 13:30-15:00,Do: 07:30-12:30 und 13:30-17:00, Fr: 07:30-12:00 h', 'poststelle@fa-sel.bayern.de', 'www.finanzamt-selb.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9252', 'Uffenheim ', 'Schloßpl.', '97215', 'Uffenheim', '09842 200-0', '09842 200-345', '', '97211', '1240', '76500000', '76501504', 'BBK NUERNBERG EH ANSBACH', '76251020', '620002006', 'SPK I LANDKREIS NEUSTADT', 'Servicezentrum: Mo-Mi: 08:00-12:00 u. 13:00-15:00,Do: 08:00-12:00 u. 13:00-17:00, Fr: 08:00-12:00 h ', 'poststelle@fa-uff.bayern.de', 'www.finanzamt-uffenheim.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9253', 'Waldmünchen - Außenstelle des  Finanzamts Cham -', 'Bahnhofstr. 10', '93449', 'Waldmünchen', '09971 488-0', '09971 488-550', '', '', '', '74221170', '344 755 205', 'HYPOVEREINSBK CHAM, OBERPF', '76010085', '1735-858', 'POSTBANK NUERNBERG', 'Servicezentrum: Mo - Mi: 07:30 - 15:00 Uhr, Do: 07:30 - 17:00 Uhr, Fr: 07:30', 'poststelle@fa-wuem.bayern.de', 'www.finanzamt-waldmuenchen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9254', 'Waldsassen ', 'Johannisplatz 13', '95652', 'Waldsassen', '09632 847-0', '09632 847-199', '', '95646', '1329', '75300000', '75301511', 'BBK REGENSBURG EH WEIDEN', '78151080', '32367', 'SPK TIRSCHENREUTH', 'Servicezentrum: Mo - Fr: 07:30 - 12:30 Uhr, Mo - Mi: 13:30 - 15:30 Uhr,', 'poststelle@fa-wasa.bayern.de', 'www.finanzamt-waldsassen.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9255', 'Weiden i.d.Opf. ', 'Schlörpl. 2 u. 4', '92637', 'Weiden', '0961 301-0', '0961 32600', '', '92604', '1460', '75300000', '75301500', 'BBK REGENSBURG EH WEIDEN', '75350000', '172700', 'ST SPK WEIDEN', 'Servicezentrum: Mo - Fr: 07:30 - 12:30 Uhr, Mo - Mi: 13:30 - 15:30 Uhr,', 'poststelle@fa-wen.bayern.de', 'www.finanzamt-weiden.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9257', 'Würzburg mit Außenstelle Ochsenfurt', 'Ludwigstr. 25', '97070', 'Würzburg', '0931 387-0', '0931 387-4444', '97064', '', '', '79000000', '79001500', 'BBK WUERZBURG', '79020076', '801283', 'HYPOVEREINSBK WUERZBURG', 'Servicezentrum: Mo - Mi: 07:30 - 15:00 Uhr, Do: 07:30 - 17:00 Uhr, Fr: 07:30', 'poststelle@fa-wue.bayern.de', 'www.finanzamt-wuerzburg.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9258', 'Wunsiedel mit Außenstelle Selb', 'Sonnenstr. 11', '95632', 'Wunsiedel', '09232 607-0', '09232 607-200', '95631', '', '', '78000000', '78101512', 'BBK BAYREUTH EH HOF', '78055050', '620006254', 'SPK FICHTELGEBIRGE', 'Servicezentrum: Mo-Mi: 07:30-12:30 u 13:30-15:00, Do: 07:30-12:30 und 13:30-17:00, Fr: 07:30-12:00 h', 'poststelle@fa-wun.bayern.de', 'www.finanzamt-wunsiedel.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9259', 'Zeil a. Main mit Außenstellen  ', 'Obere Torstr. 9', '97475', 'Zeil', '09524 824-0', '09524 824-100', '', '97470', '1160', '79300000', '79301505', 'BBK WUERZBURG EH SCHWEINFUR', '79351730', '500900', 'SPK OSTUNTERFRANKEN', 'Servicezentrum: Mo - Mi: 08:00 - 15:00 Uhr, Do: 08:00 - 17:00 Uhr, Fr: 08:00', 'poststelle@fa-zei.bayern.de', 'www.finanzamt-zeil.de');
INSERT INTO finanzamt (fa_land_nr, fa_bufa_nr, fa_name, fa_strasse, fa_plz, fa_ort, fa_telefon, fa_fax, fa_plz_grosskunden, fa_plz_postfach, fa_postfach, fa_blz_1, fa_kontonummer_1, fa_bankbezeichnung_1, fa_blz_2, fa_kontonummer_2, fa_bankbezeichnung_2, fa_oeffnungszeiten, fa_email, fa_internet) VALUES ('9', '9260', 'Kötzting - Außenstelle des Finanzamts Cham -', 'Bahnhofstr. 3', '93444', 'Kötzting', '09971 488-0', '09971 488-450', '', '', '', '74221170', '344 755 205', 'HYPOVEREINSBK CHAM, OBERPF', '76010085', '1735-858', 'POSTBANK NUERNBERG', 'Servicezentrum: Mo - Mi: 07:30 - 15:00 Uhr, Do: 07:30 - 18:00 Uhr, Fr: 07:30', 'poststelle@fa-koez.bayern.de', 'www.finanzamt-koetzting.de');


--
-- Name: units; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO units (name, base_unit, factor, "type") VALUES ('Stck', NULL, NULL, 'dimension');
INSERT INTO units (name, base_unit, factor, "type") VALUES ('psch', NULL, 0.00000, 'service');
INSERT INTO units (name, base_unit, factor, "type") VALUES ('Tag', 'Std', 8.00000, 'service');
INSERT INTO units (name, base_unit, factor, "type") VALUES ('Std', 'min', 60.00000, 'service');
INSERT INTO units (name, base_unit, factor, "type") VALUES ('min', NULL, 0.00000, 'service');
INSERT INTO units (name, base_unit, factor, "type") VALUES ('t', 'kg', 1000.00000, 'dimension');
INSERT INTO units (name, base_unit, factor, "type") VALUES ('kg', 'g', 1000.00000, 'dimension');
INSERT INTO units (name, base_unit, factor, "type") VALUES ('g', 'mg', 1000.00000, 'dimension');
INSERT INTO units (name, base_unit, factor, "type") VALUES ('mg', NULL, NULL, 'dimension');
INSERT INTO units (name, base_unit, factor, "type") VALUES ('L', 'ml', 1000.00000, 'dimension');
INSERT INTO units (name, base_unit, factor, "type") VALUES ('ml', NULL, NULL, 'dimension');


--
-- Name: tax_zones; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO tax_zones (id, description) VALUES (0, 'Inland');
INSERT INTO tax_zones (id, description) VALUES (1, 'EU mit USt-ID Nummer');
INSERT INTO tax_zones (id, description) VALUES (2, 'EU ohne USt-ID Nummer');
INSERT INTO tax_zones (id, description) VALUES (3, 'Außerhalb EU');

--
-- Name: license_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX license_id_key ON license USING btree (id);


--
-- Name: acc_trans_trans_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX acc_trans_trans_id_key ON acc_trans USING btree (trans_id);


--
-- Name: acc_trans_chart_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX acc_trans_chart_id_key ON acc_trans USING btree (chart_id);


--
-- Name: acc_trans_transdate_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX acc_trans_transdate_key ON acc_trans USING btree (transdate);


--
-- Name: acc_trans_source_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX acc_trans_source_key ON acc_trans USING btree (lower(source));


--
-- Name: ap_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ap_id_key ON ap USING btree (id);


--
-- Name: ap_transdate_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ap_transdate_key ON ap USING btree (transdate);


--
-- Name: ap_invnumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ap_invnumber_key ON ap USING btree (lower(invnumber));


--
-- Name: ap_ordnumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ap_ordnumber_key ON ap USING btree (lower(ordnumber));


--
-- Name: ap_vendor_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ap_vendor_id_key ON ap USING btree (vendor_id);


--
-- Name: ap_employee_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ap_employee_id_key ON ap USING btree (employee_id);


--
-- Name: ar_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ar_id_key ON ar USING btree (id);


--
-- Name: ar_transdate_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ar_transdate_key ON ar USING btree (transdate);


--
-- Name: ar_invnumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ar_invnumber_key ON ar USING btree (lower(invnumber));


--
-- Name: ar_ordnumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ar_ordnumber_key ON ar USING btree (lower(ordnumber));


--
-- Name: ar_customer_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ar_customer_id_key ON ar USING btree (customer_id);


--
-- Name: ar_employee_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ar_employee_id_key ON ar USING btree (employee_id);


--
-- Name: assembly_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX assembly_id_key ON assembly USING btree (id);


--
-- Name: chart_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX chart_id_key ON chart USING btree (id);


--
-- Name: chart_accno_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX chart_accno_key ON chart USING btree (accno);


--
-- Name: chart_category_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX chart_category_key ON chart USING btree (category);


--
-- Name: chart_link_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX chart_link_key ON chart USING btree (link);


--
-- Name: chart_gifi_accno_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX chart_gifi_accno_key ON chart USING btree (gifi_accno);


--
-- Name: customer_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX customer_id_key ON customer USING btree (id);


--
-- Name: customer_customer_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX customer_customer_id_key ON customertax USING btree (customer_id);


--
-- Name: customer_customernumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX customer_customernumber_key ON customer USING btree (customernumber);


--
-- Name: customer_name_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX customer_name_key ON customer USING btree (name);


--
-- Name: customer_contact_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX customer_contact_key ON customer USING btree (contact);


--
-- Name: employee_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX employee_id_key ON employee USING btree (id);


--
-- Name: employee_login_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX employee_login_key ON employee USING btree (login);


--
-- Name: employee_name_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX employee_name_key ON employee USING btree (name);


--
-- Name: exchangerate_ct_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX exchangerate_ct_key ON exchangerate USING btree (curr, transdate);


--
-- Name: gifi_accno_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX gifi_accno_key ON gifi USING btree (accno);


--
-- Name: gl_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX gl_id_key ON gl USING btree (id);


--
-- Name: gl_transdate_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX gl_transdate_key ON gl USING btree (transdate);


--
-- Name: gl_reference_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX gl_reference_key ON gl USING btree (lower(reference));


--
-- Name: gl_description_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX gl_description_key ON gl USING btree (lower(description));


--
-- Name: gl_employee_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX gl_employee_id_key ON gl USING btree (employee_id);


--
-- Name: invoice_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX invoice_id_key ON invoice USING btree (id);


--
-- Name: invoice_trans_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX invoice_trans_id_key ON invoice USING btree (trans_id);


--
-- Name: oe_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX oe_id_key ON oe USING btree (id);


--
-- Name: oe_transdate_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX oe_transdate_key ON oe USING btree (transdate);


--
-- Name: oe_ordnumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX oe_ordnumber_key ON oe USING btree (lower(ordnumber));


--
-- Name: oe_employee_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX oe_employee_id_key ON oe USING btree (employee_id);


--
-- Name: orderitems_trans_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orderitems_trans_id_key ON orderitems USING btree (trans_id);


--
-- Name: parts_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX parts_id_key ON parts USING btree (id);


--
-- Name: parts_partnumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX parts_partnumber_key ON parts USING btree (lower(partnumber));


--
-- Name: parts_description_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX parts_description_key ON parts USING btree (lower(description));


--
-- Name: partstax_parts_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX partstax_parts_id_key ON partstax USING btree (parts_id);


--
-- Name: vendor_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vendor_id_key ON vendor USING btree (id);


--
-- Name: vendor_name_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vendor_name_key ON vendor USING btree (name);


--
-- Name: vendor_vendornumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vendor_vendornumber_key ON vendor USING btree (vendornumber);


--
-- Name: vendor_contact_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vendor_contact_key ON vendor USING btree (contact);


--
-- Name: vendortax_vendor_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vendortax_vendor_id_key ON vendortax USING btree (vendor_id);


--
-- Name: shipto_trans_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX shipto_trans_id_key ON shipto USING btree (trans_id);


--
-- Name: project_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX project_id_key ON project USING btree (id);


--
-- Name: ar_quonumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ar_quonumber_key ON ar USING btree (lower(quonumber));


--
-- Name: ap_quonumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ap_quonumber_key ON ap USING btree (lower(quonumber));


--
-- Name: makemodel_parts_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX makemodel_parts_id_key ON makemodel USING btree (parts_id);


--
-- Name: makemodel_make_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX makemodel_make_key ON makemodel USING btree (lower(make));


--
-- Name: makemodel_model_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX makemodel_model_key ON makemodel USING btree (lower(model));


--
-- Name: status_trans_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX status_trans_id_key ON status USING btree (trans_id);


--
-- Name: department_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX department_id_key ON department USING btree (id);


--
-- Name: orderitems_id_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX orderitems_id_key ON orderitems USING btree (id);


--
-- Name: gl_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gl
    ADD CONSTRAINT gl_pkey PRIMARY KEY (id);


--
-- Name: chart_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY chart
    ADD CONSTRAINT chart_pkey PRIMARY KEY (id);


--
-- Name: parts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY parts
    ADD CONSTRAINT parts_pkey PRIMARY KEY (id);


--
-- Name: invoice_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY invoice
    ADD CONSTRAINT invoice_pkey PRIMARY KEY (id);


--
-- Name: vendor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vendor
    ADD CONSTRAINT vendor_pkey PRIMARY KEY (id);


--
-- Name: customer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (id);


--
-- Name: contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (cp_id);


--
-- Name: ar_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ar
    ADD CONSTRAINT ar_pkey PRIMARY KEY (id);


--
-- Name: ap_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ap
    ADD CONSTRAINT ap_pkey PRIMARY KEY (id);


--
-- Name: oe_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY oe
    ADD CONSTRAINT oe_pkey PRIMARY KEY (id);


--
-- Name: employee_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY employee
    ADD CONSTRAINT employee_pkey PRIMARY KEY (id);


--
-- Name: project_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY project
    ADD CONSTRAINT project_pkey PRIMARY KEY (id);


--
-- Name: project_projectnumber_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY project
    ADD CONSTRAINT project_projectnumber_key UNIQUE (projectnumber);


--
-- Name: warehouse_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY warehouse
    ADD CONSTRAINT warehouse_pkey PRIMARY KEY (id);


--
-- Name: business_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY business
    ADD CONSTRAINT business_pkey PRIMARY KEY (id);


--
-- Name: license_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY license
    ADD CONSTRAINT license_pkey PRIMARY KEY (id);


--
-- Name: pricegroup_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pricegroup
    ADD CONSTRAINT pricegroup_pkey PRIMARY KEY (id);


--
-- Name: language_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "language"
    ADD CONSTRAINT language_pkey PRIMARY KEY (id);


--
-- Name: payment_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_terms
    ADD CONSTRAINT payment_terms_pkey PRIMARY KEY (id);


--
-- Name: units_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY units
    ADD CONSTRAINT units_pkey PRIMARY KEY (name);


--
-- Name: rma_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rma
    ADD CONSTRAINT rma_pkey PRIMARY KEY (id);


--
-- Name: printers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY printers
    ADD CONSTRAINT printers_pkey PRIMARY KEY (id);


--
-- Name: buchungsgruppen_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY buchungsgruppen
    ADD CONSTRAINT buchungsgruppen_pkey PRIMARY KEY (id);


--
-- Name: dunning_config_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dunning_config
    ADD CONSTRAINT dunning_config_pkey PRIMARY KEY (id);


--
-- Name: dunning_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dunning
    ADD CONSTRAINT dunning_pkey PRIMARY KEY (id);


--
-- Name: taxkeys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY taxkeys
    ADD CONSTRAINT taxkeys_pkey PRIMARY KEY (id);


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY acc_trans
    ADD CONSTRAINT "$1" FOREIGN KEY (chart_id) REFERENCES chart(id);


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY invoice
    ADD CONSTRAINT "$1" FOREIGN KEY (parts_id) REFERENCES parts(id);


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ar
    ADD CONSTRAINT "$1" FOREIGN KEY (customer_id) REFERENCES customer(id);


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ap
    ADD CONSTRAINT "$1" FOREIGN KEY (vendor_id) REFERENCES vendor(id);


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orderitems
    ADD CONSTRAINT "$1" FOREIGN KEY (parts_id) REFERENCES parts(id);


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY prices
    ADD CONSTRAINT "$1" FOREIGN KEY (parts_id) REFERENCES parts(id);


--
-- Name: $2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY prices
    ADD CONSTRAINT "$2" FOREIGN KEY (pricegroup_id) REFERENCES pricegroup(id);


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY units
    ADD CONSTRAINT "$1" FOREIGN KEY (base_unit) REFERENCES units(name);


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rmaitems
    ADD CONSTRAINT "$1" FOREIGN KEY (parts_id) REFERENCES parts(id);


--
-- Name: $1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY parts
    ADD CONSTRAINT "$1" FOREIGN KEY (buchungsgruppen_id) REFERENCES buchungsgruppen(id);


--
-- Name: check_department; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_department
    AFTER INSERT OR UPDATE ON ar
    FOR EACH ROW
    EXECUTE PROCEDURE check_department();


--
-- Name: check_department; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_department
    AFTER INSERT OR UPDATE ON ap
    FOR EACH ROW
    EXECUTE PROCEDURE check_department();


--
-- Name: check_department; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_department
    AFTER INSERT OR UPDATE ON gl
    FOR EACH ROW
    EXECUTE PROCEDURE check_department();


--
-- Name: check_department; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_department
    AFTER INSERT OR UPDATE ON oe
    FOR EACH ROW
    EXECUTE PROCEDURE check_department();


--
-- Name: del_department; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER del_department
    AFTER DELETE ON ar
    FOR EACH ROW
    EXECUTE PROCEDURE del_department();


--
-- Name: del_department; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER del_department
    AFTER DELETE ON ap
    FOR EACH ROW
    EXECUTE PROCEDURE del_department();


--
-- Name: del_department; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER del_department
    AFTER DELETE ON gl
    FOR EACH ROW
    EXECUTE PROCEDURE del_department();


--
-- Name: del_department; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER del_department
    AFTER DELETE ON oe
    FOR EACH ROW
    EXECUTE PROCEDURE del_department();


--
-- Name: del_customer; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER del_customer
    AFTER DELETE ON customer
    FOR EACH ROW
    EXECUTE PROCEDURE del_customer();


--
-- Name: del_vendor; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER del_vendor
    AFTER DELETE ON vendor
    FOR EACH ROW
    EXECUTE PROCEDURE del_vendor();


--
-- Name: del_exchangerate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER del_exchangerate
    BEFORE DELETE ON ar
    FOR EACH ROW
    EXECUTE PROCEDURE del_exchangerate();


--
-- Name: del_exchangerate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER del_exchangerate
    BEFORE DELETE ON ap
    FOR EACH ROW
    EXECUTE PROCEDURE del_exchangerate();


--
-- Name: del_exchangerate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER del_exchangerate
    BEFORE DELETE ON oe
    FOR EACH ROW
    EXECUTE PROCEDURE del_exchangerate();


--
-- Name: check_inventory; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_inventory
    AFTER UPDATE ON oe
    FOR EACH ROW
    EXECUTE PROCEDURE check_inventory();


--
-- Name: customer_datevexport; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER customer_datevexport
    BEFORE UPDATE ON customer
    FOR EACH ROW
    EXECUTE PROCEDURE set_datevexport();


--
-- Name: vendor_datevexport; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER vendor_datevexport
    BEFORE UPDATE ON vendor
    FOR EACH ROW
    EXECUTE PROCEDURE set_datevexport();


--
-- Name: mtime_customer; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_customer
    BEFORE UPDATE ON customer
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_vendor; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_vendor
    BEFORE UPDATE ON vendor
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_ar; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_ar
    BEFORE UPDATE ON ar
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_ap; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_ap
    BEFORE UPDATE ON ap
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_gl; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_gl
    BEFORE UPDATE ON gl
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_acc_trans; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_acc_trans
    BEFORE UPDATE ON acc_trans
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_oe; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_oe
    BEFORE UPDATE ON oe
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_invoice; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_invoice
    BEFORE UPDATE ON invoice
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_orderitems; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_orderitems
    BEFORE UPDATE ON orderitems
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_chart; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_chart
    BEFORE UPDATE ON chart
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_tax; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_tax
    BEFORE UPDATE ON tax
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_parts; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_parts
    BEFORE UPDATE ON parts
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_status; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_status
    BEFORE UPDATE ON status
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_partsgroup; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_partsgroup
    BEFORE UPDATE ON partsgroup
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_inventory; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_inventory
    BEFORE UPDATE ON inventory
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_department; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_department
    BEFORE UPDATE ON department
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: mtime_contacts; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER mtime_contacts
    BEFORE UPDATE ON contacts
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


--
-- Name: priceupdate_parts; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER priceupdate_parts
    AFTER UPDATE ON parts
    FOR EACH ROW
    EXECUTE PROCEDURE set_priceupdate_parts();
