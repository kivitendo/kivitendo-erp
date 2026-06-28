package SL::Controller::AsteriskAMI;

use strict;

use SL::Helper::Flash;
use SL::Locale::String;
use SL::CTI::AsteriskManagerInterface;

use parent qw(SL::Controller::Base);

__PACKAGE__->run_before(sub { $::auth->assert('developer') },
                        only => [ qw(test_page) ]);

sub action_test_page {
  my ($self) = @_;

  my $ami = SL::CTI::AsteriskManagerInterface->new();
  $self->render('asterisk_ami/test_page', EPS => $ami->list_pjsip_endpoints);
}

1;
