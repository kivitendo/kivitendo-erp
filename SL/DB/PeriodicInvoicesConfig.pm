package SL::DB::PeriodicInvoicesConfig;

use strict;

use SL::DB::MetaSetup::PeriodicInvoicesConfig;

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

our @PERIODICITIES  = qw(m q f b y);
our %PERIOD_LENGTHS = ( m => 1, q => 3, f => 4, b => 6, y => 12 );

sub get_period_length {
  my $self = shift;
  return $PERIOD_LENGTHS{ $self->periodicity } || 1;
}

sub _log_msg {
  $::lxdebug->message(LXDebug->DEBUG1(), join('', @_));
}

sub handle_automatic_extension {
  my $self = shift;

  _log_msg("HAE for " . $self->id . "\n");
  # Don't extend configs that have been terminated. There's nothing to
  # extend if there's no end date.
  return if $self->terminated || !$self->end_date;

  my $today    = DateTime->now_local;
  my $end_date = $self->end_date;

  _log_msg("today $today end_date $end_date\n");

  # The end date has not been reached yet, therefore no extension is
  # needed.
  return if $today <= $end_date;

  # The end date has been reached. If no automatic extension has been
  # set then terminate the config and return.
  if (!$self->extend_automatically_by) {
    _log_msg("setting inactive\n");
    $self->active(0);
    $self->save;
    return;
  }

  # Add the automatic extension period to the new end date as long as
  # the new end date is in the past. Then save it and get out.
  $end_date->add(months => $self->extend_automatically_by) while $today > $end_date;
  _log_msg("new end date $end_date\n");

  $self->end_date($end_date);
  $self->save;

  return $end_date;
}

sub get_previous_invoice_date {
  my $self  = shift;

  my $query = <<SQL;
    SELECT MAX(ar.transdate)
    FROM periodic_invoices
    LEFT JOIN ar ON (ar.id = periodic_invoices.ar_id)
    WHERE periodic_invoices.config_id = ?
SQL

  my ($max_transdate) = $self->dbh->selectrow_array($query, undef, $self->id);

  return undef unless $max_transdate;
  return ref $max_transdate ? $max_transdate : $self->db->parse_date($max_transdate);
}

1;
