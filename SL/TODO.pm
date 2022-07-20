# TODO list helper functions

package TODO;

use SL::DBUtils;
use SL::DB;

use strict;

sub get_user_config {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  $form->error('Need params: id or login') if (!$params{id} && !$params{login});

  if ($params{login}) {
    ($params{id}) = selectfirst_array_query($form, $dbh, qq|SELECT id FROM employee WHERE login = ?|, $params{login});

    if (!$params{id}) {
      $main::lxdebug->leave_sub();
      return ();
    }

  } else {
    ($params{login}) = selectfirst_array_query($form, $dbh, qq|SELECT login FROM employee WHERE id = ?|, conv_i($params{id}));
  }

  my $cfg = selectfirst_hashref_query($form, $dbh, qq|SELECT * FROM todo_user_config WHERE employee_id = ?|, conv_i($params{id}));

  if (!$cfg) {
    # Standard configuration: enable all

    $cfg = { map { $_ => 1 } qw(show_after_login show_follow_ups show_follow_ups_login show_overdue_sales_quotations show_overdue_sales_quotations_login) };
  }

  if (! $main::auth->check_right($params{login}, 'sales_quotation_edit | sales_quotation_view | request_quotation_edit | request_quotation_view')) {
    map { delete $cfg->{$_} } qw(show_overdue_sales_quotations show_overdue_sales_quotations_login);
  }

  $main::lxdebug->leave_sub();

  return %{ $cfg };
}

sub save_user_config {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(login));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  SL::DB->client->with_transaction(sub {
    my $dbh      = $params{dbh} || SL::DB->client->dbh;

    my $query    = qq|SELECT id FROM employee WHERE login = ?|;

    my ($id)     = selectfirst_array_query($form, $dbh, $query, $params{login});

    if (!$id) {
      $main::lxdebug->leave_sub();
      return;
    }

    $query =
      qq|SELECT show_after_login
         FROM todo_user_config
         WHERE employee_id = ?|;

    if (! selectfirst_hashref_query($form, $dbh, $query, $id)) {
      do_query($form, $dbh, qq|INSERT INTO todo_user_config (employee_id) VALUES (?)|, $id);
    }

    $query =
      qq|UPDATE todo_user_config SET
           show_after_login = ?,
           show_follow_ups = ?,
           show_follow_ups_login = ?,
           show_overdue_sales_quotations = ?,
           show_overdue_sales_quotations_login = ?

         WHERE employee_id = ?|;

    my @values = map { $params{$_} ? 't' : 'f' } qw(show_after_login show_follow_ups show_follow_ups_login show_overdue_sales_quotations show_overdue_sales_quotations_login);
    push @values, $id;

    do_query($form, $dbh, $query, @values);
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

1;
