package SL::DB::Manager::CsvImportReport;

use strict;

use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::CsvImportReport' }

__PACKAGE__->make_manager_methods;

sub cleanup {
  my ($self) = @_;

  $::auth->active_session_ids;

  # get expired reports
  my $objects = $self->get_all(query => [
   '!session_id' => [ $::auth->active_session_ids ]
  ]);

  $_->destroy for @$objects;

  # get reports for the active session that aren't the latest
  $objects = $self->get_all(
    query => [ session_id => $::auth->get_session_id, ],
    sort_by => [ 'id' ],
  );

  # skip the last one
  for (0 .. $#$objects - 1) {
    $objects->[$_]->destroy;
  }
}

1;

