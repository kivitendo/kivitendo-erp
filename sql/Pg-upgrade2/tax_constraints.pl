# @tag: tax_constraints
# @description: Setzt Fremdschlüssel und andere constraints auf die Tabellen tax und taxkeys
# @depends: release_3_0_0 charts_without_taxkey
package SL::DBUpgrade2::tax_constraints;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  #CHECK CONSISTANCY OF tax
  #update tax.rate and tax.taxdescription in order to set later NOT NULL constraints
  my $query= <<SQL;
    UPDATE tax SET rate=0 WHERE rate IS NULL;
    UPDATE tax SET taxdescription='-' WHERE COALESCE(taxdescription, '') = '';
SQL

  $self->db_query($query);

  #check automatic tax accounts
  $query= <<SQL;
    SELECT count(*) FROM tax WHERE chart_id NOT IN (SELECT id FROM chart);
SQL

  my ($invalid_tax_account) = $self->dbh->selectrow_array($query);

  if ($invalid_tax_account > 0){
    #list all invalid tax accounts
    $query = <<SQL;
      SELECT id,
        taxkey,
        taxdescription,
        round(rate * 100, 2) AS rate
      FROM tax WHERE chart_id NOT IN (SELECT id FROM chart);
SQL

    my $sth = $self->dbh->prepare($query);
    $sth->execute || $::form->dberror($query);

    $::form->{TAX} = [];
    while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
      push @{ $::form->{TAX} }, $ref;
    }
    $sth->finish;

    $::form->{invalid_tax_account} = 1;
    print_error_message();
    return 0;
  }

  #check entry tax.taxkey of NOT NULL
  $query= <<SQL;
    SELECT count(*) FROM tax WHERE taxkey IS NULL;
SQL

  my ($taxkey_is_null) = $self->dbh->selectrow_array($query);

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

    my $sth = $self->dbh->prepare($query);
    $sth->execute || $::form->dberror($query);

    $::form->{TAX} = [];
    while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
      push @{ $::form->{TAX} }, $ref;
    }
    $sth->finish;

    $::form->{taxkey_is_null} = 1;
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

  $self->db_query($query);

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

  $self->db_query($query);

  #taxkeys.taxkey_id and taxkeys.tax_id are NULL:

  #Set taxkey 0 in this case:
  $query= <<SQL;
    UPDATE taxkeys
    SET taxkey_id = 0, tax_id = (SELECT id FROM tax WHERE taxkey=0)
    WHERE taxkey_id IS NULL
    AND tax_id IS NULL;
SQL

  $self->db_query($query);

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

  my $sth = $self->dbh->prepare($query);
  $sth->execute || $::form->dberror($query);

  $::form->{TAXID} = [];
  my $rowcount = 0;
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    push @{ $::form->{TAXID} }, $ref;
    $rowcount++;
  }
  $sth->finish;

  my $insertquery;
  my $updatequery;
  my $tax_id;
  for my $i (0 .. $rowcount-1){
    $query= qq|
      SELECT id FROM tax WHERE rate = 0 and taxkey=| . $::form->{TAXID}[$i]->{taxkey_id} . qq| LIMIT 1
|;
    ($tax_id) = $self->dbh->selectrow_array($query);
    if ( not $tax_id ){
      $insertquery=qq|
        INSERT INTO tax (rate, taxdescription, taxkey) VALUES (0, '| . $::locale->text('0% tax with taxkey') . $::form->{TAXID}[$i]->{taxkey_id} .  $::locale->text('. Automatically generated.') .
        qq|', | . $::form->{TAXID}[$i]->{taxkey_id} . qq|);
|;
      $self->db_query($insertquery);
      ($tax_id) = $self->dbh->selectrow_array($query);
      $tax_id || $::form->dberror($query);
    }
    $updatequery = qq|
      UPDATE taxkeys SET tax_id= | . $tax_id . qq| WHERE taxkey_id = | . $::form->{TAXID}[$i]->{taxkey_id} . qq| AND tax_id IS NULL
|;
    $self->db_query($updatequery);
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

  $sth = $self->dbh->prepare($query);
  $sth->execute || $::form->dberror($query);

  $::form->{TAXKEYS} = [];
  $rowcount = 0;
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    push @{ $::form->{TAXKEYS} }, $ref;
    $rowcount++;
  }
  $sth->finish;

  for my $i (0 .. $rowcount-1){
    $query= <<SQL;
      DELETE FROM taxkeys tk1
      WHERE (tk1.chart_id  = ?)
        AND (tk1.startdate = ?)
        AND (tk1.id <> (
          SELECT id
          FROM taxkeys
          WHERE (chart_id  = ?)
          AND   (startdate = ?)
          LIMIT 1))
SQL

    $self->db_query($query, bind => [ ($::form->{TAXKEYS}[$i]->{chart_id}, $::form->{TAXKEYS}[$i]->{startdate}) x 2 ]);
  }

  #END CHECK OF taxkeys

  #ADD CONSTRAINTS:
  #Now the database is consistent, so we can add constraints:
  #Crate NOT NULL constraint for tax.rate with default value 0
  $query= <<SQL;
    ALTER TABLE tax ALTER COLUMN rate SET NOT NULL;
    ALTER TABLE tax ALTER COLUMN rate SET DEFAULT 0;
SQL

  $self->db_query($query);

  #Create NOT NULL constraint for tax.description
  $query= <<SQL;
    ALTER TABLE tax ALTER COLUMN taxdescription SET NOT NULL;
SQL

  $self->db_query($query);

  #Create foreign key for tax.chart_id to chart.id
  $query= <<SQL;
    ALTER TABLE tax ADD FOREIGN KEY (chart_id) REFERENCES chart(id);
SQL

  $self->db_query($query);

  #Create NOT NULL constraint for tax.taxkey
  $query= <<SQL;
    ALTER TABLE tax ALTER COLUMN taxkey SET NOT NULL;
SQL

  $self->db_query($query);

  #Create NOT NULL constraint for taxkey.chart_id and foreign key for taxkey.chart_id
  $query= <<SQL;
    ALTER TABLE taxkeys ALTER COLUMN chart_id SET NOT NULL;
    ALTER TABLE taxkeys ADD FOREIGN KEY (chart_id) REFERENCES chart(id);
SQL

  $self->db_query($query);

  #Create NOT NULL constraint for taxkey.startdate
  $query= <<SQL;
    ALTER TABLE taxkeys ALTER COLUMN startdate SET NOT NULL;
SQL

  $self->db_query($query);

  #Create NOT NULL constraint for taxkey.taxkey_id
  $query= <<SQL;
    ALTER TABLE taxkeys ALTER COLUMN taxkey_id SET NOT NULL;
SQL

  $self->db_query($query);

  #Create NOT NULL constraint for taxkey.tax_id
  $query= <<SQL;
    ALTER TABLE taxkeys ALTER COLUMN tax_id SET NOT NULL;
SQL

  $self->db_query($query);

  #The triple chart_id, taxkey_id, startdate should be unique:
  $query= <<SQL;
    CREATE UNIQUE INDEX taxkeys_chartid_startdate ON taxkeys(chart_id, startdate);
SQL

  $self->db_query($query);
  #ALL CONSTRAINTS WERE ADDED

  return 1;
} # end run


sub print_error_message {
  print $::form->parse_html_template("dbupgrade/tax_constraints");
}

1;
