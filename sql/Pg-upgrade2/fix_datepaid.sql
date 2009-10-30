-- @tag: fix_datepaid
-- @description: Felder datepaid in ar und ap richtig setzen
-- @depends: release_2_6_0

UPDATE ap
  SET datepaid = COALESCE((SELECT MAX(at.transdate)
                           FROM acc_trans at
                           LEFT JOIN chart c ON (at.chart_id = c.id)
                           WHERE (at.trans_id = ap.id)
                             AND (c.link LIKE '%paid%')),
                          COALESCE(ap.mtime::date, ap.itime::date))
  WHERE paid <> 0;

UPDATE ar
  SET datepaid = COALESCE((SELECT MAX(at.transdate)
                           FROM acc_trans at
                           LEFT JOIN chart c ON (at.chart_id = c.id)
                           WHERE (at.trans_id = ar.id)
                             AND (c.link LIKE '%paid%')),
                          COALESCE(ar.mtime::date, ar.itime::date))
  WHERE paid <> 0;
