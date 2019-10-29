-- @tag: master_rights_positions_fix
-- @description: Position in Rechtetabelle korrigieren (falls zutreffend)
-- @depends: release_3_5_4 purchase_letter_rights all_drafts_edit right_purchase_all_edit rights_sales_purchase_edit_prices

UPDATE auth.master_rights SET position = position/100
       WHERE position > 10000
       AND   name IN ('purchase_letter_edit', 'purchase_letter_report', 'all_drafts_edit');

UPDATE auth.master_rights SET position = (SELECT position + 10 FROM auth.master_rights WHERE name = 'purchase_letter_edit')
       WHERE position > 10000
       AND   name LIKE 'purchase_all_edit';

UPDATE auth.master_rights SET position =(SELECT position + 10 FROM auth.master_rights WHERE name = 'purchase_all_edit')
       WHERE position > 10000
       AND   name LIKE 'purchase_edit_prices';
