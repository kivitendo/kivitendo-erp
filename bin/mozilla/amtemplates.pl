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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# administration
#
#======================================================================

use SL::AM;
use SL::Form;

use Data::Dumper;

1;

require "bin/mozilla/common.pl";

# end of main

sub display {
  call_sub($form->{display_nextsub});
}

sub save {
  call_sub($form->{save_nextsub});
}

sub edit {
  call_sub($form->{edit_nextsub});
}

sub display_template {
  $lxdebug->enter_sub();

  $form->{edit} = 0;
  display_template_form();

  $lxdebug->leave_sub();
}

sub edit_template {
  $lxdebug->enter_sub();

  $form->{edit} = 1;
  display_template_form();

  $lxdebug->leave_sub();
}

sub save_template {
  $lxdebug->enter_sub();

  $form->isblank("formname", $locale->text("You're not editing a file.")) unless ($form->{type} eq "stylesheet");

  my ($filename) = AM->prepare_template_filename(\%myconfig, $form);
  if (my $error = AM->save_template($filename, $form->{content})) {
    $form->error(sprintf($locale->text("Saving the file '%s' failed. OS error message: %s"), $filename, $error));
  }

  $form->{edit} = 0;
  display_template_form();

  $lxdebug->leave_sub();
}

sub display_template_form {
  $lxdebug->enter_sub();

  $form->{"formname"} =~ s|.*/||;
  my $format = $form->{"format"} eq "html" ? "html" : "tex";

  $form->{"title"} = $form->{"type"} eq "stylesheet" ? $locale->text("Edit the stylesheet") : $locale->text("Edit templates");

  my %options;

  my @hidden = qw(login password type format);

  if (($form->{"type"} ne "stylesheet") && !$form->{"edit"}) {
    $options{"SHOW_EDIT_OPTIONS"} = 1;

    #
    # Setup "formname" selection
    #

    $form->get_lists("printers" => "ALL_PRINTERS",
                     "languages" => "ALL_LANGUAGES",
                     "dunning_configs" => "ALL_DUNNING_CONFIGS");

    my %formname_setup =
      (
        "balance_sheet" => { "translation" => $locale->text('Balance Sheet'), "html" => 1 },
        "bin_list" => $locale->text('Bin List'),
        "bwa" => { "translation" => $locale->text('BWA'), "html" => 1 },
        "check" => { "translation" => $locale->text('Check'), "html" => 1 },
        "credit_note" => $locale->text('Credit Note'),
        "income_statement" => { "translation" => $locale->text('Income Statement'), "html" => 1 },
        "invoice" => $locale->text('Invoice'),
        "packing_list" => $locale->text('Packing List'),
        "pick_list" => $locale->text('Pick List'),
        "proforma" => $locale->text('Proforma Invoice'),
        "purchase_order" => $locale->text('Purchase Order'),
        "receipt" => { "translation" => $locale->text('Receipt'), "tex" => 1 },
        "request_quotation" => $locale->text('RFQ'),
        "sales_order" => $locale->text('Confirmation'),
        "sales_quotation" => $locale->text('Quotation'),
        "statement" => $locale->text('Statement'),
        "storno_invoice" => $locale->text('Storno Invoice'),
        "storno_packing_list" => $locale->text('Storno Packing List'),
        "ustva-2004" => { "translation" => $locale->text("USTVA 2004"), "tex" => 1 },
        "ustva-2005" => { "translation" => $locale->text("USTVA 2005"), "tex" => 1 },
        "ustva-2006" => { "translation" => $locale->text("USTVA 2006"), "tex" => 1 },
        "ustva-2007" => { "translation" => $locale->text("USTVA 2007"), "tex" => 1 },
        "ustva" => $locale->text("USTVA"),
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
             "label" => $locale->text('Payment Reminder') . ": " . $ref->{"dunning_description"} });
    }

    @values = sort({ $a->{"label"} cmp $b->{"label"} } @values);

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

  if ($form->{formname} || ($form->{type} eq "stylesheet")) {
    $options{"SHOW_CONTENT"} = 1;

    ($options{"filename"}, $options{"display_filename"})
      = AM->prepare_template_filename(\%myconfig, $form);

    ($options{"content"}, $options{"lines"})
      = AM->load_template($options{"filename"});

    $options{"CAN_EDIT"} = $form->{"edit"};

    if ($form->{edit}) {
      $form->{fokus} = "Form.content";

    } else {
      $options{"content"}                 = "\n\n" if (!$options{"content"});
      $options{"SHOW_SECOND_EDIT_BUTTON"} = $options{"lines"} > 25;
    }
  }

  $options{"HIDDEN"} = [ map(+{ "name" => $_, "value" => $form->{$_} }, @hidden) ];

  $form->header;
  print($form->parse_html_template("am/edit_templates", \%options));

  $lxdebug->leave_sub();
}

1;
