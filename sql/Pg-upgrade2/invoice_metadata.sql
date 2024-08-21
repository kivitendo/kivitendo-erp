-- @tag: invoice_metadat
-- @description: Add vendor_partno and a foreign key for referencing detail transactions to invoice

ALTER TABLE invoice ADD COLUMN acc_trans_id integer;
ALTER TABLE invoice ADD COLUMN vendor_partno text;

ALTER TABLE invoice ADD CONSTRAINT acc_trans_id_fkey FOREIGN KEY (acc_trans_id) REFERENCES public.acc_trans(acc_trans_id);
ALTER TABLE invoice ADD CONSTRAINT acc_trans_id_key UNIQUE (acc_trans_id);
