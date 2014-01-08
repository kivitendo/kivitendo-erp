-- @tag: fix_datepaid_for_sepa_transfers
-- @description: Feld »datepaid« bei via SEPA durchgeführten Transfers richtig setzen
-- @depends: release_3_0_0
UPDATE ar
SET datepaid = (
  SELECT MAX(acc.transdate)
  FROM acc_trans acc
  LEFT JOIN chart c ON (c.id = acc.chart_id)
  WHERE (acc.trans_id = ar.id)
    AND (c.link LIKE '%paid%')
)
WHERE (ar.amount != 0)
  AND NOT ar.storno
  AND ar.id IN (
    SELECT sei.ar_id
    FROM sepa_export_items sei
    WHERE (sei.ar_id IS NOT NULL)
      AND sei.executed
  );
