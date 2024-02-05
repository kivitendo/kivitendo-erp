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

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Flash - Flash actions

=head1 DESCRIPTION

This controller contains actions that can be used to reload and control client
side flash messages

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>sven.schoeling@opendynamic.deE<gt>

=cut
