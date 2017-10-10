-- @tag: trigram_indices
-- @description: Trigram Indizes für häufig durchsuchte Spalten
-- @depends: release_3_5_0 trigram_extension

CREATE INDEX customer_customernumber_gin_trgm_idx    ON customer        USING gin (customernumber          gin_trgm_ops);
CREATE INDEX customer_name_gin_trgm_idx              ON customer        USING gin (name                    gin_trgm_ops);

CREATE INDEX vendor_vendornumber_gin_trgm_idx        ON vendor          USING gin (vendornumber            gin_trgm_ops);
CREATE INDEX vendor_name_gin_trgm_idx                ON vendor          USING gin (name                    gin_trgm_ops);

CREATE INDEX parts_partnumber_gin_trgm_idx           ON parts           USING gin (partnumber              gin_trgm_ops);
CREATE INDEX parts_description_gin_trgm_idx          ON parts           USING gin (description             gin_trgm_ops);

CREATE INDEX oe_ordnumber_gin_trgm_idx               ON oe              USING gin (ordnumber               gin_trgm_ops);
CREATE INDEX oe_quonumber_gin_trgm_idx               ON oe              USING gin (quonumber               gin_trgm_ops);
CREATE INDEX oe_cusordnumber_gin_trgm_idx            ON oe              USING gin (cusordnumber            gin_trgm_ops);
CREATE INDEX oe_transaction_description_gin_trgm_idx ON oe              USING gin (transaction_description gin_trgm_ops);

CREATE INDEX do_donumber_gin_trgm_idx                ON delivery_orders USING gin (donumber                gin_trgm_ops);
CREATE INDEX do_ordnumber_gin_trgm_idx               ON delivery_orders USING gin (ordnumber               gin_trgm_ops);
CREATE INDEX do_cusordnumber_gin_trgm_idx            ON delivery_orders USING gin (cusordnumber            gin_trgm_ops);
CREATE INDEX do_transaction_description_gin_trgm_idx ON delivery_orders USING gin (transaction_description gin_trgm_ops);

CREATE INDEX ar_invnumber_gin_trgm_idx               ON ar              USING gin (invnumber               gin_trgm_ops);
CREATE INDEX ar_ordnumber_gin_trgm_idx               ON ar              USING gin (ordnumber               gin_trgm_ops);
CREATE INDEX ar_quonumber_gin_trgm_idx               ON ar              USING gin (quonumber               gin_trgm_ops);
CREATE INDEX ar_cusordnumber_gin_trgm_idx            ON ar              USING gin (cusordnumber            gin_trgm_ops);
CREATE INDEX ar_transaction_description_gin_trgm_idx ON ar              USING gin (transaction_description gin_trgm_ops);

CREATE INDEX ap_invnumber_gin_trgm_idx               ON ap              USING gin (invnumber               gin_trgm_ops);
CREATE INDEX ap_ordnumber_gin_trgm_idx               ON ap              USING gin (ordnumber               gin_trgm_ops);
CREATE INDEX ap_quonumber_gin_trgm_idx               ON ap              USING gin (quonumber               gin_trgm_ops);
CREATE INDEX ap_transaction_description_gin_trgm_idx ON ap              USING gin (transaction_description gin_trgm_ops);

CREATE INDEX gl_description_gin_trgm_idx             ON gl              USING gin (description             gin_trgm_ops);
CREATE INDEX gl_reference_gin_trgm_idx               ON gl              USING gin (reference               gin_trgm_ops);

CREATE INDEX orderitems_description_gin_trgm_idx     ON orderitems      USING gin (description             gin_trgm_ops);

CREATE INDEX doi_description_gin_trgm_idx       ON delivery_order_items USING gin (description             gin_trgm_ops);

CREATE INDEX invoice_description_gin_trgm_idx        ON invoice         USING gin (description             gin_trgm_ops);
