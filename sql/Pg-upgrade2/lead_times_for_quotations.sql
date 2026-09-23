-- @tag: lead_times_for_quotations
-- @description: Lieferzeiten ähnlich zu Liefer- und Zahlungsbedingungen auf Angeboten angeben
-- @depends: release_4_1_0

CREATE TABLE lead_times (
  id                SERIAL PRIMARY KEY,
  description       text,
  description_long  text,
  sortkey           integer not null,
  obsolete          boolean not null DEFAULT false,
  itime             timestamp not null DEFAULT now(),
  mtime             timestamp not null
);

CREATE TRIGGER mtime_lead_times
  BEFORE UPDATE ON lead_times
  FOR EACH ROW
  EXECUTE PROCEDURE set_mtime();

ALTER TABLE oe ADD COLUMN lead_time_id integer references lead_times (id);

ALTER TABLE defaults ADD COLUMN quotation_warn_no_lead_time boolean not null DEFAULT false;

CREATE OR REPLACE FUNCTION generic_translations_delete_on_lead_times_delete_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    DELETE FROM generic_translations
    WHERE (translation_id = OLD.id)
      AND (translation_type IN ('SL::DB::LeadTime/description_long'));
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_delete_lead_time_trigger ON lead_times;
CREATE TRIGGER after_delete_lead_time_trigger
 AFTER DELETE ON lead_times
 FOR EACH ROW EXECUTE PROCEDURE generic_translations_delete_on_lead_times_delete_trigger();
