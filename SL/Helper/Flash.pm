package SL::Helper::Flash;

use strict;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(flash render_flash);

sub flash {
  my $category = shift;
  $category    = 'info' if $category eq 'information';

  $::form->{FLASH}                ||= { };
  $::form->{FLASH}->{ $category } ||= [ ];
  push @{ $::form->{FLASH}->{ $category } }, @_;
}

sub render_flash {
  return $::form->parse_html_template('common/flash');
}

1;
