-- @tag: delivery_orders
-- @description: Lieferscheine als eigener Beleg
-- @depends: release_2_4_3 price_factors
CREATE TABLE delivery_orders (
  id                      integer NOT NULL DEFAULT nextval('id'),
  donumber                text    NOT NULL,
  ordnumber               text,
  transdate               date             DEFAULT now(),
  vendor_id               integer,
  customer_id             integer,
  reqdate                 date,
  shippingpoint           text,
  notes                   text,
  intnotes                text,
  employee_id             integer,
  closed                  boolean          DEFAULT false,
  delivered               boolean          DEFAULT false,
  cusordnumber            text,
  oreqnumber              text,
  department_id           integer,
  shipvia                 text,
  cp_id                   integer,
  language_id             integer,
  shipto_id               integer,
  globalproject_id        integer,
  salesman_id             integer,
  transaction_description text,
  is_sales                boolean,

  itime                   timestamp        DEFAULT now(),
  mtime                   timestamp,

  PRIMARY KEY (id),
  FOREIGN KEY (vendor_id)        REFERENCES vendor   (id),
  FOREIGN KEY (customer_id)      REFERENCES customer (id),
  FOREIGN KEY (employee_id)      REFERENCES employee (id),
  FOREIGN KEY (cp_id)            REFERENCES contacts (cp_id),
  FOREIGN KEY (language_id)      REFERENCES language (id),
  FOREIGN KEY (globalproject_id) REFERENCES project  (id),
  FOREIGN KEY (salesman_id)      REFERENCES employee (id)
);

CREATE TRIGGER mtime_delivery_orders BEFORE UPDATE ON delivery_orders
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();

CREATE SEQUENCE delivery_order_items_id;

CREATE TABLE delivery_order_items (
  id                 integer       NOT NULL DEFAULT nextval('delivery_order_items_id'),
  delivery_order_id  integer       NOT NULL,
  parts_id           integer       NOT NULL,
  description        text,
  qty                numeric(25,5),
  sellprice          numeric(15,5),
  discount           real,
  project_id         integer,
  reqdate            date,
  serialnumber       text,
  ordnumber          text,
  transdate          text,
  cusordnumber       text,
  unit               varchar(20),
  base_qty           real,
  longdescription    text,
  lastcost           numeric(15,5),
  price_factor_id    integer,
  price_factor       numeric(15,5)          DEFAULT 1,
  marge_price_factor numeric(15,5)          DEFAULT 1,

  itime timestamp                           DEFAULT now(),
  mtime timestamp,

  PRIMARY KEY (id),
  FOREIGN KEY (delivery_order_id) REFERENCES delivery_orders (id),
  FOREIGN KEY (parts_id)          REFERENCES parts (id),
  FOREIGN KEY (project_id)        REFERENCES project (id),
  FOREIGN KEY (price_factor_id)   REFERENCES price_factors (id)
);

CREATE TRIGGER mtime_delivery_order_items_id BEFORE UPDATE ON delivery_order_items
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();

ALTER TABLE defaults ADD COLUMN pdonumber text;
ALTER TABLE defaults ADD COLUMN sdonumber text;
UPDATE defaults SET pdonumber = '0', sdonumber = '0';

CREATE TABLE delivery_order_items_stock (
  id                     integer       NOT NULL DEFAULT nextval('id'),
  delivery_order_item_id integer       NOT NULL,

  qty                    numeric(15,5) NOT NULL,
  unit                   varchar(20)   NOT NULL,
  warehouse_id           integer       NOT NULL,
  bin_id                 integer       NOT NULL,
  chargenumber           text,

  itime                  timestamp              DEFAULT now(),
  mtime                  timestamp,

  PRIMARY KEY (id),
  FOREIGN KEY (delivery_order_item_id) REFERENCES delivery_order_items (id),
  FOREIGN KEY (warehouse_id)           REFERENCES warehouse (id),
  FOREIGN KEY (bin_id)                 REFERENCES bin (id)
);

CREATE TRIGGER mtime_delivery_order_items_stock BEFORE UPDATE ON delivery_order_items_stock
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();
