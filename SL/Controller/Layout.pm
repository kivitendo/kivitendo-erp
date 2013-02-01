package SL::Controller::Layout;

use strict;
use parent qw(SL::Controller::Base);

use SL::JSON ();

sub action_empty {
  my ($self) = @_;

  if ($::form->{format} eq 'json') {
    my $layout = {
      pre_content        => $::request->{layout}->pre_content,
      start_content      => $::request->{layout}->start_content,
      end_content        => $::request->{layout}->end_content,
      post_content       => $::request->{layout}->post_content,
      javascripts        => [ $::request->{layout}->javascripts ],
      javascripts_inline => [ $::request->{layout}->javascripts_inline ],
      stylesheets        => [ $::request->{layout}->stylesheets ],
      stylesheets_inline => [ $::request->{layout}->stylesheets_inline ],
    };

    $self->render(\ SL::JSON::to_json($layout), { type => 'json', process => 0 });
  }
}

1;
