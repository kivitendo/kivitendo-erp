#!/usr/bin/perl

# this version of locales processes not only all required .pl files
# but also all parse_html_templated files.

use utf8;
use strict;

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');
}

use Carp;
use Cwd;
use Data::Dumper;
use English;
use File::Slurp qw(slurp);
use FileHandle;
use Getopt::Long;
use IO::Dir;
use IPC::Run qw();
use List::MoreUtils qw(apply);
use List::Util qw(first);
use Pod::Usage;
use SL::DBUpgrade2;
use SL::System::Process;
use SL::YAML;

$OUTPUT_AUTOFLUSH = 1;

my $opt_v  = 0;
my $opt_c  = 0;
my $opt_f  = 0;
my $debug  = 0;
my $run_for_test = 0;

parse_args();

my $locale;
my $basedir      = "../..";
my $locales_dir  = ".";
my $bindir       = "$basedir/bin/mozilla";
my @progdirs     = ( "$basedir/SL" );
my @menufiles    = glob("${basedir}/menus/*/*");
my @webpages     = qw(webpages mobile_webpages design40_webpages);
my @javascript_dirs = ($basedir .'/js', map { $basedir .'/templates/' . $_ } @webpages);
my $javascript_output_dir = $basedir .'/js';
my $submitsearch = qr/type\s*=\s*[\"\']?submit/i;
our $self        = {};
our $missing     = {};
our @lost        = ();

my %ignore_unused_templates = (
  map { $_ => 1 } qw(ct/testpage.html oe/periodic_invoices_email.txt part/testpage.html t/render.html t/render.js task_server/failure_notification_email.txt
                     failed_background_jobs_report/email.txt presenter/items_list/items_list.txt)
);

my %outfiles_normal       = map {$_ => "${locales_dir}/${_}"} qw(all missing lost);
$outfiles_normal{js}      = $javascript_output_dir .'/locale/'. $locale . '.js';
my %outfiles_for_test     = map {$_ => "${locales_dir}/${_}_for_test"} qw(all missing lost);
$outfiles_for_test{js}    = $javascript_output_dir .'/locale/'. $locale . '_for_test' . '.js';
my $outfiles              = $run_for_test ? \%outfiles_for_test
                                          : \%outfiles_normal;

my (%referenced_html_files, %locale, %htmllocale, %alllocales, %cached, %submit, %jslocale);
my ($ALL_HEADER, $MISSING_HEADER, $LOST_HEADER);

init();

sub find_files {
  my ($top_dir_name) = @_;

  my (@files, $finder);

  $finder = sub {
    my ($dir_name) = @_;

    tie my %dir_h, 'IO::Dir', $dir_name;

    push @files,   grep { -f } map { "${dir_name}/${_}" }                       keys %dir_h;
    my @sub_dirs = grep { -d } map { "${dir_name}/${_}" } grep { ! m/^\.\.?$/ } keys %dir_h;

    $finder->($_) for @sub_dirs;
  };

  $finder->($top_dir_name);

  return @files;
}

sub merge_texts {
# overwrite existing entries with the ones from 'missing'
  $self->{texts}->{$_} = $missing->{$_} for grep { $missing->{$_} } keys %alllocales;

  # try to set missing entries from lost ones
  my %lost_by_text = map { ($_->{text} => $_->{translation}) } @lost;
  $self->{texts}->{$_} = $lost_by_text{$_} for grep { !$self->{texts}{$_} } keys %alllocales;
}

my @bindir_files = find_files($bindir);
my @progfiles    = map { m:^(.+)/([^/]+)$:; [ $2, $1 ]  } grep { /\.pl$/ && !/_custom/ } @bindir_files;
my @customfiles  = grep /_custom/, @bindir_files;

push @progfiles, map { m:^(.+)/([^/]+)$:; [ $2, $1 ] } grep { /\.pm$/ } map { find_files($_) } @progdirs;

my %dir_h;

my @dbplfiles;
foreach my $sub_dir ("Pg-upgrade2", "Pg-upgrade2-auth") {
  my $dir = "$basedir/sql/$sub_dir";
  tie %dir_h, 'IO::Dir', $dir;
  push @dbplfiles, map { [ $_, $dir ] } grep { /\.pl$/ } keys %dir_h;
}

# slurp the translations in
if (-f "$locales_dir/all") {
  require "$locales_dir/all";
}
# load custom translation (more_texts)
for my $file (glob("${locales_dir}/more/*")) {
  if (open my $in, "<", "$file") {
    local $/ = undef;
    my $code = <$in>;
    eval($code);
    close($in);
    $self->{more_texts_temp}{$_} = $self->{more_texts}{$_} for keys %{ $self->{more_texts} };
  }
}
$self->{more_texts} = delete $self->{more_texts_temp};

if (-f "$locales_dir/missing") {
  require "$locales_dir/missing" ;
  unlink "$locales_dir/missing";
}
if (-f "$locales_dir/lost") {
  require "$locales_dir/lost";
  unlink "$locales_dir/lost";
}

my %old_texts = %{ $self->{texts} || {} };

handle_file(@{ $_ })       for @progfiles;
handle_file(@{ $_ })       for @dbplfiles;
scanmenu($_)               for @menufiles;
scandbupgrades();

for my $file_name (grep { /\.(?:js|html)$/i } map({find_files($_)} @javascript_dirs)) {
  scan_javascript_file($file_name);
}

# merge entries to translate with entries from files 'missing' and 'lost'
merge_texts();

# Generate "all" without translations in more_texts.
# But keep the ones which are in both old_texts (texts) and more_texts,
# because this are ones which are overwritten in more_texts for custom usage.
my %to_keep;
$to_keep{$_} = 1 for grep { !!$self->{more_texts}{$_} } keys %old_texts;
my @new_all  = grep { $to_keep{$_} || !$self->{more_texts}{$_} } sort keys %alllocales;

generate_file(
  file      => $outfiles->{all},
  header    => $ALL_HEADER,
  data_name => '$self->{texts}',
  data_sub  => sub { _print_line($_, $self->{texts}{$_}, @_) for @new_all },
);

open(my $js_file, '>:encoding(utf8)', $outfiles->{js}) || die;
print $js_file 'namespace("kivi").setupLocale({';
my $first_entry = 1;
for my $key (sort(keys(%jslocale))) {
  my $trans = $self->{more_texts}{$key} // $self->{texts}{$key};
  print $js_file ((!$first_entry ? ',' : '') ."\n". _double_quote($key) .':'. _double_quote($trans));
  $first_entry = 0;
}
print $js_file ("\n");
print $js_file ('});'."\n");
close($js_file);

  foreach my $text (keys %$missing) {
    if ($locale{$text} || $htmllocale{$text}) {
      unless ($self->{texts}{$text}) {
        $self->{texts}{$text} = $missing->{$text};
      }
    }
  }


# calc and generate missing
# don't add missing ones if we have a translation in more_texts
my @new_missing = grep { !$self->{more_texts}{$_} && !$self->{texts}{$_} } sort keys %alllocales;

if (@new_missing) {
  if ($opt_c) {
    my %existing_lc = map { (lc $_ => $_) } grep { $self->{texts}->{$_} } keys %{ $self->{texts} };
    foreach my $entry (@new_missing) {
      my $other = $existing_lc{lc $entry};
      print "W: No entry for '${entry}' exists, but there is one with different case: '${other}'\n" if $other;
    }
  }

  if ($opt_f) {
    for my $string (@new_missing) {
      print "new string '$string' in files:\n";
      print join "",
        map   { "  $_\n"                  }
        apply { s{^(?:\.\./)+}{}          }
        grep  { $cached{$_}{all}{$string} }
        keys  %cached;
    }
  }

  generate_file(
    file      => $outfiles->{missing},
    header    => $MISSING_HEADER,
    data_name => '$missing',
    data_sub  => sub { _print_line($_, '', @_) for @new_missing },
  );
}

# calc and generate lost
while (my ($text, $translation) = each %old_texts) {
  next if ($alllocales{$text});
  push @lost, { 'text' => $text, 'translation' => $translation };
}

if (scalar @lost) {
  splice @lost, 0, (scalar @lost - 50) if (scalar @lost > 50);
  generate_file(
    file      => $outfiles->{lost},
    header    => $LOST_HEADER,
    delim     => '()',
    data_name => '@lost',
    data_sub  => sub {
      _print_line($_->{text}, $_->{translation}, @_, template => "  { 'text' => %s, 'translation' => %s },\n") for @lost;
    },
  );
}

my $trlanguage = slurp("$locales_dir/LANGUAGE");
chomp $trlanguage;

search_unused_htmlfiles() if $opt_c;

my $count  = scalar keys %alllocales;
my $notext = scalar @new_missing;
my $per    = sprintf("%.1f", ($count - $notext) / $count * 100);
print "\n$trlanguage - ${per}%";
print " - $notext/$count missing" if $notext;
print "\n";

if ($run_for_test) {
  print "\nrun for unit test:\n";

  my $not_up_to_date = 0;

  for my $type (qw(all js)) {
    my ($out, $err);
    my   @cmd = qw(diff -q);
    push @cmd,  $outfiles_normal{$type};
    push @cmd,  $outfiles_for_test{$type};
    IPC::Run::run \@cmd, \undef, \$out, \$err;
    my $err_code = $? >> 8;

    if ($err_code > 1) {
      unlink for values %outfiles_for_test;
      die "diff failed: " . ($err_code) . ": " . $err;
    }

    if ($err_code == 1) {
      print "not up to date: " . $outfiles_normal{$type} . " \n";
      $not_up_to_date = 1;
    }
  }
  unlink for values %outfiles_for_test;

  if ($not_up_to_date) {
    exit 1;
  } else {
    print "up to date.\n";
    exit 0;
  }
}

exit;

# eom

sub init {
  $ALL_HEADER = <<EOL;
# These are all the texts to build the translations files.
# The file has the form of 'english text'  => 'foreign text',
# you can add the translation in this file or in the 'missing' file
# run locales.pl from this directory to rebuild the translation files
EOL
  $MISSING_HEADER = <<EOL;
# add the missing texts and run locales.pl to rebuild
EOL
  $LOST_HEADER  = <<EOL;
# The last 50 text strings, that have been removed.
# This file has been auto-generated by locales.pl. Please don't edit!
EOL
}

sub parse_args {
  my ($help, $man);

  my ($opt_no_c, $ignore_for_compatiblity);

  GetOptions(
    'check-files'     => \$ignore_for_compatiblity,
    'no-check-files'  => \$opt_no_c,
    'verbose'         => \$opt_v,
    'filenames'       => \$opt_f,
    'help'            => \$help,
    'man'             => \$man,
    'debug'           => \$debug,
    'run-for-test'    => \$run_for_test
  );

  $opt_c = !$opt_no_c;

  if ($help) {
    pod2usage(1);
    exit 0;
  }

  if ($man) {
    pod2usage(-exitstatus => 0, -verbose => 2);
    exit 0;
  }

  if (@ARGV) {
    my $arg = shift @ARGV;
    my $ok  = 0;
    foreach my $dir ("../locale/$arg", "locale/$arg", "../$arg", $arg) {
      next unless -d $dir && -f "$dir/all" && -f "$dir/LANGUAGE";

      $locale = $arg;

      $ok = chdir $dir;
      last;
    }

    if (!$ok) {
      print "The locale directory '$arg' could not be found.\n";
      exit 1;
    }

  } elsif (!-f 'all' || !-f 'LANGUAGE') {
    print "locales.pl was not called from a locale/* subdirectory,\n"
      .   "and no locale directory name was given.\n";
    exit 1;
  }

  $locale ||=  (grep { $_ } split m:/:, getcwd())[-1];
  $locale   =~ s/\.+$//;
}

sub handle_file {
  my ($file, $dir) = @_;
  print "\n$file" if $opt_v;
  %locale = ();
  %submit = ();

  &scanfile("$dir/$file");

  # scan custom_{module}.pl or {login}_{module}.pl files
  foreach my $customfile (@customfiles) {
    if ($customfile =~ /_$file/) {
      if (-f "$dir/$customfile") {
        &scanfile("$dir/$customfile");
      }
    }
  }

  $file =~ s/\.pl//;
}

sub extract_text_between_parenthesis {
  my ($fh, $line) = @_;
  my ($inside_string, $pos, $text, $quote_next) = (undef, 0, "", 0);

  while (1) {
    if (length($line) <= $pos) {
      $line = <$fh>;
      return ($text, "") unless ($line);
      $pos = 0;
    }

    my $cur_char = substr($line, $pos, 1);

    if (!$inside_string) {
      if ((length($line) >= ($pos + 3)) && (substr($line, $pos, 2)) eq "qq") {
        $inside_string = substr($line, $pos + 2, 1);
        $pos += 2;

      } elsif ((length($line) >= ($pos + 2)) &&
               (substr($line, $pos, 1) eq "q")) {
        $inside_string = substr($line, $pos + 1, 1);
        $pos++;

      } elsif (($cur_char eq '"') || ($cur_char eq '\'')) {
        $inside_string = $cur_char;

      } elsif (($cur_char eq ")") || ($cur_char eq ',')) {
        return ($text, substr($line, $pos + 1));
      }

    } else {
      if ($quote_next) {
        $text .= '\\' unless $cur_char eq "'";
        $text .= $cur_char;
        $quote_next = 0;

      } elsif ($cur_char eq '\\') {
        $quote_next = 1;

      } elsif ($cur_char eq $inside_string) {
        undef($inside_string);

      } else {
        $text .= $cur_char;

      }
    }
    $pos++;
  }
}

sub scanfile {
  my $file = shift;
  my $dont_include_subs = shift;
  my $scanned_files = shift;

  # sanitize file
  $file =~ s=/+=/=g;

  $scanned_files = {} unless ($scanned_files);
  return if ($scanned_files->{$file});
  $scanned_files->{$file} = 1;

  if (!defined $cached{$file}) {

    return unless (-f "$file");

    my $fh = new FileHandle;
    open $fh, '<:encoding(utf8)', $file or die "$! : $file";

    my ($is_submit, $line_no, $sub_line_no) = (0, 0, 0);

    while (<$fh>) {
      last if /^\s*__END__/;

      $line_no++;

      # is this another file
      if (/require\s+\W.*\.pl/) {
        my $newfile = $&;
        $newfile =~ s/require\s+\W//;
        $newfile =~ s|bin/mozilla||;
         $cached{$file}{scan}{"$bindir/$newfile"} = 1;
      } elsif (/use\s+SL::([\w:]*)/) {
        my $module =  $1;
        $module    =~ s|::|/|g;
        $cached{$file}{scannosubs}{"../../SL/${module}.pm"} = 1;
      }

      # Some calls to render() are split over multiple lines. Deal
      # with that.
      while (/(?:parse_html_template2?|render)\s*\( *$/) {
        $_ .= <$fh>;
        chomp;
      }

      # is this a template call?
      if (/(?:parse_html_template2?|render)\s*\(\s*[\"\']([\w\/]+)\s*[\"\']/) {
        my $new_file_name = $1;
        if (/parse_html_template2/) {
          print "E: " . strip_base($file) . " is still using 'parse_html_template2' for $new_file_name.html.\n";
        }

        my $found_one = 0;
        for my $space (@webpages) {
          for my $ext (qw(html js json)) {
            my $new_file = "$basedir/templates/$space/$new_file_name.$ext";
            if (-f $new_file) {
              $cached{$file}{scanh}{$new_file} = 1;
              print "." if $opt_v;
              $found_one = 1;
            }
          }
        }

        if ($opt_c && !$found_one) {
          print "W: missing HTML template: $new_file_name.{html,json,js} (referenced from " . strip_base($file) . ")\n";
        }
      }

      my $rc = 1;

      while ($rc) {
        if (/Locale/) {
          unless (/^use /) {
            my ($null, $country) = split(/,/);
            $country =~ s/^ +[\"\']//;
            $country =~ s/[\"\'].*//;
          }
        }

        my $postmatch = "";

        # is it a submit button before $locale->
        if (/$submitsearch/) {
          $postmatch = "$'";
          if ($` !~ /locale->text/) {
            $is_submit   = 1;
            $sub_line_no = $line_no;
          }
        }

        my $found;
        if (/ (?: locale->text | \b t8 ) \b .*? \(/x) {
          $found     = 1;
          $postmatch = "$'";
        }

        if ($found) {
          my $string;
          ($string, $_) = extract_text_between_parenthesis($fh, $postmatch);
          $postmatch = $_;

          # if there is no $ in the string record it
          unless (($string =~ /\$\D.*/) || ("" eq $string)) {

            # this guarantees one instance of string
            $cached{$file}{locale}{$string} = 1;

            # this one is for all the locales
            $cached{$file}{all}{$string} = 1;

            # is it a submit button before $locale->
            if ($is_submit) {
              $cached{$file}{submit}{$string} = 1;
            }
          }
        } elsif ($postmatch =~ />/) {
          $is_submit = 0;
        }

        # exit loop if there are no more locales on this line
        ($rc) = ($postmatch =~ /locale->text | \b t8/x);

        if (   ($postmatch =~ />/)
            || (!$found && ($sub_line_no != $line_no) && />/)) {
          $is_submit = 0;
        }
      }
    }

    close($fh);

  }

  $alllocales{$_} = 1             for keys %{$cached{$file}{all}};
  $locale{$_}     = 1             for keys %{$cached{$file}{locale}};
  $submit{$_}     = 1             for keys %{$cached{$file}{submit}};

  scanfile($_, 0, $scanned_files) for keys %{$cached{$file}{scan}};
  scanfile($_, 1, $scanned_files) for keys %{$cached{$file}{scannosubs}};
  scanhtmlfile($_)                for keys %{$cached{$file}{scanh}};

  $referenced_html_files{$_} = 1  for keys %{$cached{$file}{scanh}};
}

sub scanmenu {
  my $file = shift;

  my $menu = SL::YAML::LoadFile($file);

  for my $node (@$menu) {
    # possible for override files
    next unless exists $node->{name};

    $locale{$node->{name}}     = 1;
    $alllocales{$node->{name}} = 1;
    $cached{$file}{all}{$node->{name}} = 1;
  }
}

sub scandbupgrades {
  # we only need to do this for auth atm, because only auth scripts can include new rights, which are translateable
  my $auth = 1;

  my $dbu = SL::DBUpgrade2->new(auth => $auth, path => SL::System::Process->exe_dir . '/sql/Pg-upgrade2-auth');

  for my $upgrade ($dbu->sort_dbupdate_controls) {
    for my $string (@{ $upgrade->{locales} || [] }) {
      $locale{$string}     = 1;
      $alllocales{$string} = 1;
    $cached{$upgrade->{tag}}{all}{$string} = 1;
    }
  }
}

sub unescape_template_string {
  my $in =  "$_[0]";
  $in    =~ s/\\(.)/$1/g;
  return $in;
}

sub scanhtmlfile {
  my ($file) = @_;

  return if defined $cached{$file};

  my $template_space = $file =~ m{templates/(\w+)/} ? $1 : 'webpages';

  my %plugins = ( 'loaded' => { }, 'needed' => { } );

  my $fh;
  if (!open($fh, '<:encoding(utf8)', $file)) {
    print "E: template file '$file' not found\n";
    return;
  }

  my $copying  = 0;
  my $issubmit = 0;
  my $text     = "";
  while (my $line = <$fh>) {
    chomp($line);

    while ($line =~ m/\[\%[^\w]*use[^\w]+(\w+)[^\w]*?\%\]/gi) {
      $plugins{loaded}->{$1} = 1;
    }

    while ($line =~ m/\[\%[^\w]*(\w+)\.\w+\(/g) {
      my $plugin = $1;
      $plugins{needed}->{$plugin} = 1 if (first { $_ eq $plugin } qw(HTML LxERP JavaScript JSON L P));
    }

    $plugins{needed}->{T8} = 1 if $line =~ m/\[\%.*\|.*\$T8/;

    while ($line =~ m/(?:             # Start von Variante 1: LxERP.t8('...'); ohne darumliegende [% ... %]-Tags
                        (LxERP\.t8)\( #   LxERP.t8(                             ::Parameter $1::
                        ([\'\"])      #   Anfang des zu übersetzenden Strings   ::Parameter $2::
                        (.*?)         #   Der zu übersetzende String            ::Parameter $3::
                        (?<!\\)\2     #   Ende des zu übersetzenden Strings
                      |               # Start von Variante 2: [% '...' | $T8 %]
                        \[\%          #   Template-Start-Tag
                        [\-~#]?       #   Whitespace-Unterdrückung
                        \s*           #   Optional beliebig viele Whitespace
                        ([\'\"])      #   Anfang des zu übersetzenden Strings   ::Parameter $4::
                        (.*?)         #   Der zu übersetzende String            ::Parameter $5::
                        (?<!\\)\4     #   Ende des zu übersetzenden Strings
                        \s*\|\s*      #   Pipe-Zeichen mit optionalen Whitespace davor und danach
                        (\$T8)        #   Filteraufruf                          ::Parameter $6::
                        .*?           #   Optionale Argumente für den Filter
                        \s*           #   Whitespaces
                        [\-~#]?       #   Whitespace-Unterdrückung
                        \%\]          #   Template-Ende-Tag
                      )
                     /ix) {
      my $module = $1 || $6;
      my $string = $3 || $5;
      print "Found filter >>>$string<<<\n" if $debug;
      substr $line, $LAST_MATCH_START[1], $LAST_MATCH_END[0] - $LAST_MATCH_START[0], '';

      $string                         = unescape_template_string($string);
      $cached{$file}{all}{$string}    = 1;
      $cached{$file}{html}{$string}   = 1;
      $cached{$file}{submit}{$string} = 1 if $PREMATCH =~ /$submitsearch/;
      $plugins{needed}->{T8}          = 1 if $module eq '$T8';
      $plugins{needed}->{LxERP}       = 1 if $module eq 'LxERP.t8';
    }

    while ($line =~ m/\[\%          # Template-Start-Tag
                      [\-~#]*       # Whitespace-Unterdrückung
                      \s*           # Optional beliebig viele Whitespace
                      (?:           # Die erkannten Template-Direktiven
                        PROCESS
                      |
                        INCLUDE
                      )
                      \s+           # Mindestens ein Whitespace
                      [\'\"]?       # Anfang des Dateinamens
                      ([^\s]+)      # Beliebig viele Nicht-Whitespaces -- Dateiname
                      \.(html|js)   # Endung ".html" oder ".js", ansonsten kann es der Name eines Blocks sein
                     /ix) {
      my $new_file_name = "$basedir/templates/$template_space/$1.$2";
      $cached{$file}{scanh}{$new_file_name} = 1;
      substr $line, $LAST_MATCH_START[1], $LAST_MATCH_END[0] - $LAST_MATCH_START[0], '';
    }
  }

  close($fh);

  foreach my $plugin (keys %{ $plugins{needed} }) {
    next if ($plugins{loaded}->{$plugin});
    print "E: " . strip_base($file) . " requires the Template plugin '$plugin', but is not loaded with '[\% USE $plugin \%]'.\n";
  }

  # copy back into global arrays
  $alllocales{$_} = 1            for keys %{$cached{$file}{all}};
  $locale{$_}     = 1            for keys %{$cached{$file}{html}};
  $submit{$_}     = 1            for keys %{$cached{$file}{submit}};

  scanhtmlfile($_)               for keys %{$cached{$file}{scanh}};

  $referenced_html_files{$_} = 1 for keys %{$cached{$file}{scanh}};
}

sub scan_javascript_file {
  my ($file) = @_;

  open(my $fh, '<:encoding(utf8)', $file) || die('can not open file: '. $file);

  while( my $line = readline($fh) ) {
    while( $line =~ m/
                    \bk(?:ivi)?.t8
                    \s*
                    \(
                    \s*
                    ([\'\"])
                    (.*?)
                    (?<!\\)\1
                    /ixg )
    {
      my $text = unescape_template_string($2);

      $jslocale{$text} = 1;
      $alllocales{$text} = 1;
    }
  }

  close($fh);
}
sub search_unused_htmlfiles {
  my @unscanned_dirs = map {  '../../templates/' . $_ } @webpages;

  while (scalar @unscanned_dirs) {
    my $dir = shift @unscanned_dirs;

    foreach my $entry (<$dir/*>) {
      if (-d $entry) {
        push @unscanned_dirs, $entry;

      } elsif (!$ignore_unused_templates{strip_base($entry)} && -f $entry && !$referenced_html_files{$entry}) {
        print "W: unused HTML template: " . strip_base($entry) . "\n";

      }
    }
  }
}

sub strip_base {
  my $s =  "$_[0]";             # Create a copy of the string.

  $s    =~ s|^../../||;
  $s    =~ s|templates/\w+/||;

  return $s;
}

sub _single_quote {
  my $val = shift;
  $val =~ s/(\'|\\$)/\\$1/g;
  return  "'" . $val .  "'";
}

sub _double_quote {
  my $val = shift;
  $val =~ s/(\"|\\$)/\\$1/g;
  return  '"'. $val .'"';
}

sub _print_line {
  my $key      = _single_quote(shift);
  my $text     = _single_quote(shift);
  my %params   = @_;
  my $template = $params{template} || qq|  %-29s => %s,\n|;
  my $fh       = $params{fh}       || croak 'need filehandle in _print_line';

  print $fh sprintf $template, $key, $text;
}

sub generate_file {
  my %params = @_;

  my $file      = $params{file}   || croak 'need filename in generate_file';
  my $header    = $params{header};
  my $lines     = $params{data_sub};
  my $data_name = $params{data_name};
  my @delim     = split //, ($params{delim} || '{}');

  open my $fh, '>:encoding(utf8)', $file or die "$! : $file";

  print $fh "#!/usr/bin/perl\n# -*- coding: utf-8; -*-\n# vim: fenc=utf-8\n\nuse utf8;\n\n";
  print $fh $header, "\n" if $header;
  print $fh "$data_name = $delim[0]\n" if $data_name;

  $lines->(fh => $fh);

  print $fh qq|$delim[1];\n\n1;\n|;
  close $fh;
}

__END__

=head1 NAME

locales.pl - Collect strings for translation in kivitendo

=head1 SYNOPSIS

locales.pl [options] lang_code

 Options:
  -c, --check-files      Run extended checks on HTML files (default)
  -n, --no-check-files   Do not run extended checks on HTML files
  -r, --run-for-test     Do (almost) nothing but return a state if all files are up to date
  -f, --filenames        Show the filenames where new strings where found
  -v, --verbose          Be more verbose
  -h, --help             Show this help

=head1 OPTIONS

=over 8

=item B<-c>, B<--check-files>

Run extended checks on the usage of templates. This can be used to
discover HTML templates that are never used as well as the usage of
non-existing HTML templates. This is enabled by default.

=item B<-n>, B<--no-check-files>

Do not run extended checks on the usage of templates. See
C<--no-check-files>.

=item B<-r>, B<--run-for-test>

Do (almost) nothing but return a state if all files are up to date.
Locales files will be generated with different names and compared to
the original files.
If the files differ an exit status of '1' is returned, '0' otherwise.
The generated files will be deleted afterwards.

=item B<-v>, B<--verbose>

Be more verbose.

=back

=head1 DESCRIPTION

This script collects strings from Perl files, the menu files and
HTML templates and puts them into the file "all" for translation.

=cut
