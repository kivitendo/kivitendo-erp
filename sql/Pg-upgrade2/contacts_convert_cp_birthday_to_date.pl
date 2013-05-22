# @tag: contacts_convert_cp_birthday_to_date
# @description: Umstellung cp_birthday von Freitext auf Datumsfeld
# @depends: release_2_7_0
package SL::DBUpgrade2::contacts_convert_cp_birthday_to_date;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub convert_to_date {
  my ($self, $str) = @_;

  return '' if !$str || ($str =~ m/00.*00.*00.*00/); # 0000-00-00 may be present in old databases.

  my $sth = $self->dbh->prepare('SELECT ?::date AS date') or return undef;
  $sth->execute($str)                                     or return undef;

  return $sth->fetchrow_hashref->{date};
}

sub run {
  my ($self) = @_;

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

  my $sth = $self->dbh->prepare($sql) or die $self->dbh->errstr;
  $sth->execute or die $self->dbh->errstr;

  my $i = -1;
  while (my $row = $sth->fetchrow_hashref) {
    $i++;
    $row->{cp_birthday} = $self->convert_to_date($::form->{form_submitted} ? $::form->{'cp_birthday_'. $i} : $row->{cp_birthday_old});
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

    $self->dbh->do($sql);

    $sql = <<SQL;
      UPDATE contacts
      SET   cp_birthday = ?
      WHERE cp_id = ?
SQL

    $sth = $self->dbh->prepare($sql) or die $self->dbh->errstr;

    foreach (grep { $_->{cp_birthday} ne '' } @auto_data) {
      $sth->execute($_->{cp_birthday}, $_->{cp_id}) or die $self->dbh->errstr;
    }

    return 1;
  }
}

1;
