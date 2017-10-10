-- @tag: first_aggregator
-- @description: SQL Aggregat Funktion FIRST
-- @depends: release_3_0_0

CREATE OR REPLACE FUNCTION public.first_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE SQL IMMUTABLE STRICT AS $$
  SELECT $1;
$$;

CREATE AGGREGATE public.FIRST (
  sfunc    = public.first_agg,
  basetype = anyelement,
  stype    = anyelement
);
