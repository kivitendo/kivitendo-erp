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

  for my $field (qw(page per_page sort_by)) {
    for my $arg (@args) {
      next unless defined $arg->{$field};
      $final_args->{$field} //= $arg->{$field};
    }
  }

  return %$final_args;
}

sub is_enabled {
  my ($self) = @_;
  return !$self->disabled;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Helper::GetModels::Base - base class for GetModels plugins

=head1 SYNOPSIS

  package SL::Controller::Helper::Getmodels::...;
  use parent 'SL::Controller::Helper::Getmodels::Base'

  sub read_params { ... }

  sub finalize { ... }

=head1 DESCRIPTION

This is a base class for plugins of the GetModels framework for controllers. It
provides some common ground.

=head1 FUNCTIONS

=over 4

=item read_params

This will be called when GetModels transitions to C<Init> phase.
Make sure that you don't need anything from source after that.

=item finalize

This will be called when GetModels transitions to C<finalized> phase. Make sure
that no internal state or configuration gets changed after this.

=item merge_args

Common function to merge the output of various callbacks.

=back

=head1 BUGS AND CAVEATS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut

