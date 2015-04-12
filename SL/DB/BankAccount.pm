# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::BankAccount;

use strict;

use SL::DB::MetaSetup::BankAccount;
use SL::DB::Manager::BankAccount;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;

  if ( not $self->{chart_id} ) {
    push @errors, $::locale->text('There is no connected chart.');
  } else {
    # check whether the assigned chart is valid or is already being used by
    # another bank account (there is also a UNIQUE database constraint on
    # chart_id)

    my $chart_id = $self->chart_id;
    my $chart = SL::DB::Chart->new( id => $chart_id );
    if ( $chart->load(speculative => 1) ) {
      my $linked_bank = SL::DB::Manager::BankAccount->find_by( chart_id => $chart_id );
      if ( $linked_bank ) {
        if ( not $self->{id} or ( $self->{id} && $linked_bank->id != $self->{id} )) {
          push @errors, $::locale->text('The account #1 is already being used by bank account #2.', $chart->displayable_name, $linked_bank->{name});
        };
      };
    } else {
      push @errors, $::locale->text('The chart is not valid.');
    };
  };

  push @errors, $::locale->text('The IBAN is missing.') unless $self->{iban};

  return @errors;
}

1;
