-- @tag: create_part_label_prints
-- @description: Tabelle für automatischen Edikettendruck
-- @depends: release_3_9_1

CREATE TYPE part_label_print_types AS ENUM (
  'single',
  'stock'
);

CREATE TABLE part_label_prints (
  price_history_id INTEGER REFERENCES parts_price_history(id) NOT NULL,
  print_type       part_label_print_types                     NOT NULL,
  template         TEXT                                       NOT NULL,

  PRIMARY KEY (price_history_id, print_type, template)
);
