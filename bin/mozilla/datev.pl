#=====================================================================
# Lx-Office ERP
# Copyright (c) 2004
#
#  Author: Philip Reetz
#   Email: p.reetz@linet-services.de
#     Web: http://www.lx-office.org
#
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# Datev export module
#
#======================================================================

use POSIX qw(strftime getcwd);
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);

use SL::Common;
use SL::DATEV;

use strict;

1;

# end of main

require "bin/mozilla/common.pl";

sub continue { call_sub($main::form->{"nextsub"}); }

sub export {
  $::lxdebug->enter_sub;
  $::auth->assert('datev_export');

  DATEV->get_datev_stamm(\%::myconfig, $::form);
  $::form->header;
  print $::form->parse_html_template('datev/export');

  $::lxdebug->leave_sub;
}

sub export2 {
  $::lxdebug->enter_sub;
  $::auth->assert('datev_export');

  if ($::form->{exporttype} == 0) {
    export_bewegungsdaten();
  } else {
    export_stammdaten();
  }
  $::lxdebug->leave_sub;
}

sub export_bewegungsdaten {
  $::lxdebug->enter_sub;
  $::auth->assert('datev_export');

  $::form->header;
  print $::form->parse_html_template('datev/export_bewegungsdaten');

  $::lxdebug->leave_sub;
}

sub export_stammdaten {
  $::lxdebug->enter_sub;
  $::auth->assert('datev_export');

  $::form->header;
  print $::form->parse_html_template('datev/export_stammdaten');

  $::lxdebug->leave_sub;
}

sub export3 {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('datev_export');

  DATEV::clean_temporary_directories();

  DATEV->save_datev_stamm(\%myconfig, \%$form);

  my $link = "datev.pl?action=download&download_token=";

  if ($form->{kne}) {
    my $result = DATEV->kne_export(\%myconfig, \%$form);
    if ($result && @{ $result->{filenames} }) {
      $link .= Q($result->{download_token});

      print(qq|<br><b>| . $locale->text('KNE-Export erfolgreich!') . qq|</b><br><br><a href="$link">Download</a>|);

      print $form->parse_html_template('datev/net_gross_difference') if @{ $form->{net_gross_differences} };

    } else {
      $form->error("KNE-Export schlug fehl.");
    }
  } else {
    # OBE-Export nicht implementiert.

    # my @filenames = DATEV->obe_export(\%myconfig, \%$form);
    # if (@filenames) {
    #   print(qq|<br><b>| . $locale->text('OBE-Export erfolgreich!') . qq|</b><br>|);
    #   $link .= "&filenames=" . $form->escape(join(":", @filenames));
    #   print(qq|<br><a href="$link">Download</a>|);
    # } else {
    #   $form->error("OBE-Export schlug fehl.");
    # }
  }

  print("</body></html>");

  $main::lxdebug->leave_sub();
}

sub download {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('datev_export');

  my $tmp_name = Common->tmpname();
  my $zip_name = strftime("lx-office-datev-export-%Y%m%d.zip", localtime(time()));

  my $cwd = getcwd();

  my $path = DATEV::get_path_for_download_token($form->{download_token});
  if (!$path) {
    $form->error($locale->text("Your download does not exist anymore. Please re-run the DATEV export assistant."));
  }

  chdir($path) || die("chdir $path");

  my @filenames = glob "*";

  if (!@filenames) {
    chdir($cwd);
    DATEV::clean_temporary_directories();
    $form->error($locale->text("Your download does not exist anymore. Please re-run the DATEV export assistant."));
  }

  my $zip = Archive::Zip->new();
  map { $zip->addFile($_); } @filenames;
  $zip->writeToFileNamed($tmp_name);

  chdir($cwd);

  open(IN, $tmp_name) || die("open $tmp_name");
  $::locale->with_raw_io(\*STDOUT, sub {
    print("Content-Type: application/zip\n");
    print("Content-Disposition: attachment; filename=\"${zip_name}\"\n\n");
    while (<IN>) {
      print($_);
    }
  });
  close(IN);

  unlink($tmp_name);

  DATEV::clean_temporary_directories();

  $main::lxdebug->leave_sub();
}
