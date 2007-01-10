-- @tag: rename_buchungsgruppen_accounts_16_19_percent
-- @description: Benennt einige Buchungsgruppen und Konten von &quot;... 16%&quot; in &quot;... 16%/19%&quot; um. Wird nur beim SKR03 und SKR04 gemacht.
-- @depends:
UPDATE buchungsgruppen
  SET description = 'Standard 16%/19%'
  WHERE
    ((SELECT coa FROM defaults) IN ('Germany-DATEV-SKR03EU', 'Germany-DATEV-SKR04EU')) AND
    (description = 'Standard 16%');
UPDATE chart SET description = replace(description, '16%', '16%/19%')
  WHERE
    ((SELECT coa FROM defaults) IN ('Germany-DATEV-SKR03EU', 'Germany-DATEV-SKR04EU')) AND
    (link NOT ILIKE '%tax%') AND
    (description ~ '16%') AND (description !~ '19%');
