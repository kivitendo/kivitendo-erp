-- @tag: remove_index
-- @description: Nicht mehr benötigte Indizes löschen (es gibt nun einen Primary Key)
-- @depends: release_3_3_0

DROP    INDEX orderitems_id_key;
REINDEX INDEX orderitems_pkey;

DROP    INDEX chart_id_key;
REINDEX INDEX chart_pkey;

DROP    INDEX customer_id_key;
REINDEX INDEX customer_pkey;

DROP    INDEX employee_id_key;
REINDEX INDEX employee_pkey;

DROP    INDEX vendor_id_key;
REINDEX INDEX vendor_pkey;

DROP    INDEX ar_id_key;
REINDEX INDEX ar_pkey;

DROP    INDEX units_name_idx;
REINDEX INDEX units_pkey;

DROP    INDEX ap_id_key;
REINDEX INDEX ap_pkey;

DROP    INDEX invoice_id_key;
REINDEX INDEX invoice_pkey;

DROP    INDEX oe_id_key;
REINDEX INDEX oe_pkey;

DROP    INDEX parts_id_key;
REINDEX INDEX parts_pkey;

DROP    INDEX project_id_key;
REINDEX INDEX project_pkey;

DROP    INDEX gl_id_key;
REINDEX INDEX gl_pkey;

DROP    INDEX department_id_key;
REINDEX INDEX department_pkey;
