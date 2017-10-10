-- @tag: trigram_indices_webshop
-- @description: Trigram Indizes für Fuzzysearch bei der Kundensuche im Shopmodul
-- @depends: release_3_5_0 trigram_extension

CREATE INDEX customer_street_gin_trgm_idx            ON customer        USING gin (street                  gin_trgm_ops);
