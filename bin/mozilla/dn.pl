#=====================================================================
# LX-Office ERP
# Copyright (C) 2006
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
# Dunning process module
#
#======================================================================

use SL::IS;
use SL::PE;
use SL::DN;
use Data::Dumper;

require "bin/mozilla/common.pl";
require "bin/mozilla/io.pl";
require "bin/mozilla/arap.pl";

1;

sub edit_config {
  $lxdebug->enter_sub();

  DN->get_config(\%myconfig, \%$form);

  $form->{title}          = $locale->text('Edit Dunning Process Config');
  $form->{callback}     ||= build_std_url("action=edit_config");
  $form->{rowcount}       = 1 + scalar @{ $form->{DUNNING} };
  $form->{rowcount_odd}   = $form->{rowcount} % 2;

  $form->header();
  print $form->parse_html_template("dunning/edit_config");

  $lxdebug->leave_sub();
}

sub add {
  $lxdebug->enter_sub();

  # setup customer selection
  $form->all_vc(\%myconfig, "customer", "AR");

  DN->get_config(\%myconfig, \%$form);

  $form->{SHOW_CUSTOMER_SELECTION}      = $form->{all_customer}    && scalar @{ $form->{all_customer} };
  $form->{SHOW_DUNNING_LEVEL_SELECTION} = $form->{DUNNING}         && scalar @{ $form->{DUNNING} };
  $form->{SHOW_DEPARTMENT_SELECTION}    = $form->{all_departments} && scalar @{ $form->{all_departments} };

  $form->{title}    = $locale->text('Start Dunning Process');
  $form->{jsscript} = 1;
  $form->{fokus}    = "search.customer";
  $form->header();

  print $form->parse_html_template("dunning/add");

  $lxdebug->leave_sub();
}

sub show_invoices {
  $lxdebug->enter_sub();

  DN->get_invoices(\%myconfig, \%$form);
  $form->{title} = $locale->text('Start Dunning Process');

  foreach my $row (@{ $form->{DUNNINGS} }) {
    $row->{DUNNING_CONFIG} = [ map +{ %{ $_ } }, @{ $form->{DUNNING_CONFIG} } ];

    if ($row->{next_dunning_config_id}) {
      map { $_->{SELECTED} = $_->{id} == $row->{next_dunning_config_id} } @{ $row->{DUNNING_CONFIG } };
    }
    map { $row->{$_} = $form->format_amount(\%myconfig, $row->{$_} * 1, -2) } qw(amount fee interest);
  }

  $form->{type}           = 'dunning';
  $form->{rowcount}       = scalar @{ $form->{DUNNINGS} };
  $form->{jsscript}       = 1;
  $form->{callback}     ||= build_std_url("action=show_invoices", qw(login password customer invnumber ordnumber groupinvoices minamount dunning_level notes));

  $form->{PRINT_OPTIONS}  = print_options({ 'inline' => 1 });

  $form->header();
  print $form->parse_html_template("dunning/show_invoices");

  $lxdebug->leave_sub();
}

sub save {
  $lxdebug->enter_sub();

  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"dunning_description_$i"} ne "") {
      $form->isblank("dunning_level_$i", $locale->text('Dunning Level missing in row '). $i);
      $form->isblank("dunning_description_$i", $locale->text('Dunning Description missing in row '). $i);
      $form->isblank("terms_$i", $locale->text('Terms missing in row '). $i);
      $form->isblank("payment_terms_$i", $locale->text('Payment Terms missing in row '). $i);
    }
  }

  DN->save_config(\%myconfig, \%$form);
  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
  	$form->{snumbers} = qq|dunning_id_| . $form->{"dunning_id"};
    $form->{addition} = "SAVED FOR DUNNING";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history 
  $form->redirect($locale->text('Dunning Process Config saved!'));

  $lxdebug->leave_sub();
}

sub save_dunning {
  $lxdebug->enter_sub();

  my $active=1;
  my @rows = ();
  undef($form->{DUNNING_PDFS});

  if ($form->{groupinvoices}) {
    my %dunnings_for;

    for my $i (1 .. $form->{rowcount}) {
      next unless ($form->{"active_$i"});

      $dunnings_for{$form->{"customer_id_$i"}} ||= {};
      my $dunning_levels = $dunnings_for{$form->{"customer_id_$i"}};

      $dunning_levels->{$form->{"next_dunning_config_id_$i"}} ||= [];
      my $level = $dunning_levels->{$form->{"next_dunning_config_id_$i"}};

      push @{ $level }, { "row"                    => $i,
                          "invoice_id"             => $form->{"inv_id_$i"},
                          "customer_id"            => $form->{"customer_id_$i"},
                          "next_dunning_config_id" => $form->{"next_dunning_config_id_$i"},
                          "email"                  => $form->{"email_$i"}, };
    }

    foreach my $levels (values %dunnings_for) {
      foreach my $level (values %{ $levels }) {
        next unless scalar @{ $level };

        DN->save_dunning(\%myconfig, \%$form, $level, $userspath, $spool, $sendmail);
      }
    }

  } else {
    for my $i (1 .. $form->{rowcount}) {
      next unless $form->{"active_$i"};

      my $level = [ { "row"                    => $i,
                      "invoice_id"             => $form->{"inv_id_$i"},
                      "customer_id"            => $form->{"customer_id_$i"},
                      "next_dunning_config_id" => $form->{"next_dunning_config_id_$i"},
                      "email"                  => $form->{"email_$i"}, } ];
      DN->save_dunning(\%myconfig, \%$form, $level, $userspath, $spool, $sendmail);
    }
  }

  if($form->{DUNNING_PDFS}) {
    DN->melt_pdfs(\%myconfig, \%$form,$spool);
  }

  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
  	$form->{snumbers} = qq|dunning_id_| . $form->{"dunning_id"};
    $form->{addition} = "DUNNING STARTED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history

  $form->redirect($locale->text('Dunning Process started for selected invoices!'));

  $lxdebug->leave_sub();
}

sub set_email {
  $lxdebug->enter_sub();


  my $callback = "$form->{script}?action=set_email&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(login password name input_subject input_body input_attachment email_subject email_body email_attachment), grep({ /^[fl]_/ } keys %$form)));

  if ($form->{email_attachment}) {
    $form->{email_attachment} = "checked";
  }
  $form->{"title"} = $locale->text("Set eMail text");
  $form->header();
  print($form->parse_html_template("dunning/set_email"));

  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  $form->get_lists("customers"   => "ALL_CUSTOMERS",
                   "departments" => "ALL_DEPARTMENTS");

  DN->get_config(\%myconfig, \%$form);

  $form->{SHOW_CUSTOMER_DDBOX}   = scalar @{ $form->{ALL_CUSTOMERS} } <= $myconfig{vclimit};
  $form->{SHOW_DEPARTMENT_DDBOX} = scalar @{ $form->{ALL_CUSTOMERS} };
  $form->{SHOW_DUNNING_LEVELS}   = scalar @{ $form->{DUNNING} };

  $form->{jsscript} = 1;
  $form->{title}    = $locale->text('Search Dunning');
  $form->{fokus}    = "search.customer";

  $form->header();

  $form->{onload} = qq|focus()|
    . qq|;setupDateFormat('|. $myconfig{dateformat} .qq|', '|. $locale->text("Falsches Datumsformat!") .qq|')|
    . qq|;setupPoints('|. $myconfig{numberformat} .qq|', '|. $locale->text("wrongformat") .qq|')|;

  print $form->parse_html_template("dunning/search");

  $lxdebug->leave_sub();

}

sub show_dunning {
  $lxdebug->enter_sub();

  DN->get_dunning(\%myconfig, \%$form);

  my $odd_even = 0;
  my ($previous_dunning_id, $first_row_for_dunning);

  foreach $ref (@{ $form->{DUNNINGS} }) {
    if ($previous_dunning_id != $ref->{dunning_id}) {
      $odd_even = ($odd_even + 1) % 2;
      $ref->{first_row_for_dunning} = 1;

    } else {
      $ref->{first_row_for_dunning} = 0;
    }

    $previous_dunning_id     = $ref->{dunning_id};
    $ref->{listrow_odd_even} = $odd_even;
  }

  if (!$form->{callback}) {
    $form->{callback} =
      build_std_url("action=show_dunning", qw(customer_id customer dunning_level department_id invnumber ordnumber
                                              ransdatefrom transdateto dunningfrom dunningto notes showold));
  }

  $form->{title} = $locale->text('Dunning overview');
  $form->header();

  print $form->parse_html_template("dunning/show_dunning");

  $lxdebug->leave_sub();

}

sub print_dunning {
  $lxdebug->enter_sub();

  DN->print_dunning(\%myconfig, \%$form, $form->{dunning_id}, $userspath, $spool, $sendmail);

  if($form->{DUNNING_PDFS}) {
    DN->melt_pdfs(\%myconfig, \%$form,$spool);
  } else {
    $form->redirect($locale->text('Could not create dunning copy!'));
  }

  $lxdebug->leave_sub();

}

# end of main

