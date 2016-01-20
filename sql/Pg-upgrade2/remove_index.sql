-- @tag: remove_index
-- @description: Nicht mehr benötigte Indizes löschen (es gibt nun einen Primary Key)
-- @depends: release_3_3_0

DROP    INDEX orderitems_id_key;
REINDEX INDEX orderitems_pkey;

DROP    INDEX chart_id_key;
REINDEX INDEX chart_pkey;

-- Bei LINET nicht existent:
-- DROP    INDEX customer_id_key;
REINDEX INDEX customer_pkey;

-- Bei LINET nicht existent:
-- DROP    INDEX employee_id_key;
REINDEX INDEX employee_pkey;

-- Bei LINET nicht existent:
-- DROP    INDEX vendor_id_key;
REINDEX INDEX vendor_pkey;

-- Bei LINET nicht existent:
-- DROP    INDEX ar_id_key;
REINDEX INDEX ar_pkey;

DROP    INDEX units_name_idx;
REINDEX INDEX units_pkey;

-- Bei LINET nicht existent:
-- DROP    INDEX ap_id_key;
REINDEX INDEX ap_pkey;

-- Bei LINET nicht existent:
-- DROP    INDEX invoice_id_key;
REINDEX INDEX invoice_pkey;

-- Bei LINET nicht existent:
-- DROP    INDEX oe_id_key;
REINDEX INDEX oe_pkey;

DROP    INDEX parts_id_key;
REINDEX INDEX parts_pkey;

DROP    INDEX project_id_key;
REINDEX INDEX project_pkey;

-- Bei LINET nicht existent:
-- DROP    INDEX gl_id_key;
REINDEX INDEX gl_pkey;

DROP    INDEX department_id_key;
REINDEX INDEX department_pkey;
