-- @tag: project_bob_attributes_itime_default_fix
-- @description: Standardwert für 'itime'-Spalten in Bob-Tabellen fixen
-- @depends: project_bob_attributes

ALTER TABLE project                    ALTER COLUMN itime SET DEFAULT now();
ALTER TABLE project_status             ALTER COLUMN itime SET DEFAULT now();
ALTER TABLE project_phases             ALTER COLUMN itime SET DEFAULT now();
ALTER TABLE project_roles              ALTER COLUMN itime SET DEFAULT now();
ALTER TABLE project_participants       ALTER COLUMN itime SET DEFAULT now();
ALTER TABLE project_phase_participants ALTER COLUMN itime SET DEFAULT now();
