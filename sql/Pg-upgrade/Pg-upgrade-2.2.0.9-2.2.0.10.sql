alter table invoice add column subtotal boolean;
alter table orderitems add column subtotal boolean;
alter table invoice alter column subtotal set default 'false';
alter table orderitems alter column subtotal set default 'false';