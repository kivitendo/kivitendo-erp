#!/usr/bin/perl -w

our $master_templates;
BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');                  # '.' will be removed from @INC soon.

  # this is a default dir. may be wrong in your installation, change it then
  $master_templates = $FindBin::Bin . '/../templates/print/';
}

use strict;
use Getopt::Long;
use Pod::Usage;
use Term::ANSIColor;
use Text::Wrap;

my $exit_code = 0;
unless (eval { require Config::Std; 1 }){
  print STDERR <<EOL ;
+------------------------------------------------------------------------------+
  Perl Modul Config::Std could not be loaded.

  Debian: you may install the needed *.deb package with:
    apt-get install libconfig-std-perl

  Red Hat/Fedora/CentOS: you may install the needed *.rpm package with:
    yum install perl-Config-Std

  SUSE: you may install the needed *.rpm package with:
    zypper install perl-Config-Std

+------------------------------------------------------------------------------+
EOL

  $exit_code = 72;
}


unless (eval { require List::MoreUtils; 1 }){
  print STDERR <<EOL ;
+------------------------------------------------------------------------------+
  Perl Modul List::MoreUtils could not be loaded.

  Debian: you may install the needed *.deb package with:
    apt install liblist-moreutils-perl

  Red Hat/Fedora/CentOS: you may install the needed *.rpm package with:
    dnf install perl-List-MoreUtils


+------------------------------------------------------------------------------+
EOL

  $exit_code = 72;
}

exit $exit_code if $exit_code;

use SL::InstallationCheck;
use SL::LxOfficeConf;

my @missing_modules;
my %check;
Getopt::Long::Configure ("bundling");
GetOptions(
  "v|verbose"   => \ my $v,
  "a|all"       => \ $check{a},
  "o|optional!" => \ $check{o},
  "d|devel!"    => \ $check{d},
  "l|latex!"    => \ $check{l},
  "r|required!" => \ $check{r},
  "h|help"      => sub { pod2usage(-verbose => 2) },
  "c|color!"    => \ ( my $c = 1 ),
  "i|install-command!"  => \ my $apt,
  "s|silent"    => \ $check{s},
);

my %install_methods = (
  apt    => { key => 'debian', install => 'sudo apt install', system => "Debian, Ubuntu" },
  yum    => { key => 'fedora', install => 'sudo yum install',     system => "RHEL, Fedora, CentOS" },
  zypper => { key => 'suse',   install => 'sudo zypper install',  system => "SLES, openSUSE" },
  cpan   => { key => 'name',   install => "sudo cpan",            system => "CPAN" },
);

# if nothing is requested check "required"
my $default_run;
if (!defined $check{a}
 && !defined $check{l}
 && !defined $check{o}
 && !defined $check{d}) {
  $check{r} = 1;
  $default_run ='1';  # no parameter, therefore print a note after default run
}

if ($check{a}) {
  $check{$_} //= 1 for qw(o d l r);
}


$| = 1;

if (!SL::LxOfficeConf->read(undef, 'may fail')) {
  print_header('Could not load the config file. If you have dependencies from any features enabled in the configuration these will still show up as optional because of this. Please rerun this script after installing the dependencies needed to load the configuration.')
} else {
  SL::InstallationCheck::check_for_conditional_dependencies();
}

if ($check{r}) {
  print_header('Checking Required Modules');
  check_module($_, required => 1) for @SL::InstallationCheck::required_modules;
  check_pdfinfo();
}
if ($check{o}) {
  print_header('Checking Optional Modules');
  check_module($_, optional => 1) for @SL::InstallationCheck::optional_modules;
}
if ($check{d}) {
  print_header('Checking Developer Modules');
  check_module($_, devel => 1) for @SL::InstallationCheck::developer_modules;
}
if ($check{l}) {
  check_latex();
}

my $fail = @missing_modules;
print_header('Result');
print_line('All', $fail ? 'NOT ok' : 'OK', $fail ? 'red' : 'green');

if ($default_run && !$check{s}) {
  if (@missing_modules) {
    $apt = 1;
  print <<"EOL";

HEY! It seems there are modules MISSING! Look for the red lines with "NOT ok"
above. You'll want to fix those, I've enabled --install-command for you...
EOL
  } else {
  print <<"EOL";

Standard check done, everything is OK and up to date. Have a look at the --help
section of this script to see some more advanced checks for developer and
optional dependencies, as well as LaTeX packages you might need.
EOL
  }
}

if (@missing_modules && $apt && !$check{s}) {
  print "\nHere are some sample installation lines, choose one appropriate for your system:\n\n";
  local $Text::Wrap::separator = " \\\n";

  for (keys %install_methods) {
    my $method = $install_methods{$_};
    if (my @install_candidates = grep $_, map { $_->{$method->{key}} } @missing_modules) {
      print "$method->{system}:\n";
      print wrap("  ", "    ",  $method->{install}, @install_candidates);
      print $/;
    }
  }
}

exit !!@missing_modules;

sub check_latex {
  my ($res) = check_kpsewhich();
  print_result("Looking for LaTeX kpsewhich", $res);

  # no pdfx -> no zugferd possible
  my $ret = kpsewhich('template/print/', 'sty', 'pdfx');
  die "Cannot use pdfx. Please install this package first (debian: apt install texlive-latex-extra)"  if $ret;
  if ($res) {
    check_template_dir($_) for SL::InstallationCheck::template_dirs($master_templates);
  }
}

sub check_template_dir {
  my ($dir) = @_;
  my $path  = $master_templates . $dir;

  print_header("Checking LaTeX Dependencies for Master Templates '$dir'");
  kpsewhich($path, 'cls', $_) for SL::InstallationCheck::classes_from_latex($path, '\documentclass');

  my @sty = sort { $a cmp $b } List::MoreUtils::uniq (
    SL::InstallationCheck::classes_from_latex($path, '\usepackage'),
    qw(textcomp ulem embedfile)
  );
  kpsewhich($path, 'sty', $_) for @sty;
}

our $mastertemplate_path = './templates/print/';

sub check_kpsewhich {
  return 1 if SL::InstallationCheck::check_kpsewhich();

  print STDERR <<EOL if $v && !$check{s};
+------------------------------------------------------------------------------+
  Can't find kpsewhich, is there a proper installed LaTeX?
  On Debian you may run "aptitude install texlive-base-bin"
+------------------------------------------------------------------------------+
EOL
  return 0;
}

sub kpsewhich {
  my ($dw, $type, $package) = @_;
  $package =~ s/[^-_0-9A-Za-z]//g;
  my $type_desc = $type eq 'cls' ? 'document class' : 'package';

  eval { require String::ShellQuote; 1 } or warn "can't load String::ShellQuote" && return;
     $dw         = String::ShellQuote::shell_quote $dw;
  my $e_package  = String::ShellQuote::shell_quote $package;
  my $e_type     = String::ShellQuote::shell_quote $type;

  my $exit = system(qq|TEXINPUTS=".:$dw:" kpsewhich $e_package.$e_type > /dev/null|);
  my $res  = $exit > 0 ? 0 : 1;

  print_result("Looking for LaTeX $type_desc $package", $res);
  if (!$res) {
    print STDERR <<EOL if $v && !$check{s};
+------------------------------------------------------------------------------+
  LaTeX $type_desc $package could not be loaded.

  On Debian you may find the needed *.deb package with:
    apt-file search $package.$type

  Maybe you need to install apt-file first by:
    aptitude install apt-file && apt-file update
+------------------------------------------------------------------------------+
EOL
  }
}

sub check_pdfinfo {
  my $line = "Looking for pdfinfo executable";
  my $shell_out = `pdfinfo -v 2>&1 | grep version 2> /dev/null`;
  my ($label,$vers,$ver_string)  = split / /,$shell_out;
  if ( $label && $label eq 'pdfinfo' ) {
    chop $ver_string;
    print_line($line, $ver_string, 'green');
  } else {
    print_line($line, 'not installed','red');
    my %modinfo = ( debian => 'poppler-utils' );
    push @missing_modules, \%modinfo;

  }
}

sub check_module {
  my ($module, %role) = @_;

  my $line = "Looking for $module->{fullname}";
  $line   .= " (from $module->{dist_name})" if $module->{dist_name};
  my ($res, $ver) = SL::InstallationCheck::module_available($module->{"name"}, $module->{version});
  if ($res) {
    my $ver_string = ref $ver && $ver->can('numify') ? $ver->numify : $ver ? $ver : 'no version';
    print_line($line, $ver_string, 'green');
  } else {
    print_result($line, $res);
  }


  return if $res;

  push @missing_modules, $module;

  my $needed_text =
      $role{optional} ? 'It is OPTIONAL for kivitendo but RECOMMENDED for improved functionality.'
    : $role{required} ? 'It is NEEDED by kivitendo and must be installed.'
    : $role{devel}    ? 'It is OPTIONAL for kivitendo and only useful for developers.'
    :                   'It is not listed as a dependency yet. Please tell this the developers.';

  my @source_texts = module_source_texts($module);
  local $" = $/;
  print STDERR <<EOL if $v && !$check{s};
+------------------------------------------------------------------------------+
  $module->{fullname} could not be loaded.

  This module is either too old or not available on your system.
  $needed_text

  Here are some ideas how to get it:

@source_texts
+------------------------------------------------------------------------------+
EOL
}

sub module_source_texts {
  my ($module) = @_;
  my @texts;
  for my $key (keys %install_methods) {
    my $method = $install_methods{$key};
    push @texts, <<"EOL" if $module->{$method->{key}};
  - Using $method->{system} you can install it with $key:
      $method->{install} $module->{$method->{key}}
EOL
  }
  push @texts, <<EOL if $module->{url};
  - You can download it from this URL and install it manually:
      $module->{url}
EOL

  return @texts;
}

sub mycolor {
  return $_[0] unless $c;
  return colored(@_);
}

sub print_result {
  my ($test, $exit) = @_;
  if ($exit) {
    print_line($test, 'ok', 'green');
  } else {
    print_line($test, 'NOT ok', 'red');
  }
}

sub print_line {
  my ($text, $res, $color) = @_;
  return if $check{s};
  print $text, " ", ('.' x (78 - length($text) - length($res))), " ", mycolor($res, $color), $/;
}

sub print_header {
  return if $check{s};
  print $/;
  print "$_[0]:", $/;
}

1;

__END__

=encoding UTF-8

=head1 NAME

scripts/installation_check.pl - check kivitendo dependencies

=head1 SYNOPSIS

  scripts/installation_check.pl [OPTION]

=head1 DESCRIPTION

Check dependencys. List all perl modules needed by kivitendo, probes for them,
and warns if one is not available.  List all LaTeX document classes and
packages needed by kivitendo master templates, probes for them, and warns if
one is not available.


=head1 OPTIONS

=over 4

=item C<-a, --all>

Probe for all perl modules and all LaTeX master templates.

=item C<-c, --color>

Color output. Default on.

=item C<--no-color>

No color output. Helpful to avoid terminal escape problems.

=item C<-d, --devel>

Probe for perl developer dependencies. (Used for console  and tags file)

=item C<--no-devel>

Don't probe for perl developer dependencies. (Useful in combination with --all)

=item C<-h, --help>

Display this help.

=item C<-o, --optional>

Probe for optional modules.

=item C<--no-optional>

Don't probe for optional perl modules. (Useful in combination with --all)

=item C<-r, --required>

Probe for required perl modules (default).

=item C<--no-required>

Don't probe for required perl modules. (Useful in combination with --all)

=item C<-l. --latex>

Probe for LaTeX documentclasses and packages in master templates.

=item C<--no-latex>

Don't probe for LaTeX document classes and packages in master templates. (Useful in combination with --all)

=item C<-v. --verbose>

Print additional info for missing dependencies

=item C<-i, --install-command>

Tries to generate installation commands for the most common package managers.
Note that these lists can be slightly off, but it should still save you a lot
of typing.

=back

=head1 BUGS, CAVEATS and TODO

=over 4

=item *

Fedora packages not listed yet.

=item *

Not possible yet to generate a combined cpan/apt-get string to install all needed.

=item *

Not able to handle devel cpan modules yet.

=item *

Version requirements not fully tested yet.

=back

=head1 AUTHOR

  Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>
  Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>
  Wulf Coulmann E<lt>wulf@coulmann.deE<gt>

=cut
