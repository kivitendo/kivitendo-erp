-- @tag: record_links
-- @description: Verknüpfungen zwischen Aufträgen, Lieferscheinen und Rechnungen
-- @depends: delivery_orders
CREATE TABLE record_links (
  from_table varchar(50) NOT NULL,
  from_id    integer     NOT NULL,
  to_table   varchar(50) NOT NULL,
  to_id      integer     NOT NULL,

  itime      timestamp   DEFAULT now()
);

CREATE INDEX idx_record_links_from_table ON record_links (from_table);
CREATE INDEX idx_record_links_from_id    ON record_links (from_id);
CREATE INDEX idx_record_links_to_table   ON record_links (to_table);
CREATE INDEX idx_record_links_to_id      ON record_links (to_id);
