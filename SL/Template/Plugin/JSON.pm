package SL::Template::Plugin::JSON;

use strict;
use JSON ();
use Carp qw(croak);
use base qw(Template::Plugin);

our $VERSION = "0.06";

sub new {
  my ($class, $context, $args) = @_;

  my $self = bless {context => $context, json_args => $args }, $class;

  $context->define_vmethod($_, json => sub { $self->json(@_) }) for qw(hash list scalar);

  return $self;
}

sub json_converter {
  my ($self, %params) = @_;

  if (!$self->{json}) {
    $self->{json} = JSON->new->allow_nonref(1)->convert_blessed(1);

    my $args = $self->{json_args};

    for my $method (keys %$args) {
      if ( $self->{json}->can($method) ) {
        $self->{json}->$method( $args->{$method} );
      }
    }
  }

  return $self->{json};
}

sub json {
  my ($self, $value) = @_;

  $self->json_converter->encode($value);
}

sub json_decode {
  my ( $self, $value ) = @_;

  $self->json_converter->decode($value);
}

1;

__END__
