-- @tag: chart_names2
-- @description: Behebt ein paar Schreibfehler in Kontennamen in den Kontenramen SKR03 und SKR04.
-- @depends:
UPDATE chart
  SET description = 'Fahrzeugkosten'
  WHERE
    ((SELECT coa FROM defaults) IN ('Germany-DATEV-SKR03EU', 'Germany-DATEV-SKR04EU')) AND
    (description = 'Fahrzugkosten');
UPDATE chart
  SET description = replace(description, 'Unentgeld', 'Unentgelt')
  WHERE
    ((SELECT coa FROM defaults) IN ('Germany-DATEV-SKR03EU', 'Germany-DATEV-SKR04EU')) AND
    (description LIKE '%Unentgeld%');
