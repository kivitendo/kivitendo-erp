-- @tag: shop_images_dont_skip_position
-- @description: Keine Lücken in Position bei Shopbilder
-- @depends: release_3_9_0

UPDATE shop_images
SET position = reordered.new_position
FROM (
  SELECT id, rank() OVER (PARTITION BY object_id ORDER BY position ASC) AS new_position
  FROM shop_images
) reordered
WHERE shop_images.id = reordered.id
AND shop_images.position IS DISTINCT FROM reordered.new_position;

CREATE OR REPLACE FUNCTION shop_images_reorder_position()
RETURNS TRIGGER
AS
$$
BEGIN
  UPDATE shop_images
  SET position = reordered.new_position
  FROM (
    SELECT id, rank() OVER (PARTITION BY object_id ORDER BY position ASC) AS new_position
    FROM shop_images
    WHERE shop_images.object_id = OLD.object_id
  ) reordered
  WHERE shop_images.id = reordered.id
  AND shop_images.position IS DISTINCT FROM reordered.new_position;

  RETURN OLD;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER after_delete_shop_images_trigger
AFTER DELETE ON shop_images
FOR EACH ROW
EXECUTE FUNCTION shop_images_reorder_position();
