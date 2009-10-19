package IO;

use strict;

use SL::DBUtils;

sub retrieve_partunits {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(part_ids));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh();

  my $query    = qq|SELECT id, unit FROM parts WHERE id IN (| . join(', ', map { '?' } @{ $params{part_ids} }) . qq|)|;
  my %units    = selectall_as_map($form, $dbh, $query, 'id', 'unit', @{ $params{part_ids} });

  $main::lxdebug->leave_sub();

  return %units;
}


1;
