package SL::DB::Helper::PDF_A;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(create_pdf_a_print_options);

sub create_pdf_a_print_options {
  my ($self) = @_;

  require SL::DB::Language;

  my $language_code = $self->can('language_id') && $self->language_id ? SL::DB::Language->load_cached($self->language_id)->template_code : undef;
  $language_code  ||= 'de';
  my $pdf_language  = $language_code =~ m{deutsch|german|^de$}i   ? 'de-DE'
                    : $language_code =~ m{englisch|english|^en$}i ? 'en-US'
                    :                                               '';
  my $author        = do {
    no warnings 'once';
    $::instance_conf->get_company
  };

  return {
    version   => '3b',
    meta_data => {
      title    => $self->displayable_name,
      author   => $author,
      language => $pdf_language,
    },
  };
}

1;
