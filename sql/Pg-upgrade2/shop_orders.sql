-- @tag: shop_orders
-- @description: Erstellen der Tabellen shop_orders und shop_order_items
-- @depends: release_3_5_0 shops

CREATE TABLE shop_orders (
  id SERIAL PRIMARY KEY,
  shop_trans_id integer NOT NULL, --id vom shop
  shop_ordernumber TEXT, --Bestellnummer vom Shop
  shop_data text,        -- store whole order as json
  shop_customer_comment text, --Bestellkommentar des Kunden
  amount numeric(15,5),  --Bruttogesamtbetrag
  netamount numeric(15,5),--Nettogesamtbetrag
  order_date timestamp, --Bestelldatum und Zeit
  shipping_costs numeric(15,5),
  shipping_costs_net numeric(15,5),
  shipping_costs_id integer,
  tax_included boolean,
  payment_id integer, --Bezahlart
  payment_description TEXT,  --Bezahlart
  shop_id integer,               --welcher shop bei mehreren
  host TEXT,             --Hostname vom Shop
  remote_ip text,        --IP Besteller
  transferred boolean DEFAULT FALSE,    -- übernommen
  transfer_date date, -- Zeit wann übernommen
  kivi_customer_id integer,  -- Kundenid von Tbl customer wenn übernommen
  oe_transid integer,  -- id to
-- Bestell-, Rechnungs- und Lieferadresse. !!Manche Shops bieten sowas!!
-- In der Regel ist aber die Rechnungsadresse die Kundenadresse
  -- Bestelldaten des Kunden
  shop_customer_id integer,
  shop_customer_number TEXT,
  customer_lastname TEXT,
  customer_firstname TEXT,
  customer_company TEXT,
  customer_street TEXT,
  customer_zipcode TEXT,
  customer_city TEXT,
  customer_country TEXT,
  customer_greeting TEXT,
  customer_department TEXT,
  customer_vat TEXT,
  customer_phone TEXT,
  customer_fax TEXT,
  customer_email TEXT,
  customer_newsletter boolean,
  -- Rechnungsadresse
  shop_c_billing_id integer,
  shop_c_billing_number TEXT,
  billing_lastname TEXT,
  billing_firstname TEXT,
  billing_company TEXT,
  billing_street TEXT,
  billing_zipcode TEXT,
  billing_city TEXT,
  billing_country TEXT,
  billing_greeting TEXT,
  billing_department TEXT,
  billing_vat TEXT,
  billing_phone TEXT,
  billing_fax TEXT,
  billing_email TEXT,

  -- SEPA
  sepa_account_holder TEXT,
  sepa_iban TEXT,
  sepa_bic TEXT,

  -- Lieferadresse
  shop_c_delivery_id integer,
  shop_c_delivery_number TEXT,
  delivery_lastname TEXT,
  delivery_firstname TEXT,
  delivery_company TEXT,
  delivery_street TEXT,
  delivery_zipcode TEXT,
  delivery_city TEXT,
  delivery_country TEXT,
  delivery_greeting TEXT,
  delivery_department TEXT,
  delivery_vat TEXT,
  delivery_phone TEXT,
  delivery_fax TEXT,
  delivery_email TEXT,

  obsolete boolean DEFAULT FALSE NOT NULL,
  positions integer,

  itime timestamp DEFAULT now(),
  mtime timestamp
);

CREATE TABLE shop_order_items (
  id            SERIAL PRIMARY KEY,
  shop_trans_id INTEGER NOT NULL, --id vom shop in shop-db? -> could use $order_item->shop_order->shop_trans_id instead
  shop_order_id INTEGER REFERENCES shop_orders (id) ON DELETE CASCADE,
  description   TEXT,  -- Artikelbezeichnung
  partnumber    TEXT,
  shop_id       INTEGER,
  position      INTEGER,
  tax_rate      NUMERIC(15,2),
  quantity      NUMERIC(25,5),   -- qty in invoice and orderitems is real, doi is numeric(25,5)
  price         NUMERIC(15,5)
);
