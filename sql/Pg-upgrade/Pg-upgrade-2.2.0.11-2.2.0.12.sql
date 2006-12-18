alter table parts add column not_discountable boolean;
alter table parts alter column not_discountable set default 'false';
update parts set not_discountable='false';