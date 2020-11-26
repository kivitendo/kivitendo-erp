package SL::DB::Helper::PDF_A;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(create_pdf_a_print_options);

use Carp;
use Template;

sub _create_xmp_data {
  my ($self, %params) = @_;

  my $template = Template->new({
    INTERPOLATE  => 0,
    EVAL_PERL    => 0,
    ABSOLUTE     => 1,
    PLUGIN_BASE  => 'SL::Template::Plugin',
    ENCODING     => 'utf8',
  }) || croak;

  my $output = '';
  $template->process(SL::System::Process::exe_dir() . '/templates/pdf/pdf_a_metadata.xmp', \%params, \$output) || croak $template->error;

  return $output;
}

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

  my $timestamp =  DateTime->now_local->strftime('%Y-%m-%dT%H:%M:%S%z');
  $timestamp    =~ s{(..)$}{:$1};

  return {
    version                => '3b',
    xmp                    => _create_xmp_data(
      $self,
      pdf_a_version        => '3',
      pdf_a_conformance    => 'B',
      producer             => 'pdfTeX',
      timestamp            => $timestamp, # 2019-11-05T15:26:20+01:00
      meta_data            => {
        title              => $self->displayable_name,
        author             => $author,
        language           => $pdf_language,
      },
      zugferd              => {
        conformance_level  => 'EXTENDED',
        document_file_name => 'factur-x.xml',
        document_type      => 'INVOICE',
        version            => '1.0',
      },
    ),
  };
}

1;
