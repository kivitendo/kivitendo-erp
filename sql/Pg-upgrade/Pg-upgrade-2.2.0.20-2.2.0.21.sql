alter table contacts add column cp_abteilung text;
update contacts set cp_abteilung=cp_department;
alter table contacts drop column cp_department;
