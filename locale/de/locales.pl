#!/usr/bin/perl

# -n do not include custom_ scripts

# this version of locles processes not only all required .pl files
# but also all parse_html_templated files.

use POSIX;
use FileHandle;
use Data::Dumper;

$basedir  = "../..";
$bindir   = "$basedir/bin/mozilla";
$menufile = "menu.ini";
$submitsearch = qr/type\s*=\s*["']?submit/i;

foreach $item (@ARGV) {
  $item =~ s/-//g;
  $arg{$item} = 1;
}

opendir DIR, "$bindir" or die "$!";
@progfiles = grep { /\.pl$/ && !/(_|^\.)/ } readdir DIR;
seekdir DIR, 0;
@customfiles = grep /_/, readdir DIR;
closedir DIR;

# put customized files into @customfiles
@customfiles = () if ($arg{n});

if ($arg{n}) {
  @menufiles = ($menufile);
} else {
  opendir DIR, "$basedir" or die "$!";
  @menufiles = grep { /.*?_$menufile$/ } readdir DIR;
  closedir DIR;
  unshift @menufiles, $menufile;
}

# slurp the translations in
if (-f 'all') {
  require "all";
}

# Read HTML templates.
#%htmllocale = ();
#@htmltemplates = <../../templates/webpages/*/*_master.html>;
#foreach $file (@htmltemplates) {
#  scanhtmlfile($file);
#}

foreach $file (@progfiles) {

  %locale = ();
  %submit = ();
  %subrt  = ();

  &scanfile("$bindir/$file");

  # scan custom_{module}.pl or {login}_{module}.pl files
  foreach $customfile (@customfiles) {
    if ($customfile =~ /_$file/) {
      if (-f "$bindir/$customfile") {
        &scanfile("$bindir/$customfile");
      }
    }
  }

  # if this is the menu.pl file
  if ($file eq 'menu.pl') {
    foreach $item (@menufiles) {
      &scanmenu("$basedir/$item");
    }
  }

  if ($file eq 'menunew.pl') {
    foreach $item (@menufiles) {
      &scanmenu("$basedir/$item");
    }
  }

  $file =~ s/\.pl//;

  eval { require 'missing'; };
  unlink 'missing';

  foreach $text (keys %$missing) {
    if ($locale{$text} || $htmllocale{$text}) {
      unless ($self{texts}{$text}) {
        $self{texts}{$text} = $missing->{$text};
      }
    }
  }

  open FH, ">$file" or die "$! : $file";

  print FH q|$self{texts} = {
|;

  foreach $key (sort keys %locale) {
    if ($self{texts}{$key}) {
      $text = $self{texts}{$key};
    } else {
      $text = $key;
    }
    $text =~ s/'/\\'/g;
    $text =~ s/\\$/\\\\/;

    $keytext = $key;
    $keytext =~ s/'/\\'/g;
    $keytext =~ s/\\$/\\\\/;

    print FH qq|  '$keytext'|
      . (' ' x (27 - length($keytext)))
      . qq| => '$text',\n|;
  }

  print FH q|};

$self{subs} = {
|;

  foreach $key (sort keys %subrt) {
    $text = $key;
    $text =~ s/'/\\'/g;
    $text =~ s/\\$/\\\\/;
    print FH qq|  '$text'| . (' ' x (27 - length($text))) . qq| => '$text',\n|;
  }

  foreach $key (sort keys %submit) {
    $text = ($self{texts}{$key}) ? $self{texts}{$key} : $key;
    $text =~ s/'/\\'/g;
    $text =~ s/\\$/\\\\/;

    $english_sub = $key;
    $english_sub =~ s/'/\\'/g;
    $english_sub =~ s/\\$/\\\\/;
    $english_sub = lc $key;

    $translated_sub = lc $text;
    $english_sub    =~ s/( |-|,)/_/g;
    $translated_sub =~ s/( |-|,)/_/g;
    print FH qq|  '$translated_sub'|
      . (' ' x (27 - length($translated_sub)))
      . qq| => '$english_sub',\n|;
  }

  print FH q|};

1;
|;

  close FH;
}

foreach $file (@htmltemplates) {
  converthtmlfile($file);
}

# now print out all

open FH, ">all" or die "$! : all";

print FH q|# These are all the texts to build the translations files.
# The file has the form of 'english text'  => 'foreign text',
# you can add the translation in this file or in the 'missing' file
# run locales.pl from this directory to rebuild the translation files

$self{texts} = {
|;

foreach $key (sort keys %alllocales) {
  $text = $self{texts}{$key};

  $count++;

  $text =~ s/'/\\'/g;
  $text =~ s/\\$/\\\\/;
  $key  =~ s/'/\\'/g;
  $key  =~ s/\\$/\\\\/;

  unless ($text) {
    $notext++;
    push @missing, $key;
  }

  print FH qq|  '$key'| . (' ' x (27 - length($key))) . qq| => '$text',\n|;

}

print FH q|};

1;
|;

close FH;

if (@missing) {
  open FH, ">missing" or die "$! : missing";

  print FH q|# add the missing texts and run locales.pl to rebuild

$missing = {
|;

  foreach $text (@missing) {
    print FH qq|  '$text'| . (' ' x (27 - length($text))) . qq| => '',\n|;
  }

  print FH q|};

1;
|;

  close FH;

}

open(FH, "LANGUAGE");
@language = <FH>;
close(FH);
$trlanguage = $language[0];
chomp $trlanguage;

$per = sprintf("%.1f", ($count - $notext) / $count * 100);
print "\n$trlanguage - ${per}%\n";

exit;

# eom

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

      } elsif ($cur_char eq ")") {
        return ($text, substr($line, $pos + 1));
      }

    } else {
      if ($quote_next) {
        $text .= $cur_char;
        $quote_next = 0;

      } elsif ($cur_char eq '\\') {
        $text .= $cur_char;
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

  return unless (-f "$file");

  my $fh = new FileHandle;
  open $fh, "$file" or die "$! : $file";

  my ($is_submit, $line_no, $sub_line_no) = (0, 0, 0);

  while (<$fh>) {
    $line_no++;

    # is this another file
    if (/require\s+\W.*\.pl/) {
      my $newfile = $&;
      $newfile =~ s/require\s+\W//;
      $newfile =~ s/\$form->{path}\///;
      &scanfile("$bindir/$newfile");
    }

    # is this a template call?
    if (/parse_html_template\s*\(\s*["']([\w\/]+)/) {
      my $newfile = "$basedir/templates/webpages/$1_master.html";
      if (-f $newfile) {
        &scanhtmlfile($newfile);
        &converthtmlfile($newfile);
      }
    }

    # is this a sub ?
    if (/^sub /) {
      ($null, $subrt) = split / +/;
      $subrt{$subrt} = 1;
      next;
    }

    my $rc = 1;

    while ($rc) {
      if (/Locale/) {
        unless (/^use /) {
          my ($null, $country) = split /,/;
          $country =~ s/^ +[\"\']//;
          $country =~ s/[\"\'].*//;
        }
      }

      my $postmatch = "";

      # is it a submit button before $locale->
      if (/$submitsearch/) {
        $postmatch = $';
        if ($` !~ /\$locale->text/) {
          $is_submit   = 1;
          $sub_line_no = $line_no;
        }
      }

      my ($found) = /\$locale->text.*?\(/;
      my $postmatch = $';

      if ($found) {
        my $string;
        ($string, $_) = extract_text_between_parenthesis($fh, $postmatch);
        $postmatch = $_;

        # if there is no $ in the string record it
        unless (($string =~ /\$\D.*/) || ("" eq $string)) {

          # this guarantees one instance of string
          $locale{$string} = 1;

          # this one is for all the locales
          $alllocales{$string} = 1;

          # is it a submit button before $locale->
          if ($is_submit) {
            $submit{$string} = 1;
          }
        }
      } elsif ($postmatch =~ />/) {
        $is_submit = 0;
      }

      # exit loop if there are no more locales on this line
      ($rc) = ($postmatch =~ /\$locale->text/);

      # strip text
      s/^.*?\$locale->text.*?\)//;

      if (   ($postmatch =~ />/)
          || (!$found && ($sub_line_no != $line_no) && />/)) {
        $is_submit = 0;
      }
    }
  }

  close($fh);

}

sub scanmenu {
  my $file = shift;

  my $fh = new FileHandle;
  open $fh, "$file" or die "$! : $file";

  my @a = grep /^\[/, <$fh>;
  close($fh);

  # strip []
  grep { s/(\[|\])//g } @a;

  foreach my $item (@a) {
    @b = split /--/, $item;
    foreach $string (@b) {
      chomp $string;
      $locale{$string}     = 1;
      $alllocales{$string} = 1;
    }
  }

}

sub scanhtmlfile {
  local *IN;

  open(IN, $_[0]) || die $_[0];

  my $copying = 0;
  my $issubmit = 0;
  my $text = "";
  while (my $line = <IN>) {
    chomp($line);

    while ("" ne $line) {
      if (!$copying) {
        if ($line =~ m|<translate>|i) {
          my $eom = $+[0];
          if ($` =~ /$submitsearch/) {
            $issubmit = 1
          }
          substr($line, 0, $eom) = "";
          $copying = 1;
        } else {
          $line = "";
        }

      } else {
        if ($line =~ m|</translate>|i) {
          $text .= $`;
          substr($line, 0, $+[0]) = "";
          
          $copying = 0; 
          if ($issubmit) {
            $submit{$text} = 1;
            $issubmit = 0;
          }
          $alllocales{$text} = 1;
          $htmllocale{$text} = 1;
          $text = "";

        } else {
          $text .= $line;
          $line = "";
        }
      }
    }
  }

  close(IN);
}

sub converthtmlfile {
  local *IN;
  local *OUT;

  my $file = shift;

  open(IN, $file) || die;

  my $langcode = (split("/", getcwd()))[-1];
  $file =~ s/_master.html$/_${langcode}.html/;

  open(OUT, ">$file") || die;

  my $copying = 0;
  my $text = "";
  while (my $line = <IN>) {
    chomp($line);
    if ("" eq $line) {
      print(OUT "\n");
      next;
    }

    while ("" ne $line) {
      if (!$copying) {
        if ($line =~ m|<translate>|i) {
          print(OUT $`);
          substr($line, 0, $+[0]) = "";
          $copying = 1;
          print(OUT "\n") if ("" eq $line);

        } else {
          print(OUT "${line}\n");
          $line = "";
        }

      } else {
        if ($line =~ m|</translate>|i) {
          $text .= $`;
          substr($line, 0, $+[0]) = "";
          $copying = 0;
          $alllocales{$text} = 1;
          $htmllocale{$text} = 1;
          print(OUT $self{"texts"}{$text});
          print(OUT "\n") if ("" eq $line);
          $text = "";

        } else {
          $text .= $line;
          $line = "";
        }
      }
    }
  }

  close(IN);
  close(OUT);
}
