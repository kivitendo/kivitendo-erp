alter table invoice add column longdescription text;
alter table orderitems add column longdescription text;
alter table translation rename column longtext to longdescription;

alter table ar add column storno boolean;
alter table ar alter column storno set default 'false';
alter table ap add column storno boolean;
alter table ap alter column storno set default 'false';