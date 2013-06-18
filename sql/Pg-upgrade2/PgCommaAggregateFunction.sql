-- @tag: PgCommaAggregateFunction
-- @description: Neue Postgres Funktion zur Abfrage mehrdeutiger Ergebniszeilen als kommagetrennte Liste
-- @depends: release_2_4_1
-- Taken from: http://www.zigo.dhs.org/postgresql/#comma_aggregate
-- Copyright © 2005 Dennis Björklund
-- License: Free
-- Thx. to A. Kretschmer, http://archives.postgresql.org/pgsql-de-allgemein/2007-02/msg00006.php
CREATE FUNCTION comma_aggregate(text,text) RETURNS text AS '
  SELECT CASE WHEN $1 <> '''' THEN $1 || '', '' || $2 
                              ELSE $2 
         END; 
' LANGUAGE sql IMMUTABLE STRICT; 

CREATE AGGREGATE comma (basetype=text, sfunc=comma_aggregate, stype=text, initcond='' );

