package SL::Template::Plugin::T8;

use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );

my $locale = undef;

sub init {
    my $self = shift;

    $locale ||= Locale->new($main::myconfig{countrycode}, 'all');

    # first arg can specify filter name
    $self->install_filter($self->{ _ARGS }->[0] || 'T8');

    return $self;
}

sub filter {
    my ($self, $text, $args) = @_;
    return $locale->text($text, @{ $args || [] });
}

return 'SL::Template::Plugin::T8';
