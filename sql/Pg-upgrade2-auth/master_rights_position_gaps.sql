-- @tag: master_rights_position_gaps
-- @description: Position in Rechtetabelle mit 100 multipliziert damit Lücken für neue Einträge entstehen
-- @depends: release_3_4_0 add_master_rights

UPDATE auth.master_rights SET position=position*100;
