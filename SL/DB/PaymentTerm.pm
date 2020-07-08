package SL::DB::PaymentTerm;

use strict;

use List::Util qw(max);

use SL::DB::MetaSetup::PaymentTerm;
use SL::DB::Manager::PaymentTerm;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::TranslatedAttributes;

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.')      if !$self->description;
  push @errors, $::locale->text('The long description is missing.') if !$self->description_long;

  return @errors;
}

sub calc_date {
  my ($self, %params) = @_;

  my $reference_date  = $params{reference_date} || DateTime->today_local;
  $reference_date     = DateTime->from_kivitendo($reference_date) unless ref($reference_date) eq 'DateTime';

  if (!$self->auto_calculation) {
    my $due_date = $params{due_date} || $reference_date;
    $due_date    = DateTime->from_kivitendo($due_date) unless ref($due_date) eq 'DateTime';

    return max $due_date, $reference_date;
  }

  my $terms           = ($params{terms} // 'net') eq 'discount' ? 'terms_skonto' : 'terms_netto';
  my $date            = $reference_date->clone->add(days => $self->$terms);

  my $dow             = $date->day_of_week;
  $date               = $date->add(days => 8 - $dow) if $dow > 5;

  return $date;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::PaymentTerm - Rose model for the payment_terms table

=head1 SYNOPSIS

  my $terms             = SL::DB::PaymentTerm->new(id => $::form->{payment_id})->load;
  my $due_date_net      = $terms->calc_date(terms => 'net');      # uses terms_netto
  my $due_date_discount = $terms->calc_date(terms => 'discount'); # uses terms_skonto

  # Calculate due date taking the existing invoice date and the due
  # date entered by the user into account:
  my $due_date = $terms->calc_date(
    reference_date => $::form->{invdate},
    due_date       => $::form->{duedate},
  );

=head1 FUNCTIONS

=over 4

=item C<calc_date [%params]>

Calculates and returns a due date as an instance of L<DateTime> by
adding one of C<$self>'s terms fields if automatic calculation is on;
otherwise returns the currently-set due date (which must be provided)
or the reference date, whichever is later.

Note that for automatic calculation the resulting date will be the
following Monday if the result falls on a weekend.

C<%params> can contain the following parameters:

=over 4

=item C<reference_date>

The reference date from which the due date will be calculated. Can be
either an instance of L<DateTime> or a scalar in which case the scalar
is parsed via L<DateTime/from_kivitendo>.

Defaults to the current date if unset.

=item C<due_date>

A currently set due date. If automatic calculation is off then this
date will be returned if it is provided and greater than or equal to
the C<reference_date>. Otherwise the reference date will be returned.

=item C<terms>

Can be either C<net> or C<discount>. For C<net> the number of days to
add to the reference date are C<$self-E<gt>terms_netto>. For
C<discount> C<$self-E<gt>terms_skonto> is used.

Defaults to C<net> if unset.

=back

=item C<validate>

Validates before saving and returns an array of human-readable error
messages in case of an error.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
