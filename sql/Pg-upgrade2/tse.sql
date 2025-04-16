-- @tag: tse
-- @description: Tabellen für TSE
-- @depends: release_3_9_0

create table tse_devices (
  id serial primary key,
  device_id text not null, -- "TSE_439A361F12696C620D7F904DBF3C5283681C0C950875747492603093927FD5_3"
  serial text not null, -- "439A361F12696C620D7F904DBF3C5283681C0C950875747492603093927FD5"
  description text,  -- e.g. "POS1"
  active boolean not null default true
);
alter table tse_devices add constraint device_id_unique unique (device_id);

-- always gets written in one go, after the transaction has been completed
-- needs to be split into start_transaction and finish_transaction
CREATE TABLE tse_transactions (
  id serial primary key,
  transaction_number text NOT NULL,
  client_id TEXT NOT NULL,
  process_data TEXT,  -- base64 encoded
  sig_counter TEXT NOT NULL,
  pos_serial_number TEXT NOT NULL,
  start_timestamp TIMESTAMPTZ NOT NULL,
  finish_timestamp TIMESTAMPTZ NOT NULL,
  signature TEXT NOT NULL,
  pos_id int references points_of_sale(id) NOT NULL,
  tse_device_id int references tse_devices(id) NOT NULL,
  process_type text not null,  -- "Kassenbeleg-V1"
  json text,
  ar_id integer references ar(id) unique,
  unique (transaction_number, tse_device_id)
);

CREATE INDEX tse_transactions_ar_id_idx ON tse_transactions(ar_id);
