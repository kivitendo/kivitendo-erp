-- @tag: dunning_config_interest_rate
-- @description: In der Tabelle dunning_config ist interest falsch benannt.
-- @depends: release_2_4_2
ALTER TABLE dunning_config RENAME interest TO interest_rate;
