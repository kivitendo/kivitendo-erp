-- @tag: price_source_client_config
-- @description: Preisquellen: Preisquellen ausschaltbar per Mandant
-- @depends: release_3_1_0

ALTER TABLE defaults ADD disabled_price_sources TEXT[];
