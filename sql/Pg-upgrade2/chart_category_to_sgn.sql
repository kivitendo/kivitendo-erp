-- @tag: chart_category_to_sgn
-- @description: Fuegt eine Hilfsfunktion ein mit der die interne Reprasentation der Konten (Haben positiv) in die Mehrungsrepraesentation gewandelt werden kann.
-- @depends:

 CREATE OR REPLACE FUNCTION chart_category_to_sgn(CHARACTER(1)) 
 RETURNS INTEGER
 LANGUAGE SQL
 AS 'SELECT  1 WHERE $1 IN (''I'', ''L'', ''Q'')
      UNION 
    SELECT -1 WHERE $1 IN (''E'', ''A'')';

