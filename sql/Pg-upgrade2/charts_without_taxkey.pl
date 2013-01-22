# @tag: charts_without_taxkey
# @description: F&uuml;gt f&uuml;r jedes Konto, was keien Steuerschl&uuml;ssel hat, den Steuerschl&uuml;ssel 0 hinzu
# @depends:
# @charset: UTF-8

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
  my ($taxkey0_with_taxes_exists) = $dbh->selectrow_array("SELECT COUNT(*) FROM tax WHERE taxkey=0 AND NOT rate=0;"); 

  if ($taxkey0_with_taxes_exists > 0){
    print_error_message();
    return 0;
  }

  my ($taxkey0_exists) = $dbh->selectrow_array("SELECT COUNT(*) FROM tax WHERE taxkey=0");

  if ($taxkey0_exists == 0){
    my $insert_taxkey0 = <<SQL;
INSERT INTO tax 
  (rate, taxkey, taxdescription)
  VALUES
  (0, 0, 'Keine Steuer');
SQL
    do_query($insert_taxkey0);
    print $::locale->text("taxkey 0 with taxrate 0 was created.");
  };
  
  my $insert_taxkeys = <<SQL;
INSERT INTO taxkeys 
  (chart_id, tax_id, taxkey_id, startdate) 
  SELECT 
  c.id, (SELECT id FROM tax WHERE taxkey=0), 0, '1970-01-01' 
  FROM chart c WHERE c.id NOT IN (SELECT chart_id FROM taxkeys);
SQL
    do_query($insert_taxkeys);
    return 1;
}; # end do_update

sub print_error_message {
  print $main::form->parse_html_template("dbupgrade/taxkey_update");
};

return do_update();
