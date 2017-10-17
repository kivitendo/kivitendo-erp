package SL::BackgroundJob::SelfTest::Base;

use strict;

use Test::Builder;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => 'tester',
);

sub run {
  my ($self) = @_;
  die 'needs to be overwritten';
}

sub todo {
  0
}

sub skipped {
  0
}


sub init_tester {
  Test::Builder->new;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::BackgroundJob::SelfTests::Base - Base class for background job self tests.

=head1 SYNOPSIS

  # in self test:
  use parent qw(SL::BackgroundJob::SelfTests::Base);

  # optionally use a different tester
  sub init_tester {
    Test::Deeply->new;
  }

  # implement interface
  sub run {
    my $self = shift;

    $self->tester->plan(tests => 1);

    $self->tester->ok($value_from_database == $expected_value, 'short explanation');
  }

=head1 DESCRIPTION

This is a base class for self tests.

=head1 INTERFACE

Your class will inherit L<Rose::Object> so you can use the class building utils
from there, and won't need to worry about writing a new constructor.

Your test will be instanciated and the run method will be invoked. The output
of your tester object will be collected and processed.

=head2 THE TESTER

=over 4

=item C<tester>

=item C<init_tester>

If you don't bother overriding C<init_tester>, your test will use a
L<Test::More> object by default. Any other L<Test::Builder> object will do.

The TAP output of your builder will be collected and processed for further handling.

=back

=head1 ERROR HANDLING

If a self test module dies, it will be recorded as failed, and the bubbled
exception will be used as diagnosis.

=head1 TODO

It is currently not possible to indicate if a test skipped (indicating no actual testing was done but it wasn't an error) nor returning a todo status (indicating that the test failed, but that being ok, because it's a todo).

Stub methods "todo" and "skipped" exist, but are currently not used.

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
