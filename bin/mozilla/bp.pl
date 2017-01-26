#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2003
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
# Batch printing
#
#======================================================================

use SL::BP;
use SL::Locale::String qw(t8);
use Data::Dumper;
use List::Util qw(first);

1;

require "bin/mozilla/common.pl";

use strict;

# end of main

sub assert_bp_access {
  my %access_map = (
    'invoice'           => 'invoice_edit',
    'sales_order'       => 'sales_order_edit',
    'sales_quotation'   => 'sales_quotation_edit',
    'purchase_order'    => 'purchase_order_edit',
    'packing_list'      => 'sales_delivery_order_edit|purchase_delivery_order_edit',
    'request_quotation' => 'request_quotation_edit',
    'check'             => 'cash',
    'receipt'           => 'cash',
  );

  if ($::form->{type} && $access_map{$::form->{type}}) {
    $::auth->assert($access_map{$::form->{type}});

  } else {
    $::auth->assert('DOES_NOT_EXIST');
  }
}

sub search {
  $::lxdebug->enter_sub;

  assert_bp_access();

  my %label = (
       invoice           => { title => $::locale->text('Sales Invoices'),  invnumber => 1, ordnumber => 1 },
       sales_order       => { title => $::locale->text('Sales Orders'),    ordnumber => 1, },
       purchase_order    => { title => $::locale->text('Purchase Orders'), ordnumber => 1, },
       sales_quotation   => { title => $::locale->text('Quotations'),      quonumber => 1, },
       request_quotation => { title => $::locale->text('RFQs'),            quonumber => 1, },
       packing_list      => { title => $::locale->text('Delivery Orders'), donumber  => 1, ordnumber => 1 },
       check             => { title => $::locale->text('Checks'),          chknumber => 1, },
       receipt           => { title => $::locale->text('Receipts'),        rctnumber => 1, },
  );

  my $bp_accounts = $::form->{type} =~ /check|receipt/
                 && BP->payment_accounts(\%::myconfig, $::form);

  setup_bp_search_action_bar();

  $::form->header;
  print $::form->parse_html_template('bp/search', {
    label         => \%label,
    show_accounts => $bp_accounts,
    account_sub   => sub { ("$_[0]{accno}--$_[0]{description}")x2 },
    vc_keys       => sub { "$_[0]{name}--$_[0]{id}" },
  });

  $::lxdebug->leave_sub;
}

sub remove {
  $::lxdebug->enter_sub;
  assert_bp_access();

  $::form->info($::locale->text('Removing marked entries from queue ...'));
  $::form->{callback} .= "&header=1" if $::form->{callback};

  $::form->redirect($::locale->text('Removed spoolfiles!'))
    if BP->delete_spool(\%::myconfig, $::form);
  $::form->error($::locale->text('Cannot remove files!'));

  $::lxdebug->leave_sub;
}

sub print {
  $::lxdebug->enter_sub;
  assert_bp_access();

  $::form->get_lists(printers => 'ALL_PRINTERS');
  # use the command stored in the databse or fall back to $myconfig{printer}
  my $selected_printer =  first { $_ } map ({ $_ ->{printer_command} }
                                         grep { $_->{id} eq $::form->{printer} }
                                           @{ $::form->{ALL_PRINTERS} }),
                                       $::myconfig{printer};

  if ($::form->{callback}) {
    map { $::form->{callback} .= "&checked_$_=1" if $::form->{"checked_$_"} }
      (1 .. $::form->{rowcount});
    $::form->{callback} .= "&header=1";
  }

  for my $i (1 .. $::form->{rowcount}) {
    if ($::form->{"checked_$i"}) {
      $::form->info($::locale->text('Printing ... '));

      if (BP->print_spool(\%::myconfig, $::form, "| $selected_printer")) {
        print $::locale->text('done');
        $::form->redirect($::locale->text('Marked entries printed!'));
      }
      $::dispatcher->end_request;
    }
  }

  $::form->error('Nothing selected!');

  $::lxdebug->leave_sub;
}

sub list_spool {
  $::lxdebug->enter_sub;
  assert_bp_access();

  # parse old vc picker
  $::form->{ $::form->{vc} } = $::form->unescape($::form->{ $::form->{vc} });
  ($::form->{ $::form->{vc} }, $::form->{"$::form->{vc}_id"}) = split(/--/, $::form->{ $::form->{vc} });

  BP->get_spoolfiles(\%::myconfig, $::form);

  my @href_options = ('vc', 'type', 'title', $::form->{vc});

  my %option_texts = (
    customer      => sub { $::locale->text('Customer')         . " : $::form->{customer}" },
    vendor        => sub { $::locale->text('Customer')         . " : $::form->{vendor}" },
    account       => sub { $::locale->text('Account')          . " : $::form->{account}" },
    invnumber     => sub { $::locale->text('Invoice Number')   . " : $::form->{invnumber}" },
    ordnumber     => sub { $::locale->text('Order Number')     . " : $::form->{ordnumber}" },
    quonumber     => sub { $::locale->text('Quotation Number') . " : $::form->{quonumber}" },
    donumber      => sub { $::locale->text('Delivery Order Number') . " : $::form->{donumber}" },
    transdatefrom => sub { $::locale->text('From') . "&nbsp;" . $::locale->date(\%::myconfig, $::form->{transdatefrom}, 1) },
    transdateto   => sub { $::locale->text('To')   . "&nbsp;" . $::locale->date(\%::myconfig, $::form->{transdateto}, 1) },
  );

  my @options;
  for my $key ($::form->{vc}, qw(account invnumber ordnumber quonumber donumber transdatefrom transdateto)) {
    next unless $::form->{$key};
    push @href_options, $key;
    push @options, $option_texts{$key} ? $option_texts{$key}->() : '';
  }

  my $last_spoolfile;
  for my $ref (@{ $::form->{SPOOL} }) {
    $ref->{module}   = ($ref->{module} eq 'ar') ? "is" : "ir" if $ref->{invoice};
    $ref->{new_file} = $last_spoolfile ne $ref->{spoolfile};
  } continue {
    $last_spoolfile = $ref->{spoolfile};
  }

  $::form->get_lists(printers => "ALL_PRINTERS");

  setup_bp_list_spool_action_bar();

  $::form->header;
  print $::form->parse_html_template('bp/list_spool', {
     href         => build_std_url('bp.pl', @href_options),
     is_invoice   => scalar ($::form->{type} =~ /^invoice$/),
     is_order     => scalar ($::form->{type} =~ /_order$/),
     is_quotation => scalar ($::form->{type} =~ /_quotation$/),
     options      => \@options,
  });

  $::lxdebug->leave_sub;
}

sub setup_bp_search_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Show'),
        submit    => [ '#form', { action => "list_spool" } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_bp_list_spool_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Remove'),
        submit  => [ '#form', { action => "remove" } ],
        checks  => [ [ 'kivi.check_if_entries_selected', '.check_all' ] ],
        confirm => t8('Are you sure you want to remove the marked entries from the queue?'),
      ],
      action => [
        t8('Print'),
        submit => [ '#form', { action => "print" } ],
        checks => [ [ 'kivi.check_if_entries_selected', '.check_all' ] ],
      ],
    );
  }
}
