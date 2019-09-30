package SL::DB::Helper::AccountingPeriod;

use strict;
use SL::Locale::String qw(t8);

use parent qw(Exporter);
use SL::DBUtils;
our @EXPORT = qw(get_balance_starting_date get_balance_startdate_method_options);

use Carp;

sub get_balance_startdate_method_options {
  [
    { title => t8("After closed period"),                       value => "closed_to"                   },
    { title => t8("Start of year"),                             value => "start_of_year"               },
    { title => t8("All transactions"),                          value => "all_transactions"            },
    { title => t8("Last opening balance or all transactions"),  value => "last_ob_or_all_transactions" },
    { title => t8("Last opening balance or start of year"),     value => "last_ob_or_start_of_year"    },
  ]
}

sub get_balance_starting_date {
  my ($self, $asofdate, $startdate_method) = @_;

  $asofdate         ||= DateTime->today_local;
  $startdate_method ||= $::instance_conf->get_balance_startdate_method;

  unless ( ref $asofdate eq 'DateTime' ) {
    $asofdate = $::locale->parse_date_to_object($asofdate);
  };

  my $dbh = $::form->get_standard_dbh;


  # We could use the following objects to determine the starting date for
  # calculating the balance from asofdate (the reference date for the balance):
  # * start_of_year - 1.1., no deviating fiscal year supported
  # * closed_to - all transactions since the books were last closed
  # * last_ob - all transactions since last opening balance transaction (usually 1.1.)
  # * mindate - all transactions in database

  my $start_of_year = $asofdate->clone();
  $start_of_year->set_day(1);
  $start_of_year->set_month(1);

  # closedto assumes that we only close the books at the end of a fiscal year,
  # never during the fiscal year. If this assumption is valid closedto should
  # also work for deviating fiscal years. But as the trial balance (SuSa)
  # doesn't yet deal with deviating fiscal years, and it is useful to also close
  # the books after a month has been exported via DATEV, this method of
  # determining the starting date isn't recommended and is not the default.

  my $closedto = $::instance_conf->get_closedto;
  if ($closedto) {
    $closedto = $::locale->parse_date_to_object($closedto);
    $closedto->subtract(years => 1) while ($asofdate - $closedto)->is_negative;
    $closedto->add(days => 1);
  };

  my ($query, $startdate, $last_ob, $mindate);
  $query = qq|select max(transdate) from acc_trans where ob_transaction is true and transdate <= ?|;
  ($last_ob) = selectrow_query($::form, $dbh, $query, $::locale->format_date(\%::myconfig, $asofdate));
  $last_ob = $::locale->parse_date_to_object($last_ob) if $last_ob;

  $query = qq|select min(transdate) from acc_trans|;
  ($mindate) = selectrow_query($::form, $dbh, $query);
  $mindate = $::locale->parse_date_to_object($mindate);

  # the default method is to use all transactions ($mindate)

  if ( $startdate_method eq 'closed_to' and $closedto ) {
    # if no closedto is configured use default
    return $::locale->format_date(\%::myconfig, $closedto);

  } elsif ( $startdate_method eq 'start_of_year' ) {

    return $::locale->format_date(\%::myconfig, $start_of_year);

  } elsif ( $startdate_method eq 'all_transactions' ) {

    return $::locale->format_date(\%::myconfig, $mindate);

  } elsif ( $startdate_method eq 'last_ob_or_all_transactions' and $last_ob ) {
    # use default if there are no ob transactions

    return $::locale->format_date(\%::myconfig, $last_ob);

  } elsif ( $startdate_method eq 'last_ob_or_start_of_year' ) {

    if ( $last_ob ) {
      return $::locale->format_date(\%::myconfig, $last_ob);
    } else {
      return $::locale->format_date(\%::myconfig, $start_of_year);
    };

  } else {
    # default action, also used for closedto and last_ob_or_all_transactions if
    # there are no valid dates

    return $::locale->format_date(\%::myconfig, $mindate);
  };

};

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::AccountingPeriod - Helper functions for calculating dates relative to the financial year

=head1 FUNCTIONS

=over 4

=item C<get_balance_startdate_method_options>

Returns an arrayref of translated options for determining the startdate of a
balance period or the yearend period. To be used as the options for a dropdown.

=item C<get_balance_starting_date $date $startdate_method>

Given a date this method calculates and returns the starting date of the
financial period relative to that date, according to the configured
balance_startdate_method in the client configuration. The returned date is
locale-formatted and can be used for SQL queries.

If $date isn't a DateTime object a date string is assumed, which then gets
date-parsed.

If no argument is passed the current day is assumed as default.

If no startdate method is passed, the default method from defaults is used.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>information@kivitendo-premium.deE<gt>

=cut
