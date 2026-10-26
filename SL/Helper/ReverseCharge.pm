package SL::Helper::ReverseCharge;

use strict;

use Carp;

use SL::DB;
use SL::DB::ApGl;
use SL::DB::Chart;
use SL::DB::GLTransaction;
use SL::DB::RecordLink;
use SL::DB::Tax;

sub delete_bookings {
  my ($class, $ap_id) = @_;

  return unless $ap_id;

  SL::DB->client->with_transaction(sub {
    my @gl_ids = map { $_->gl_id } @{ SL::DB::Manager::ApGl->get_all(where => [ ap_id => $ap_id ]) };
    return 1 unless @gl_ids;

    # only the links to these transactions, other links to gl may have been set by hand
    SL::DB::Manager::RecordLink->   delete_all(where => [ from_table => 'ap', from_id => $ap_id, to_table => 'gl', to_id => \@gl_ids ]);
    SL::DB::Manager::ApGl->         delete_all(where => [ ap_id => $ap_id ]);
    SL::DB::Manager::GLTransaction->delete_all(where => [ id    => \@gl_ids ]);
    1;
  }) or die SL::DB->client->error;
}

sub post_bookings {
  my ($class, %params) = @_;

  croak "ap_id missing"     unless $params{ap_id};
  croak "transdate missing" unless $params{transdate};

  # all or nothing: a failure must not lose the previous bookings
  SL::DB->client->with_transaction(sub {
    $class->delete_bookings($params{ap_id});

    foreach my $entry (@{ $params{entries} || [] }) {
      my $tax       = $entry->{tax};
      my $taxamount = $::form->round_amount($entry->{taxamount}, 2);

      croak "tax missing"                    unless ref $tax eq 'SL::DB::Tax';
      croak "tax is not a reverse charge tax" unless $tax->reverse_charge_chart_id;
      next                                    unless $taxamount;

      my $input_tax_chart  = SL::DB::Manager::Chart->find_by(id => $tax->chart_id);
      my $output_tax_chart = SL::DB::Manager::Chart->find_by(id => $tax->reverse_charge_chart_id);

      croak("No such Chart ID " . $tax->chart_id)                unless ref $input_tax_chart  eq 'SL::DB::Chart';
      croak("No such Chart ID " . $tax->reverse_charge_chart_id) unless ref $output_tax_chart eq 'SL::DB::Chart';

      my $source         = "Reverse Charge for " . ($params{reference} // '');
      my $gl_transaction = SL::DB::GLTransaction->new(
        employee_id   => $params{employee_id},
        transdate     => $params{transdate},
        description   => $params{description} || $params{reference},
        reference     => $params{reference},
        department_id => $params{department_id} || undef,
        imported      => 0,
        taxincluded   => 0,
      )->add_chart_booking(
        chart  => $taxamount > 0 ? $input_tax_chart : $output_tax_chart,
        debit  => abs($taxamount),
        source => $source,
        tax_id => 0,
      )->add_chart_booking(
        chart  => $taxamount > 0 ? $output_tax_chart : $input_tax_chart,
        credit => abs($taxamount),
        source => $source,
        tax_id => 0,
      )->post;

      SL::DB::ApGl->new(ap_id => $params{ap_id}, gl_id => $gl_transaction->id)->save;
      SL::DB::RecordLink->new(
        from_table => 'ap',
        from_id    => $params{ap_id},
        to_table   => 'gl',
        to_id      => $gl_transaction->id,
      )->save;
    }
    1;
  }) or die SL::DB->client->error;
}

sub taxes_by_id {
  my ($class) = @_;

  return { map { ($_->id => $_) } @{ SL::DB::Manager::Tax->get_all(where => [ '!reverse_charge_chart_id' => undef ]) } };
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Helper::ReverseCharge - Book input and output tax for reverse charge
taxes of purchase records

=head1 SYNOPSIS

  use SL::Helper::ReverseCharge;

  # after posting a purchase record
  SL::Helper::ReverseCharge->post_bookings(
    ap_id       => $ap_id,
    transdate   => $transdate,
    reference   => $invnumber,
    description => $notes,
    employee_id => $employee_id,
    entries     => [ { tax => $tax, taxamount => 19 } ],
  );

  # before deleting a purchase record
  SL::Helper::ReverseCharge->delete_bookings($ap_id);

=head1 OVERVIEW

Taxes with a C<reverse_charge_chart_id> (e.g. tax keys 18, 19 and 94 in
SKR03/SKR04) are used for purchases where the buyer owes the tax:
intra-community acquisitions and services according to §13b UStG. The
vendor gets the net amount only. Input tax and output tax are booked in
a separate general ledger transaction, which is linked to the purchase
record via C<ap_gl> and C<record_links>. The DATEV export skips this
transaction because DATEV calculates the taxes from the tax key of the
expense booking.

=head1 FUNCTIONS

=over 4

=item C<post_bookings %params>

Deletes all reverse charge bookings of the purchase record C<ap_id> and
creates one general ledger transaction per entry in C<entries>. Each
entry is a hash reference with the reverse charge tax C<tax> and the
amount C<taxamount>, positive for an invoice and negative for a credit
note or a cancellation. A positive amount is debited to the tax's
chart (input tax) and credited to its C<reverse_charge_chart_id>
(output tax). Entries rounded to zero are skipped.

Further parameters: C<transdate> (mandatory), C<reference> (the
invoice number), C<description>, C<employee_id>, C<department_id>.

Runs in a transaction (or the caller's transaction): if an entry fails,
the previous bookings stay unchanged.

=item C<delete_bookings $ap_id>

Deletes all reverse charge general ledger transactions of the purchase
record C<$ap_id> together with their links.

=item C<taxes_by_id>

Returns a hash reference of all reverse charge taxes by their ID.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Max Wessendorf E<lt>m.wessendorf@ukd.deE<gt>

=cut
