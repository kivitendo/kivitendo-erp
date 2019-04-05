package SL::DB::Object::Hooks;

use strict;

use SL::X;

use parent qw(Exporter);
our @EXPORT = qw(before_load   after_load
                 before_save   after_save
                 before_delete after_delete);

my %hooks;

# Adding hooks

sub before_save {
  _add_hook('before_save', @_);
}

sub after_save {
  _add_hook('after_save', @_);
}

sub before_load {
  _add_hook('before_load', @_);
}

sub after_load {
  _add_hook('after_load', @_);
}

sub before_delete {
  _add_hook('before_delete', @_);
}

sub after_delete {
  _add_hook('after_delete', @_);
}

# Running hooks

sub run_hooks {
  my ($object, $when, @args) = @_;

  foreach my $sub (@{ ( $hooks{$when} || { })->{ ref($object) } || [ ] }) {
    my $result = ref($sub) eq 'CODE' ? $sub->($object, @args) : $object->call_sub($sub, @args);
    SL::X::DBHookError->throw(when        => $when,
                              hook        => (ref($sub) eq 'CODE' ? '<anonymous sub>' : $sub),
                              object      => $object,
                              object_type => ref($object))
      if !$result;
  }
}

# Internals

sub _add_hook {
  my ($when, $class, $sub_name, $code) = @_;
  $hooks{$when}           ||= { };
  $hooks{$when}->{$class} ||= [ ];
  push @{ $hooks{$when}->{$class} }, $sub_name;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Object::Hooks - Hooks that are run before/after a
load/save/delete

=head1 SYNOPSIS

Hooks are functions that are called before or after an object is
loaded, saved or deleted. The package defines the hooks, and those
hooks themselves are run as instance methods.

Hooks are run in the order they're added.

Hooks must return a trueish value in order to continue processing. If
any hook returns a falsish value then an exception (instance of
C<SL::X::DBHookError>) is thrown. However, C<SL::DB::Object> usually
runs the hooks from within a transaction, catches the exception and
only returns falsish in error cases.

=head1 FUNCTIONS

=over 4

=item C<before_load $sub>

=item C<before_save $sub>

=item C<before_delete $sub>

=item C<after_load $sub>

=item C<after_save $sub>

=item C<after_delete $sub>

Adds a new hook that is called at the appropriate time. C<$sub> can be
either a name of an existing sub or a code reference. If it is a code
reference then the then-current C<$self> will be passed as the first
argument.

C<before> hooks are called without arguments.

C<after> hooks are called with a single argument: the result of the
C<save> or C<delete> operation.

=item C<run_hooks $object, $when, @args>

Runs all hooks for the object C<$object> that are defined for
C<$when>. C<$when> is the same as one of the C<before_xyz> or
C<after_xyz> function names above.

An exception of C<SL::X::DBHookError> is thrown if any of the hooks
returns a falsish value.

This function is supposed to be called by L<SL::DB::Object/"load">,
L<SL::DB::Object/"save"> or L<SL::DB::Object/"delete">.

=back

=head1 EXPORTS

This mixin exports the functions L</before_load>, L</after_load>,
L</before_save>, L</after_save>, L</before_delete>, L</after_delete>.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
