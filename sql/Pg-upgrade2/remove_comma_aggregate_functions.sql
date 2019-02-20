-- @tag: remove_comma_aggregate_functions
-- @description: Entfernt Aggregate Funktion comma
-- @depends: release_3_5_3

DROP AGGREGATE IF EXISTS comma(text);
DROP FUNCTION IF EXISTS comma_aggregate ( text, text) ;
