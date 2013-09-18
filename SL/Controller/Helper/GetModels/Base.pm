package SL::Controller::Helper::GetModels::Base;

use strict;
use parent 'Rose::Object';
use Scalar::Util qw(weaken);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(get_models disabled finalized) ],
);

# phase stubs
sub read_params { die 'implement me' }

sub finalize { die 'implement me' }

sub set_get_models {
  $_[0]->get_models($_[1]);

  weaken($_[1]);
}

sub merge_args {
  my ($self, @args) = @_;
  my $final_args = { };

  for my $field (qw(query with_objects)) {
    $final_args->{$field} = [ map { @{ $_->{$field} || [] } } @args ];
  }

  for my $field (qw(page per_page sort_by sort_dir )) {
    for my $arg (@args) {
      next unless defined $_->{$field};
      $final_args->{$field} //= $_->{$field};
    }
  }

  return %$final_args;
}

sub is_enabled {
  my ($self) = @_;
  return !$self->disabled;
}

1;
