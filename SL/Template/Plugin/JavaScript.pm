package SL::Template::Plugin::JavaScript;

use base qw( Template::Plugin );
use Template::Plugin;

sub new {
  my $class   = shift;
  my $context = shift;

  bless { }, $class;
}

sub escape {
  my $self = shift;
  my $text = shift;

  $text =~ s|\"|\\\"|g;

  return $text;
}

1;


