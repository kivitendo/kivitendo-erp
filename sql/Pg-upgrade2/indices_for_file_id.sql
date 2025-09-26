-- @tag: indices_for_file_id
-- @description: Indizes für Files in referenzierenden Tabellen
-- @depends: file_full_texts file_version shopimages oe_version
-- @required_by: add_file_version

CREATE index ON file_full_texts(file_id);
CREATE index ON file_versions(file_id);
CREATE index ON oe_version(file_id);
CREATE index ON shop_images(file_id);
