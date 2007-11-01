#!/usr/bin/perl

# Upgrade von Vorlagen

die("This script cannot be run from the command line.") unless ($main::form);

use File::Copy;

sub update_templates {
  local *IN;

  if (!open(IN, "users/members")) {
    die($dbup_locale->text("Could not open the file users/members."));
  }

  my %all_template_dirs;
  while (<IN>) {
    chomp();
    $all_template_dirs{$1} = 1 if (/^templates=(.*)/);
  }
  close(IN);

  my @new_templates;

  foreach my $raw (@_) {
    $raw =~ /^.*?-(.*)/;
    push(@new_templates, { "source" => "templates/$raw",
                           "destination" => $1 });
  }

  my @warnings;

  foreach my $dir (keys(%all_template_dirs)) {
    foreach my $template (@new_templates) {
      my $destination = $dir . "/" . $template->{"destination"};
      if (-f $destination) {
        if (!rename($destination, $destination . ".bak")) {
          push(@warnings, sprintf($dbup_locale->text("Could not rename %s to %s. Reason: %s"),
                                  $destination, $destination . ".bak", $!));
        }
      }
      if (!copy($template->{"source"}, $destination)) {
        push(@warnings, sprintf($dbup_locale->text("Could not copy %s to %s. Reason: %s"),
                                $template->{"source"}, $destination . ".bak", $!));
      }
    }
  }

  if (@warnings) {
    @warnings = map(+{ "message" => $_ }, @warnings);
    print($form->parse_html_template("dbupgrade/update_templates_warnings", { "WARNINGS" => \@warnings }));
  }

  return 1;
}

sub do_update {
  update_templates("German-winston.xml",
                   "German-taxbird.txb",
                   "German-credit_note.tex",
                   "German-zahlungserinnerung.tex");
}

return do_update();
