-- @tag: invoice_items_tax_id_not_null
-- @description: tax_id für alle "alten" Rechnungen füllen und zur Pflichtspalte machen
-- @depends: add_charts_and_tax_to_invoice_items

UPDATE invoice SET tax_id =
  (SELECT tax.id FROM invoice i
    JOIN ap ON (ap.id = i.trans_id)
    LEFT JOIN parts p ON (p.id = i.parts_id)
    LEFT JOIN taxzone_charts tc ON (tc.taxzone_id = ap.taxzone_id AND tc.buchungsgruppen_id = p.buchungsgruppen_id)
    LEFT JOIN chart c ON (c.id = tc.expense_accno_id)
    LEFT JOIN taxkeys tk ON (tk.chart_id = c.id AND tk.taxkey_id = c.taxkey_id )
    LEFT JOIN tax ON (tax.id = tk.tax_id)
  WHERE tk.startdate <= (SELECT COALESCE(tax_point, deliverydate, transdate) FROM ap WHERE id = invoice.trans_id)
  ORDER BY tk.startdate DESC LIMIT 1)
WHERE invoice.tax_id IS NULL AND (SELECT invoice FROM ap WHERE id = invoice.trans_id) IS TRUE;

UPDATE invoice SET tax_id =
  (SELECT tax.id FROM invoice i
    JOIN ar ON (ar.id = i.trans_id)
    LEFT JOIN parts p ON (p.id = i.parts_id)
    LEFT JOIN taxzone_charts tc ON (tc.taxzone_id = ar.taxzone_id AND tc.buchungsgruppen_id = p.buchungsgruppen_id)
    LEFT JOIN chart c ON (c.id = tc.income_accno_id)
    LEFT JOIN taxkeys tk ON (tk.chart_id = c.id AND tk.taxkey_id = c.taxkey_id )
    LEFT JOIN tax ON (tax.id = tk.tax_id)
  WHERE tk.startdate <= (SELECT COALESCE(tax_point, deliverydate, transdate) FROM ar WHERE id = invoice.trans_id)
  ORDER BY tk.startdate DESC LIMIT 1)
WHERE invoice.tax_id IS NULL AND (SELECT invoice FROM ar WHERE id = invoice.trans_id) IS TRUE;

ALTER TABLE invoice ALTER tax_id SET NOT NULL;
