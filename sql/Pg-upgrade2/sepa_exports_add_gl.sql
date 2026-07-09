-- @tag: sepa_exports_add_gl
-- @description: Verrechnete Gutschriften können auch Skonto Steuerkorrektur
-- @depends: release_4_0_0 sepa_exports_add_acc_trans
ALTER TABLE sepa_exports_acc_trans ADD gl_id INTEGER REFERENCES gl(id);

