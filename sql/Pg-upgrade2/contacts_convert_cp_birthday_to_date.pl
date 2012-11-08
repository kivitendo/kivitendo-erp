# @tag: contacts_convert_cp_birthday_to_date
# @description: Umstellung cp_birthday von Freitext auf Datumsfeld
# @depends: release_2_7_0
package contacts_convert_cp_birthday_to_date;
use strict;

die 'This script cannot be run from the command line.' if !$::form;

sub convert_to_date {
  my ($str) = @_;

  return '' if !$str;

  my $sth = $dbh->prepare('SELECT ?::date AS date') or return undef;
  $sth->execute($str)                               or return undef;

  return $sth->fetchrow_hashref->{date};
}

sub update {
  my @data      = ();
  my @auto_data = ();
  my $sql       = <<SQL;
    SELECT
      cp_id,
      cp_givenname,
      cp_name,
      cp_birthday AS cp_birthday_old
    FROM contacts
    ORDER BY cp_id;
SQL

  my $sth = $dbh->prepare($sql) or die $dbh->errstr;
  $sth->execute or die $dbh->errstr;

  my $i = -1;
  while (my $row = $sth->fetchrow_hashref) {
    $i++;
    $row->{cp_birthday} = convert_to_date($::form->{form_submitted} ? $::form->{'cp_birthday_'. $i} : $row->{cp_birthday_old});
    $row->{row_index}   = $i;

    if ( defined($row->{cp_birthday}) ) {
       push(@auto_data, $row);
    } else {
       push(@data,      $row);
    }
  }

  $::form->{data}       = \@data;
  $::form->{auto_data}  = \@auto_data;
  $::form->{row_length} = $i;

  if (@data) {
    print $::form->parse_html_template('dbupgrade/contacts_convert_cp_birthday_to_date_form');
    return 2;
  } else {
    $sql = <<SQL;
      ALTER TABLE contacts DROP COLUMN cp_birthday;
      ALTER TABLE contacts ADD COLUMN cp_birthday date;
SQL

    $dbh->do($sql);

    $sql = <<SQL;
      UPDATE contacts
      SET   cp_birthday = ?
      WHERE cp_id = ?
SQL

    $sth = $dbh->prepare($sql) or die $dbh->errstr;

    foreach (grep { $_->{cp_birthday} ne '' } @auto_data) {
      $sth->execute($_->{cp_birthday}, $_->{cp_id}) or die $dbh->errstr;
    }

    return 1;
  }
}

return update();
