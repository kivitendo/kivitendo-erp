-- @tag: shop_add_default_country
-- @description: Ländervoreinstellung für Shop-Importe
-- @depends: shops countries

ALTER TABLE shops ADD COLUMN default_country_id INTEGER REFERENCES countries (id);
