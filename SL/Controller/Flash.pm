package SL::Controller::Flash;

use strict;
use parent qw(SL::Controller::Base);

use SL::Helper::Flash;

sub action_reload {
  my ($self) = @_;

  $self->js->clear_flash;
  $self->js->flash(@$_) for SL::Helper::Flash::flash_contents;
  $self->js->show_flash;
  $self->js->render;
}

sub action_test_page {
  my ($self) = @_;

  my $detail_message = qq(
This is a long detail message: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

This is a long detail message: Lorem ipsum dolor sit
amet, consectetur adipiscing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Ut enim ad
minim veniam, quis nostrud exercitation ullamco laboris nisi
ut aliquip ex ea commodo consequat. Duis aute irure dolor
in reprehenderit in voluptate velit esse cillum dolore eu
fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
proident, sunt in culpa qui officia deserunt mollit anim id
est laborum.
);

  flash('error', 'This is an error message');
  flash('warning', 'This is a warning message', $detail_message);
  flash('info', 'This is an info message');
  flash('ok', 'This is an ok message', $detail_message);

  $self->render('flash/test_page', title => 'Flash-Testpage');
}
1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Flash - Flash actions

=head1 DESCRIPTION

This controller contains actions that can be used to reload and control client
side flash messages

=head1 TEST

The function C<action_test_page> renders a functional test page with flash messages
for Error, Warning, Information and Ok. See Developer Tools, Flash-Test.

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@googlemail.comE<gt>

=cut
