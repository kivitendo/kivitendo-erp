# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::OrderStatus;

use strict;

use SL::DB::MetaSetup::OrderStatus;
use SL::DB::Manager::OrderStatus;

use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The name is missing.') if !$self->name;

  my $not_unique_count = SL::DB::Manager::OrderStatus->get_all_count(where => ['!id' => $self->id,
                                                                               name  => $self->name]);
  push @errors, $::locale->text('The name is not unique.') if $not_unique_count;

  return @errors;
}

1;
