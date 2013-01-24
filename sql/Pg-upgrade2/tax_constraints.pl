# @tag: tax_constraints
# @description: Setzt Fremdschlüssel und andere constraints auf die Tabellen tax und taxkeys
# @depends: release_3_0_0
# @charset: utf-8

use utf8;
use strict;
use SL::Locale;

die("This script cannot be run from the command line.") unless ($main::form);

sub mydberror {
  my ($msg) = @_;
  die($dbup_locale->text("Database update error:") . "<br>$msg<br>" . $DBI::errstr);
}

sub do_query {
  my ($query, $may_fail) = @_;

  if (!$dbh->do($query)) {
    mydberror($query) unless ($may_fail);
    $dbh->rollback();
    $dbh->begin_work();
  }
}

sub do_update {
#CHECK CONSISTANCY OF tax
  #update tax.rate and tax.taxdescription in order to set later NOT NULL constraints
my $query= <<SQL;
UPDATE tax SET rate=0 WHERE rate IS NULL;
UPDATE tax SET taxdescription='-' WHERE taxdescription IS NULL;
SQL

  do_query($query);

  #check automatic tax accounts
  $query= <<SQL;
SELECT count(*) FROM tax WHERE chart_id NOT IN (SELECT id FROM chart);
SQL
   
  my ($invalid_tax_account) = $dbh->selectrow_array($query);
  
  if ($invalid_tax_account > 0){
    #list all invalid tax accounts
    $query = <<SQL;
SELECT id,
  taxkey,
  taxdescription, 
  round(rate * 100, 2) AS rate 
FROM tax WHERE chart_id NOT IN (SELECT id FROM chart);
SQL

    my $sth = $dbh->prepare($query);
    $sth->execute || $main::form->dberror($query);

    $main::form->{TAX} = [];
    while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
      push @{ $main::form->{TAX} }, $ref;
    }
    $sth->finish;

    $main::form->{invalid_tax_account} = 1;
    print_error_message();
    return 0;
  } 

  #check entry tax.taxkey of NOT NULL
  $query= <<SQL;
SELECT count(*) FROM tax WHERE taxkey IS NULL;
SQL
   
  my ($taxkey_is_null) = $dbh->selectrow_array($query);
  
  if ($taxkey_is_null > 0){
    #list all invalid tax accounts
    $query = <<SQL;
SELECT id, 
  taxdescription, 
  round(rate * 100, 2) AS rate, 
  (SELECT accno FROM chart WHERE id = chart_id) AS taxnumber, 
  (SELECT description FROM chart WHERE id = chart_id) AS account_description
FROM tax 
WHERE taxkey IS NULL;
SQL

    my $sth = $dbh->prepare($query);
    $sth->execute || $main::form->dberror($query);

    $main::form->{TAX} = [];
    while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
      push @{ $main::form->{TAX} }, $ref;
    }
    $sth->finish;

    $main::form->{taxkey_is_null} = 1;
    print_error_message();
    return 0;
  } 
#END CHECK OF tax

#CHECK CONSISTANCY OF taxkeys
  #delete invalide entries in taxkeys
  $query= <<SQL;
DELETE FROM taxkeys 
WHERE chart_id IS NULL 
OR chart_id NOT IN (SELECT id FROM chart) 
OR startdate IS NULL;
SQL

  do_query($query);

#There are 3 cases for taxkeys.tax_id and taxkeys.taxkey_id
#taxkeys.taxkey_id is NULL and taxkeys.tax_id is not NULL:

  #Update taxkeys.taxkey_id with tax.taxkey
  $query= <<SQL;
UPDATE taxkeys 
SET taxkey_id = (SELECT t.taxkey 
                        FROM tax t 
                        WHERE t.id=tax_id)
WHERE taxkey_id IS NULL 
AND tax_id IS NOT NULL;
SQL
  
  do_query($query);

#taxkeys.taxkey_id and taxkeys.tax_id are NULL:
  
  #Set taxkey 0 in this case:
  $query= <<SQL;
UPDATE taxkeys
SET taxkey_id = 0, tax_id = (SELECT id FROM tax WHERE taxkey=0)
WHERE taxkey_id IS NULL
AND tax_id IS NULL;
SQL
   
  do_query($query);

#Last case where taxkeys.taxkey_id is not null and taxkeys.tax_id is null

  #If such entries exist we update with an entry in tax where tax.rate=0
  #and tax.taxkey corresponds to taxkeys.taxkey_id.
  #If no entry in tax with rate 0 and taxkey taxkeys.taxkey_id exists 
  #we create one.
  $query= <<SQL;
SELECT DISTINCT taxkey_id
FROM taxkeys 
WHERE taxkey_id IS NOT NULL 
AND tax_id IS NULL;
SQL

  my $sth = $dbh->prepare($query);
  $sth->execute || $main::form->dberror($query);

  $main::form->{TAXID} = [];
  my $rowcount = 0;
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    push @{ $main::form->{TAXID} }, $ref;
    $rowcount++;
  }
  $sth->finish;
  
  my $insertquery;
  my $updatequery;
  my $tax_id;
  for my $i (0 .. $rowcount-1){
    $query= qq|
SELECT id FROM tax WHERE rate = 0 and taxkey=| . $main::form->{TAXID}[$i]->{taxkey_id} . qq| LIMIT 1
|;  
    ($tax_id) = $dbh->selectrow_array($query); 
    if ( not $tax_id ){
      $insertquery=qq|
INSERT INTO tax (rate, taxdescription, taxkey) VALUES (0, '| . $::locale->text('0% tax with taxkey') . $main::form->{TAXID}[$i]->{taxkey_id} .  $::locale->text('. Automatically generated.') . 
qq|', | . $main::form->{TAXID}[$i]->{taxkey_id} . qq|);
|;
      do_query($insertquery);
      ($tax_id) = $dbh->selectrow_array($query);
      $tax_id || $main::form->dberror($query); 
    }
    $updatequery = qq|
UPDATE taxkeys SET tax_id= | . $tax_id . qq| WHERE taxkey_id = | . $main::form->{TAXID}[$i]->{taxkey_id} . qq| AND tax_id IS NULL
|;
    do_query($updatequery);
  }

#The triple taxkey_id, chart_id, startdate in taxkeys has to be unique
  #Select these entries:
  $query= <<SQL;
SELECT DISTINCT tk1.chart_id AS chart_id, tk1.startdate AS startdate
FROM taxkeys tk1 
WHERE (SELECT count(*) 
       FROM taxkeys tk2 
       WHERE tk2.chart_id  = tk1.chart_id 
       AND   tk2.startdate = tk1.startdate) > 1;
SQL

  $sth = $dbh->prepare($query);
  $sth->execute || $main::form->dberror($query);

  $main::form->{TAXKEYS} = [];
  $rowcount = 0;
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    push @{ $main::form->{TAXKEYS} }, $ref;
    $rowcount++;
  }
  $sth->finish;

  for my $i (0 .. $rowcount-1){
    $query= qq| 
DELETE FROM taxkeys tk1 
WHERE (SELECT count(*) 
       FROM taxkeys tk2 
       WHERE tk2.chart_id  = tk1.chart_id 
       AND   tk2.startdate = tk1.startdate) > 1 
AND NOT tk1.id = (SELECT id 
                  FROM taxkeys 
                  WHERE chart_id  = | . $main::form->{TAXKEYS}[$i]->{chart_id} . qq|
                  AND   startdate = '| . $main::form->{TAXKEYS}[$i]->{startdate} . qq|'
                  LIMIT 1)
|;

    do_query($query);
  }

#END CHECK OF taxkeys

#ADD CONSTRAINTS:
#Now the database is consistent, so we can add constraints:
  #Crate NOT NULL constraint for tax.rate with default value 0
  $query= <<SQL;
ALTER TABLE tax ALTER COLUMN rate SET NOT NULL;
ALTER TABLE tax ALTER COLUMN rate SET DEFAULT 0;
SQL

  do_query($query);

  #Create NOT NULL constraint for tax.description
  $query= <<SQL;
ALTER TABLE tax ALTER COLUMN taxdescription SET NOT NULL;
SQL

  do_query($query);

  #Create foreign key for tax.chart_id to chart.id
  $query= <<SQL;
ALTER TABLE tax ADD FOREIGN KEY (chart_id) REFERENCES chart(id);
SQL
  
  do_query($query);
  
  #Create NOT NULL constraint for tax.taxkey
  $query= <<SQL;
ALTER TABLE tax ALTER COLUMN taxkey SET NOT NULL;
SQL

  do_query($query);

  #Create NOT NULL constraint for taxkey.chart_id and foreign key for taxkey.chart_id
  $query= <<SQL;
ALTER TABLE taxkeys ALTER COLUMN chart_id SET NOT NULL;
ALTER TABLE taxkeys ADD FOREIGN KEY (chart_id) REFERENCES chart(id);
SQL
  
  do_query($query);

  #Create NOT NULL constraint for taxkey.startdate
  $query= <<SQL;
ALTER TABLE taxkeys ALTER COLUMN startdate SET NOT NULL;
SQL
  
  do_query($query);

  #Create NOT NULL constraint for taxkey.taxkey_id
  $query= <<SQL;
ALTER TABLE taxkeys ALTER COLUMN taxkey_id SET NOT NULL;
SQL
   
  do_query($query);

  #Create NOT NULL constraint for taxkey.tax_id
  $query= <<SQL;
ALTER TABLE taxkeys ALTER COLUMN tax_id SET NOT NULL;
SQL
   
  do_query($query);

  #The triple chart_id, taxkey_id, startdate should be unique:
  $query= <<SQL;
CREATE UNIQUE INDEX taxkeys_chartid_startdate ON taxkeys(chart_id, startdate);
SQL
  
  do_query($query);
#ALL CONSTRAINTS WERE ADDED

  return 1;
}; # end do_update


sub print_error_message {
  print $main::form->parse_html_template("dbupgrade/tax_constraints");
}

return do_update();
