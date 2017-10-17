package SL::Helper::Object;

use strict;

sub import {
  my ($class, @args) = @_;

  my $caller = (caller)[0];

  while (@args > 1) {
    my $method = shift @args;
    my $args   = shift @args;
    die "invalid method '$method' for $class" unless $class->can($method);
    $class->$method($caller, $args);
  }
}

my %args_string_by_key = (
  none     => '',
  raw      => '(@_)',
  standard => '(@_[1..$#_])',
);

my %pre_context_by_key = (
  void   => '',
  scalar => 'my $return =',
  list   => 'my @return =',
);

my %post_context_by_key = (
  void   => 'return',
  scalar => '$return',
  list   => '@return',
);

my %known_delegate_args = map { $_ => 1 } qw(target_method args force_context class_function);

my $_ident  = '^[a-zA-Z0-9_]+$';
my $_cident = '^[a-zA-Z0-9_:]+$';

sub delegate {
  my ($class, $caller, $args) = @_;

  die 'delegate needs an array ref of parameters' if 'ARRAY' ne ref $args;
  die 'delegate needs an even number of args'     if @$args % 2;

  while (@$args > 1) {
    my $target        = shift @$args;
    my $delegate_args = shift @$args;
    my $params = 'HASH' eq ref $delegate_args->[0] ? $delegate_args->[0] : {};

    $known_delegate_args{$_} || die "unknown parameter '$_'" for keys %$params;

    die "delegate: target '$target' must match /$_cident/" if $target !~ /$_cident/;
    die "delegate: target_method '$params->{target_method}' must match /$_ident/" if $params->{target_method} && $params->{target_method} !~ /$_ident/;

    my $method_joiner = $params->{class_function} ? '::' : '->';

    for my $method (@$delegate_args) {
      next if ref $method;

      die "delegate: method name '$method' must match /$_ident/" if $method !~ /$_ident/;

      my $target_method = $params->{target_method} // $method;

      my ($pre_context, $post_context) = ('', '');
      if (exists $params->{force_context}) {
        $pre_context  = $pre_context_by_key { $params->{force_context} };
        $post_context = $post_context_by_key{ $params->{force_context} };
        die "invalid context '$params->{force_context}' to force" unless defined $pre_context && defined $post_context;
      }

      my $target_code = ucfirst($target) eq $target ? $target : "\$_[0]->$target";

      my $args_string = $args_string_by_key{ $params->{args} // 'standard' };
      die "invalid args handling '$params->{args}'" unless defined $target_code;

      eval "
        sub ${caller}::$method {
          $pre_context $target_code$method_joiner$target_method$args_string; $post_context
        }
        1;
      " or die "could not create ${caller}::$method: $@";
    }
  }
}



1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::Object - Meta Object Helper Mixin

=head1 SYNOPSIS

  use SL::Helper::Object (
    delegate => [
      $target => [ qw(method1 method2 method3 ...) ],
      $target => [ { DELEGATE_OPTIONS }, qw(method1 method2 method3 ...) ],
      ...
    ],
  );

=head1 DESCRIPTION

Sick of writing getter, setter? No because Rose::Object::MakeMethods has you covered.

Sick of writing all the rest that Rose can't do? Put it here. Functionality in this
mixin is passed as an include parameter, but are still described as functions:

=head1 FUNCTIONS

=over 4

=item C<delegate PARAMS>

Creates a method that delegates to the target. If the target string starts with
a lower case character, the generated code will be called on an object found
within the calling object by calling an accessor. This way, it is possible to
delegate to an object:

  delegate => [
    backend_obj => [ qw(save) ],
  ],

will generate:

  sub save {
    $_[0]->backend_obj->save
  }

If it starts with an upper case letter, it is assumed that it is a class name:

  delegate => [
    'Backend' => [ qw(save) ],
  ],

will generate:

  sub save {
    Backend->save
  }

Possible delegate args are:

=over 4

=item * C<target_method>

Optional. If not given, the generated method will dispatch to the same method
in the target class. If this is not possible, this can be used to overwrite it.

=item * C<args>

Controls how the arguments are passed.

If set to C<none>, the generated code will not bother passing args. This has the benefit
of not needing to splice the caller class out of @_, or to touch @_ at all for that matter.

If set to C<raw>, the generated code will pass @_ without changes. This will
result in the calling class or object being left in the arg, but is fine if the
delegator is called as a function.

If set to C<standard> (which is also the default), the original caller will be
spliced out and replaced with the new calling context.

=item * C<force_context>

Forces the given context on the delegated method. Valid arguments can be
C<void>, C<scalar>, C<list>. Default behaviour simply puts the call at the end
of the sub so that context is propagated.

=item * C<class_function>

If true, the function will be called as a class function instead of a method call.

=back

=back

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
