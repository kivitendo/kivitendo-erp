ALTER TABLE rmaitems ADD COLUMN tmp varchar(20);
UPDATE rmaitems SET tmp = unit;
ALTER TABLE rmaitems DROP COLUMN unit;
ALTER TABLE rmaitems RENAME tmp TO unit;
