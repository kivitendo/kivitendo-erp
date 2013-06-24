-- @tag: defaults_show_mark_as_paid_config
-- @description: Einstellung, ob der "als bezahlt markieren"-Knopf angezeigt wird.
-- @depends: release_2_7_0

ALTER TABLE defaults ADD COLUMN is_show_mark_as_paid boolean DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN ir_show_mark_as_paid boolean DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN ar_show_mark_as_paid boolean DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN ap_show_mark_as_paid boolean DEFAULT TRUE;
