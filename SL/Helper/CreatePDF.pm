package SL::Helper::CreatePDF;

use strict;

use Carp;
use Cwd;
use English qw(-no_match_vars);
use File::Slurp ();
use File::Spec  ();
use File::Temp  ();
use File::Copy qw(move);
use List::MoreUtils qw(uniq);
use List::Util qw(first);
use Scalar::Util qw(blessed);
use String::ShellQuote ();

use SL::Common;
use SL::DB::Language;
use SL::DB::Printer;
use SL::MoreCommon;
use SL::System::Process;
use SL::Template;
use SL::Template::LaTeX;
use SL::X;

use Exporter 'import';
our @EXPORT_OK = qw(create_pdf merge_pdfs find_template);
our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);

sub create_pdf {
  my ($class, %params) = @_;

  return __PACKAGE__->create_parsed_file(
    format        => 'pdf',
    template_type => 'LaTeX',
    %params,
  );
}

sub create_parsed_file {
  my ($class, %params) = @_;

  my $keep_temp_files = $::lx_office_conf{debug} && $::lx_office_conf{debug}->{keep_temp_files};
  my $userspath       = SL::System::Process::exe_dir() . "/" . $::lx_office_conf{paths}->{userspath};
  my $temp_dir        = File::Temp->newdir(
    "kivitendo-print-XXXXXX",
    DIR     => $userspath,
    CLEANUP => !$keep_temp_files,
  );

  my $vars           = $params{variables} || {};
  my $form           = Form->new('');
  $form->{$_}        = $vars->{$_} for keys %{$vars};
  $form->{format}    = lc($params{format} || 'pdf');
  $form->{cwd}       = SL::System::Process::exe_dir();
  $form->{templates} = $::instance_conf->get_templates;
  $form->{IN}        = $params{template};
  $form->{tmpdir}    = $temp_dir->dirname;
  my $tmpdir         = $form->{tmpdir};
  my ($suffix)       = $params{template} =~ m{\.(.+)};

  my ($temp_fh, $tmpfile) = File::Temp::tempfile(
    'kivitendo-printXXXXXX',
    SUFFIX => ".${suffix}",
    DIR    => $form->{tmpdir},
    UNLINK => !$keep_temp_files,
  );

  $form->{tmpfile} = $tmpfile;
  (undef, undef, $form->{template_meta}{tmpfile}) = File::Spec->splitpath($tmpfile);

  my %driver_options;
  eval {
    %driver_options = _maybe_attach_zugferd_data($params{record});
  };

  if (my $e = SL::X::ZUGFeRDValidation->caught) {
    $form->cleanup;
    die $e->message;
  }

  my $parser               = SL::Template::create(
    type                   => ($params{template_type} || 'LaTeX'),
    source                 => $form->{IN},
    form                   => $form,
    myconfig               => \%::myconfig,
    userspath              => $tmpdir,
    variable_content_types => $params{variable_content_types},
    %driver_options,
  );

  my $result = $parser->parse($temp_fh);

  close $temp_fh;
  chdir $form->{cwd};

  if (!$result) {
    $form->cleanup;
    die $parser->get_error;
  }

  # SL::Template:** modify $form->{tmpfile} by removing its
  # $form->{userspath} prefix. They also store the final file's actual
  # file name in $form->{tmpfile} – but it is now relative to
  # $form->{userspath}. Other modules return the full file name…
  my ($volume, $directory, $file_name) = File::Spec->splitpath($form->{tmpfile});
  my $full_file_name                   = File::Spec->catfile($tmpdir, $file_name);
  if (($params{return} || 'content') eq 'file_name') {
    my $new_name = File::Spec->catfile($userspath, 'keep-' . $form->{tmpfile});
    rename $full_file_name, $new_name;

    $form->cleanup;

    return $new_name;
  }

  my $content = File::Slurp::read_file($full_file_name);

  $form->cleanup;

  return $content;
}

#
# Alternativen zu pdfinfo wären (aber wesentlich langamer):
#
# gs  -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile=/dev/null $filename | grep 'Processing pages'
# my (undef,undef,undef,undef,$pages)  = split / +/,$shell_out;
#
# gs  -dBATCH -dNOPAUSE -q -dNODISPLAY -c "($filename) (r) file runpdfbegin pdfpagecount = quit"
# $pages=$shell_out;
#

sub has_odd_pages {
  my ($class, $filename) = @_;
  return 0 unless -f $filename;
  my $shell_out = `pdfinfo $filename | grep 'Pages:'`;
  my ($label, $pages) = split / +/, $shell_out;
  return $pages & 1;
}

sub merge_pdfs {
  my ($class, %params) = @_;
  my $filecount = scalar(@{ $params{file_names} });

  if ($params{inp_content}) {
    return $params{inp_content} if $filecount == 0 && !$params{out_path};
  } elsif ($params{out_path}) {
    return 0 if $filecount == 0;
    if ($filecount == 1) {
      if (!rename($params{file_names}->[0], $params{out_path})) {
        # special filesystem or cross filesystem etc
        move($params{file_names}->[0], $params{out_path});
      }
      return 1;
    }
  } else {
    return '' if $filecount == 0;
    return scalar(File::Slurp::read_file($params{file_names}->[0])) if $filecount == 1;
  }

  my ($temp_fh, $temp_name) = File::Temp::tempfile(
    'kivitendo-printXXXXXX',
    SUFFIX => '.pdf',
    DIR    => $::lx_office_conf{paths}->{userspath},
    UNLINK => ($::lx_office_conf{debug} && $::lx_office_conf{debug}->{keep_temp_files})? 0 : 1,
  );
  close $temp_fh;

  my $input_names = '';
  my $hasodd      = 0;
  my $emptypage   = '';
  if ($params{bothsided}) {
    $emptypage = $::instance_conf->get_templates . '/emptyPage.pdf';
    unless (-f $emptypage) {
      $emptypage = '';
      delete $params{bothsided};
    }
  }
  if ($params{inp_content}) {
    my ($temp_fh, $inp_name) = File::Temp::tempfile(
      'kivitendo-contentXXXXXX',
      SUFFIX => '.pdf',
      DIR    => $::lx_office_conf{paths}->{userspath},
      UNLINK => ($::lx_office_conf{debug} && $::lx_office_conf{debug}->{keep_temp_files})? 0 : 1,
    );
    binmode $temp_fh;
    print $temp_fh $params{inp_content};
    close $temp_fh;
    $input_names = $inp_name . ' ';
    $hasodd = $params{bothsided} && __PACKAGE__->has_odd_pages($inp_name);
  }
  foreach (@{ $params{file_names} }) {
    $input_names .= $emptypage . ' ' if $hasodd;
    $input_names .= String::ShellQuote::shell_quote($_) . ' ';
    $hasodd = $params{bothsided} && __PACKAGE__->has_odd_pages($_);
  }
  my $exe = $::lx_office_conf{applications}->{ghostscript} || 'gs';
  my $output =
    `$exe -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=${temp_name} ${input_names} 2>&1`;

  die "Executing gs failed: $ERRNO" if !defined $output;
  die $output                       if $? != 0;

  if ($params{out_path}) {
    if (!rename($temp_name, $params{out_path})) {

      # special filesystem or cross filesystem etc
      move($temp_name, $params{out_path});
    }
    return 1;
  }
  return scalar File::Slurp::read_file($temp_name);
}

sub find_template {
  my ($class, %params) = @_;

  $params{name} or croak "Missing parameter 'name'";

  my $path                 = $::instance_conf->get_templates;
  my $extension            = $params{extension} || "tex";
  my ($printer, $language) = ('', '');

  if ($params{printer} || $params{printer_id}) {
    if ($params{printer} && !ref $params{printer}) {
      $printer = '_' . $params{printer};
    } else {
      $printer = $params{printer} || SL::DB::Printer->new(id => $params{printer_id})->load;
      $printer = $printer->template_code ? '_' . $printer->template_code : '';
    }
  }

  if ($params{language} || $params{language_id}) {
    if ($params{language} && !ref $params{language}) {
      $language = '_' . $params{language};
    } else {
      $language = $params{language} || SL::DB::Language->new(id => $params{language_id})->load;
      $language = $language->template_code ? '_' . $language->template_code : '';
    }
  }

  my @template_files = (
    $params{name} . "${language}${printer}",
    $params{name} . "${language}",
    $params{name},
    "default",
  );

  if ($params{email}) {
    unshift @template_files, (
      $params{name} . "_email${language}${printer}",
      $params{name} . "_email${language}",
    );
  }

  @template_files = map { "${_}.${extension}" } uniq grep { $_ } @template_files;

  my $template = first { -f ($path . "/$_") } @template_files;

  return wantarray ? ($template, @template_files) : $template;
}

sub _maybe_attach_zugferd_data {
  my ($record) = @_;

  return if !blessed($record)
    || !$record->can('customer')
    || !$record->customer
    || !$record->can('create_pdf_a_print_options')
    || !$record->can('create_zugferd_data')
    || !$record->customer->create_zugferd_invoices_for_this_customer;

  my $xmlfile = File::Temp->new;
  $xmlfile->print($record->create_zugferd_data);
  $xmlfile->close;

  my %driver_options = (
    pdf_a           => $record->create_pdf_a_print_options(zugferd_xmp_data => $record->create_zugferd_xmp_data),
    pdf_attachments => [
      { source       => $xmlfile,
        name         => 'factur-x.xml',
        description  => $::locale->text('Factur-X/ZUGFeRD invoice'),
        relationship => '/Alternative',
        mime_type    => 'text/xml',
      }
    ],
  );

  return %driver_options;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Helper::CreatePDF - A helper for creating PDFs from template files

=head1 SYNOPSIS

  # Retrieve a sales order from the database and create a PDF for
  # it:
  my $order               = SL::DB::Order->new(id => …)->load;
  my $print_form          = Form->new('');
  $print_form->{type}     = 'invoice';
  $print_form->{formname} = 'invoice',
  $print_form->{format}   = 'pdf',
  $print_form->{media}    = 'file';

  $order->flatten_to_form($print_form, format_amounts => 1);
  $print_form->prepare_for_printing;

  my $pdf = SL::Helper::CreatePDF->create_pdf(
    template  => 'sales_order',
    variables => $print_form,
  );

=head1 FUNCTIONS

=over 4

=item C<create_pdf %params>

Parses a LaTeX template file, creates a PDF for it and returns either
its content or its file name. The recognized parameters are the same
as the ones for L</create_parsed_file> with C<format> and
C<template_type> being pre-set.

=item C<create_parsed_file %params>

Parses a template file and returns either its content or its file
name. The recognized parameters are:

=over 2

=item * C<template> – mandatory. The template file name relative to
the users' templates directory. Must be an existing file name,
e.g. one retrieved by L</find_template>.

=item * C<variables> – optional hash reference containing variables
available to the template.

=item * C<return> – optional scalar containing either C<content> (the
default) or C<file_name>. If it is set to C<file_name> then the file
name of the temporary file containing the PDF is returned, and the
caller is responsible for deleting it. Otherwise a scalar containing
the PDF itself is returned and all temporary files have already been
deleted by L</create_pdf>.

=item * C<format> – optional, defaults to C<pdf> and determines the
output format. Can be set to C<html> for HTML output if
C<template_type> is set to C<HTML> as well.

=item * C<template_type> – optional, defaults to C<LaTeX> and
determines the template's format. Can be set to C<HTML> for HTML
output if C<format> is set to C<html> as well.

=back

=item C<find_template %params>

Searches the user's templates directory for a template file name to
use. The file names considered depend on the parameters; they can
contain a template base name and suffixes for email, language and
printers. As a fallback the name C<default.$extension> is also
considered.

The return value depends on the context. In scalar context the
template file name that matches the given parameters is returned. It's
a file name relative to the user's templates directory. If no template
file is found then C<undef> is returned.

In list context the first element is the same value as in scalar
context. Additionally a list of considered template file names is
returned.

The recognized parameters are:

=over 2

=item * C<name> – mandatory. The template's file name basis
without any additional suffix or extension, e.g. C<sales_quotation>.

=item * C<extension> – optional file name extension to use without the
dot. Defaults to C<tex>.

=item * C<email> – optional flag indicating whether or not the
template is to be sent via email. If set to true then template file
names containing C<_email> are considered as well.

=item * C<language> and C<language_id> – optional parameters
indicating the language to be used. C<language> can be either a string
containing the language code to use or an instance of
C<SL::DB::Language>. C<language_id> can contain the ID of the
C<SL::DB:Language> instance to load and use. If given template file
names containing C<_language_template_code> are considered as well.

=item * C<printer> and C<printer_id> – optional parameters indicating
the printer to be used. C<printer> can be either a string containing
the printer code to use or an instance of
C<SL::DB::Printer>. C<printer_id> can contain the ID of the
C<SL::DB:Printer> instance to load and use. If given template file
names containing C<_printer_template_code> are considered as well.

=back

=item C<merge_pdfs %params>

Merges two or more PDFs into a single PDF by using the external
application ghostscript.

Normally the function returns the contents of the resulting PDF.
if The parameter C<out_path> is set the resulting PDF is in this file
and the return value is 1 if it successful or 0 if not.

The recognized parameters are:

=over 2

=item * C<file_names> – mandatory array reference containing the file
names to merge.

=item * C<inp_content> – optional, contents of first file to merge with C<file_names>.

=item * C<out_path> – optional, returns not the merged contents but wrote him into this file

=back

Note that this function relies on the presence of the external
application ghostscript. The executable to use is configured via
kivitendo's configuration file setting C<application.ghostscript>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
