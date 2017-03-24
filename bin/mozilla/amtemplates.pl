#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================
#
# administration
#
#======================================================================

use File::Find;

use SL::DB::Default;
use SL::AM;
use SL::Form;

use Data::Dumper;

use strict;

1;

require "bin/mozilla/common.pl";

# end of main

sub display {
  call_sub($main::form->{display_nextsub});
}

sub save {
  call_sub($main::form->{save_nextsub});
}

sub edit {
  call_sub($main::form->{edit_nextsub});
}

sub display_template {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $main::auth->assert('admin');

  $form->{edit} = 0;
  display_template_form();

  $main::lxdebug->leave_sub();
}

sub edit_template {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $main::auth->assert('admin');

  $form->{edit} = 1;
  display_template_form();

  $main::lxdebug->leave_sub();
}

sub save_template {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('admin');

  $form->isblank("formname", $locale->text("You're not editing a file."));

  my ($filename) = AM->prepare_template_filename(\%myconfig, $form);
  if (my $error = AM->save_template($filename, $form->{content})) {
    $form->error(sprintf($locale->text("Saving the file '%s' failed. OS error message: %s"), $filename, $error));
  }

  $form->{edit} = 0;
  display_template_form();

  $main::lxdebug->leave_sub();
}

sub display_template_form {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('admin');

  my $defaults = SL::DB::Default->get;
  $form->error($::locale->text('No print templates have been created for this client yet. Please do so in the client configuration.')) if !$defaults->templates;

  if ($form->{"formname"} =~ m|\.\.| || $form->{"formname"} =~ m|^/|) {
    $form->{"formname"} =~ s|.*/||;
  }

  my $format = $form->{"format"} eq "html" ? "html" : "tex";

  $form->{"title"} = $locale->text("Edit templates");
  if ($form->{"format"}) {
      $form->{"title"} = uc($form->{"format"}) . " - " . $form->{"title"};
  }

  my %options;

  my @hidden = qw(type format);

  if (!$form->{"edit"}) {
    $options{"SHOW_EDIT_OPTIONS"} = 1;

    #
    # Setup "formname" selection
    #

    $form->get_lists("printers" => "ALL_PRINTERS",
                     "languages" => "ALL_LANGUAGES",
                     "dunning_configs" => "ALL_DUNNING_CONFIGS");

    my %formname_setup =
      (
        # balance_sheet           => { translation => $locale->text('Balance Sheet'),             html => 1 },
        bin_list                => $locale->text('Bin List'),
        bwa                     => { translation => $locale->text('BWA'),                       html => 1 },
        check                   => { translation => $locale->text('Check'),                     html => 1 },
        credit_note             => $locale->text('Credit Note'),
        income_statement        => { translation => $locale->text('Income Statement'),          html => 1 },
        invoice                 => $locale->text('Invoice'),
        pick_list               => $locale->text('Pick List'),
        proforma                => $locale->text('Proforma Invoice'),
        purchase_delivery_order => { translation => $::locale->text('Purchase delivery order'), tex => 1 },
        purchase_order          => $locale->text('Purchase Order'),
        receipt                 => { translation => $locale->text('Receipt'),                   tex => 1 },
        request_quotation       => $locale->text('RFQ'),
        sales_delivery_order    => { translation => $::locale->text('Sales delivery order'),    tex => 1 },
        sales_order             => $locale->text('Confirmation'),
        sales_quotation         => $locale->text('Quotation'),
        statement               => $locale->text('Statement'),
        storno_invoice          => $locale->text('Storno Invoice'),
        "ustva-2004"            => { translation => $locale->text("USTVA 2004"),                tex => 1 },
        "ustva-2005"            => { translation => $locale->text("USTVA 2005"),                tex => 1 },
        "ustva-2006"            => { translation => $locale->text("USTVA 2006"),                tex => 1 },
        "ustva-2007"            => { translation => $locale->text("USTVA 2007"),                tex => 1 },
        ustva                   => $locale->text("USTVA"),
      );

    my (@values, $file, $setup);

    while (($file, $setup) = each(%formname_setup)) {
      next if ref($setup) && !$setup->{$format};

      push(@values,
           { "value"   => $file,
             "label"   => ref($setup) ? $setup->{"translation"} : $setup });
    }

    # "zahlungserinnerung" => $locale->text('Payment Reminder'),

    foreach my $ref (@{ $form->{"ALL_DUNNING_CONFIGS"} }) {
      next if !$ref->{"template"};

      push(@values,
           { "value" => $ref->{"template"},
             "label" => $locale->text('Payment Reminder') . ": " . $ref->{"dunning_description"} },
           { "value" => $ref->{"template"} . "_invoice",
             "label" => $locale->text('Payment Reminder') . ": " . $ref->{"dunning_description"} . ' (' . $locale->text("Invoice for fees") . ')' });
    }

    @values = sort({ $a->{"label"} cmp $b->{"label"} } @values);

    #
    # at the end: others/includes for tex
    #
    if ($format eq "tex") {
      # search all .tex-files in template dir (recursively)
      my $template_dir = $defaults->templates;
      my @all_files;
      find(
        sub {
          next if (-l $_ || -d $_);
          next unless (-f $_ && $_ =~ m/.*?\.tex$/);

          my $fname = $File::Find::name;
          # remove template dir from name
          $fname =~ s|^\Q$template_dir\E/||;
          # remove .tex from name
          $fname =~ s|.tex$||;

          push(@all_files, $fname);

          }, $template_dir);

      # filter all files already set up (i.e. not already in @values)
      my @other_files = grep { my $a=$_; not grep {$a eq $_->{value}} @values } @all_files;

      # add other tex files
      foreach my $o (@other_files) {
        push(@values, { "value" => $o, "label" => $locale->text("Others")." ($o)" });
      }
    }

    $options{FORMNAME} = [ @values ];

    #
    # Setup "language" selection
    #

    @values = ();

    foreach my $item (@{ $form->{"ALL_LANGUAGES"} }) {
      next unless ($item->{"template_code"});

      push(@values,
           { "value" => "$item->{id}--$item->{template_code}",
             "label" => $item->{"description"} });
    }

    $options{LANGUAGE} = [ @values ];

    #
    # Setup "printer" selection
    #

    @values = ();

    foreach my $item (@{ $form->{"ALL_PRINTERS"} }) {
      next unless ($item->{"template_code"});

      push(@values,
           { "value" => "$item->{id}--$item->{template_code}",
             "label" => $item->{"printer_description"} });
    }

    $options{PRINTER} = [ @values ];

  } else {
    push(@hidden, qw(formname language printer));
  }

  if ($form->{formname}) {
    $options{"SHOW_CONTENT"} = 1;

    ($options{"filename"}, $options{"display_filename"})
      = AM->prepare_template_filename(\%myconfig, $form);

    ($options{"content"}, $options{"lines"})
      = AM->load_template($options{"filename"});

    $options{"CAN_EDIT"} = $form->{"edit"};

    if (!$form->{edit}) {
      $options{"content"}                 = "\n\n" if (!$options{"content"});
      $options{"SHOW_SECOND_EDIT_BUTTON"} = $options{"lines"} > 25;
    }
  }

  $options{"HIDDEN"} = [ map(+{ "name" => $_, "value" => $form->{$_} }, @hidden) ];

  $form->header;
  print($form->parse_html_template("am/edit_templates", \%options));

  $main::lxdebug->leave_sub();
}

1;
