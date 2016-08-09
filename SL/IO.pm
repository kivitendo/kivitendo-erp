package IO;

use List::Util qw(first);
use List::MoreUtils qw(any);

use SL::DBUtils;
use SL::DB;

use strict;

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


sub set_datepaid {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id table));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  SL::DB->client->with_transaction(sub {
    my $dbh      = $params{dbh} || SL::DB->client->dbh;
    my $id       = conv_i($params{id});
    my $table    = (any { $_ eq $params{table} } qw(ar ap gl)) ? $params{table} : 'ar';

    my ($curr_datepaid, $curr_paid) = selectfirst_array_query($form, $dbh, qq|SELECT datepaid, paid FROM $table WHERE id = ?|, $id);

    my $query    = <<SQL;
      SELECT MAX(at.transdate)
      FROM acc_trans at
      LEFT JOIN chart c ON (at.chart_id = c.id)
      WHERE (at.trans_id = ?)
        AND (c.link LIKE '%paid%')
SQL

    my ($max_acc_trans_date) = selectfirst_array_query($form, $dbh, $query, $id);

    if ($max_acc_trans_date && ($max_acc_trans_date ne $curr_datepaid)) {
      # 1. Fall: Es gab mindestens eine Zahlung, und das Datum der Zahlung entspricht nicht
      # dem vermerkten Zahlungsdatum.
      do_query($form, $dbh, qq|UPDATE $table SET datepaid = ? WHERE id = ?|, $max_acc_trans_date, $id);

    } elsif (!$max_acc_trans_date && ($curr_paid * 1)) {
      # 2. Fall: Es gab keine Zahlung, aber paid ist nicht 0. Das ist z.B. der Fall, wenn
      # die Funktion "als bezahlt buchen" verwendet oder wenn ein Beleg storniert wird.
      # In diesem Fall das letzte Modifikationsdatum als Bezahldatum nehmen, oder aber das
      # Erstelldatum, wenn keine Modifikation erfolgt ist (bei Stornos z.B.).
      do_query($form, $dbh, qq|UPDATE $table SET datepaid = COALESCE(mtime::date, itime::date) WHERE id = ?|, $id);
    }

    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}


1;
