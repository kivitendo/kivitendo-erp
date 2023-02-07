package SL::Controller::GenericPresenterTest;

use strict;

use parent qw(SL::Controller::Base);

sub action_show {
  my ($self) = @_;

  $self->render(
    'presenter/test_page',
    defaults => {
      from_date => '1.2.2022',
      to_date => '3.4.2022',
      dialog => {
          year => '2022',                 # numeric year
          type => 'monthly',              # the radio button selection:
                                          # 'yearly', 'monthly', 'quarterly'
          quarter => 'B',                 # the quarter as a letter code:
                                          # 'A', 'B', 'C', 'D' A being 1st quarter etc.
          month => '6',                   # numeric month
      }
    }
  );
}

1;
