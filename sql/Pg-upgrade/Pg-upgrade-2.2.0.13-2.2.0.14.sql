alter table oe add column proforma boolean;
alter table oe alter column proforma set default 'false';
update oe set proforma='f';
