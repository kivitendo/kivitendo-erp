package SL::Chart;

use SL::Form;
use SL::DBUtils;

use strict;

sub list {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my @values   = ();
  my @where    = ();

  if ($params{link}) {
    if ($params{link} =~ '%') {
      push @where,  "c.link LIKE ?";
      push @values, $params{link};

    } else {
      push @where,  "(c.link = ?) OR (c.link LIKE ?) OR (c.link LIKE ?) OR (c.link LIKE ?)";
      push @values, $params{link}, '%:' . $params{link} . ':%', '%:' . $params{link}, $params{link} . ':%';
    }
  }

  my $where = scalar @where ? 'WHERE ' . join(' AND ', map { "($_)" } @where) : '';

  my $query =
    qq|SELECT c.id, c.accno, c.description, c.link
       FROM chart c
       $where
       ORDER BY c.accno|;

  my $charts = selectall_hashref_query($form, $dbh, $query, @values);

  $main::lxdebug->leave_sub();

  return $charts;
}

1;

