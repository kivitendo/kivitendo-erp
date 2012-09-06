-- @tag: customer_add_taxincluded_checked
-- @description: Feld "Steuer im Preis inbegriffen" vormarkierbar machen
-- @encoding: utf-8
-- @depends: release_2_7_0

ALTER TABLE customer ADD COLUMN taxincluded_checked varchar(1) DEFAULT '' NOT NULL;
