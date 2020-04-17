-- @tag: dunning_config_print_original_invoice
-- @description: Optional die Originalrechnung bei Zahlungserinnerungen ausdrucken
-- @depends: release_3_5_5
ALTER TABLE dunning_config ADD COLUMN print_original_invoice boolean;

