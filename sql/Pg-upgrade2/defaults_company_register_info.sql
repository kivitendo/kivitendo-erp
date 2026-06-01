-- @tag: defaults_company_register_info
-- @description: Felder für Registrier-Infos der Firma (Geschäftsführung/Handelsregistereintrag/Sitz)
-- @depends: release_4_0_0

ALTER TABLE defaults ADD COLUMN managing_directors        TEXT,
                     ADD COLUMN registered_seat           TEXT,
                     ADD COLUMN commercial_register_entry TEXT,
                     ADD COLUMN commercial_register_place TEXT;
