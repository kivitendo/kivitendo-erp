package SL::Helper::CreatePDF;

use strict;

use Carp;
use Cwd;
use English qw(-no_match_vars);
use File::Slurp ();
use File::Temp ();
use List::MoreUtils qw(uniq);
use List::Util qw(first);
use String::ShellQuote ();

use SL::Form;
use SL::Common;
use SL::DB::Language;
use SL::DB::Printer;
use SL::MoreCommon;
use SL::Template;
use SL::Template::LaTeX;

use Exporter 'import';
our @EXPORT_OK = qw(create_pdf merge_pdfs find_template);
our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);

sub create_pdf {
  my ($class, %params) = @_;

  my $userspath       = $::lx_office_conf{paths}->{userspath};
  my $form            = Form->new('');
  $form->{format}     = 'pdf';
  $form->{cwd}        = getcwd();
  $form->{templates}  = $::instance_conf->get_templates;
  $form->{IN}         = $params{template} . '.tex';
  $form->{tmpdir}     = $form->{cwd} . '/' . $userspath;

  my $vars            = $params{variables} || {};
  $form->{$_}         = $vars->{$_} for keys %{ $vars };

  my $temp_fh;
  ($temp_fh, $form->{tmpfile}) = File::Temp::tempfile(
    'kivitendo-printXXXXXX',
    SUFFIX => '.tex',
    DIR    => $userspath,
    UNLINK => ($::lx_office_conf{debug} && $::lx_office_conf{debug}->{keep_temp_files})? 0 : 1,
  );

  my $parser = SL::Template::LaTeX->new(
    $form->{IN},
    $form,
    \%::myconfig,
    $userspath,
  );

  my $result = $parser->parse($temp_fh);

  close $temp_fh;
  chdir $form->{cwd};

  if (!$result) {
    $form->cleanup;
    die $parser->get_error;
  }

  if (($params{return} || 'content') eq 'file_name') {
    my $new_name = $userspath . '/keep-' . $form->{tmpfile};
    rename $userspath . '/' . $form->{tmpfile}, $new_name;

    $form->cleanup;

    return $new_name;
  }

  my $pdf = File::Slurp::read_file($userspath . '/' . $form->{tmpfile});

  $form->cleanup;

  return $pdf;
}

sub merge_pdfs {
  my ($class, %params) = @_;

  return scalar(File::Slurp::read_file($params{file_names}->[0])) if scalar(@{ $params{file_names} }) < 2;

  my ($temp_fh, $temp_name) = File::Temp::tempfile(
    'kivitendo-printXXXXXX',
    SUFFIX => '.pdf',
    DIR    => $::lx_office_conf{paths}->{userspath},
    UNLINK => ($::lx_office_conf{debug} && $::lx_office_conf{debug}->{keep_temp_files})? 0 : 1,
  );
  close $temp_fh;

  my $input_names = join ' ', String::ShellQuote::shell_quote(@{ $params{file_names} });
  my $exe         = $::lx_office_conf{applications}->{ghostscript} || 'gs';
  my $output      = `$exe -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=${temp_name} ${input_names} 2>&1`;

  die "Executing gs failed: $ERRNO" if !defined $output;
  die $output                       if $? != 0;

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

1;
