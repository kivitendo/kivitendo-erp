package SL::Template::XML;

use parent qw(SL::Template::HTML);

use strict;

sub new {
  #evtl auskommentieren
  my $type = shift;

  return $type->SUPER::new(@_);
}

sub format_string {
  my ($self, $variable) = @_;
  my $form = $self->{"form"};

  $variable = $main::locale->quote_special_chars('Template/XML', $variable);

  # Allow no markup to be converted into the output format
  my @markup_replace = ('b', 'i', 's', 'u', 'sub', 'sup');

  foreach my $key (@markup_replace) {
    $variable =~ s/\&lt;(\/?)${key}\&gt;//g;
  }

  return $variable;
}

sub get_mime_type() {
  my ($self) = @_;

  return "text";

}

sub uses_temp_file {
  # tempfile needet for XML Output
  return 1;
}

1;
