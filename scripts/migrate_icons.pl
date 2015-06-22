
use strict;
use warnings;

my %icons = (
'AP--Add Purchase Order.png'                                => 'purchase_order_add.png',
'AP--Add RFQ.png'                                           => 'rfq_add.png',
'AP.png'                                                    => 'ap.png',
'AP--Reports.png'                                           => 'ap_report.png',
'AP--Reports--Purchase Orders.png'                          => 'purchase_order_report.png',
'AP--Reports--RFQs.png'                                     => 'rfq_report.png',
'AR--Add Credit Note.png'                                   => 'credit_note_add.png',
'AR--Add Delivery Order.png'                                => 'delivery_oder_add.png', # symlink to MDI-Txt_editor
'AR--Add Dunning.png'                                       => 'dunning_add.png',
'AR--Add Quotation.png'                                     => 'quotation_add.png',
'AR--Add Sales Invoice.png'                                 => 'sales_invoice_add.png',
'AR--Add Sales Order.png'                                   => 'sales_order_add.png',
'AR.png'                                                    => 'ar.png',
'AR--Reports--Delivery Orders.png'                          => 'delivery_order_report.png', # symlink to MDI-Text_editor
'AR--Reports--Dunnings.png'                                 => 'dunnings_report.png',
'AR--Reports--Invoices, Credit Notes & AR Transactions.png' => 'invoices_report.png',
'AR--Reports.png'                                           => 'ar_report.png',
'AR--Reports--Quotations.png'                               => 'report_quotations.png',
'AR--Reports--Sales Orders.png'                             => 'report_sales_orders.png',
'Batch Printing--Packing Lists.png'                         => 'package_lists.png',
'Batch Printing.png'                                        => 'printing.png',
'Batch Printing--Purchase Orders.png'                       => 'purchase_order_printing.png',
'Batch Printing--Quotations.png'                            => 'quotation_printing.png',
'Batch Printing--Receipts.png'                              => 'receipt_printing.png',
'Batch Printing--RFQs.png'                                  => 'rfq_printing.png',
'Batch Printing--Sales Invoices.png'                        => 'sales_invoice_printing.png',
'Batch Printing--Sales Orders.png'                          => 'sales_order_printing.png',
'Cash--Payment.png'                                         => 'payment.png',
'Cash.png'                                                  => 'cash.png',
'Cash--Receipt.png'                                         => 'receipt.png',
'Cash--Reconciliation.png'                                  => 'reconcilliation.png',
'Cash--Reports--Payments.png'                               => 'payment_report.png',
'Cash--Reports.png'                                         => 'cash_report.png',
'Cash--Reports--Receipts.png'                               => 'receipt_report.png',
'CRM--Add--Customer.png'                                    => 'customer.png',
'CRM--Add--Person.png'                                      => 'contact.png',
'CRM--Add--Vendor.png'                                      => 'vendor.png',
'CRM--Admin--Document Template.png'                         => 'document_template.png',
'CRM--Admin--Label.png'                                     => 'label.png',
'CRM--Admin--Message.png'                                   => 'message.png',
'CRM--Admin.png'                                            => 'admin.png',
'CRM--Admin--Status.png'                                    => 'status.png',
'CRM--Admin--User Groups.png'                               => 'user_group.png',
'CRM--Admin--User.png'                                      => 'user.png',
'CRM--Appointments.png'                                     => 'appointment.png',
'CRM--E-mail.png'                                           => 'email.png',
'CRM--Follow-Up.png'                                        => 'follow_up.png',
'CRM--Help.png'                                             => 'help.png',
'CRM--Knowledge.png'                                        => 'knowledge.png',
'CRM--Memo.png'                                             => 'memo.png',
'CRM--Opportunity.png'                                      => 'opportunity.png',
'CRM.png'                                                   => 'crm.png',
'CRM--Search.png'                                           => 'search.png',
'CRM--Service.png'                                          => 'service.png',
'General Ledger--Add AP Transaction.png'                    => 'ap_transaction_add.png',
'General Ledger--Add AR Transaction.png'                    => 'ar_transaction_add.png',
'General Ledger--Add Transaction.png'                       => 'transaction_add.png',
'General Ledger--DATEV - Export Assistent.png'              => 'datev.png',
'General Ledger.png'                                        => 'gl.png',
'General Ledger--Reports--AP Aging.png'                     => 'ap_aging.png',
'General Ledger--Reports--AR Aging.png'                     => 'ar_aging.png',
'General Ledger--Reports--Journal.png'                      => 'journal.png',
'General Ledger--Reports.png'                               => 'gl_report.png',
'Master Data--Add Assembly.png'                             => 'assembly_add.png',
'Master Data--Add Customer.png'                             => 'customer_add.png',
'Master Data--Add License.png'                              => 'license_add.png',
'Master Data--Add Part.png'                                 => 'part_add.png',
'Master Data--Add Project.png'                              => 'project_add.png',
'Master Data--Add Service.png'                              => 'service_add.png',
'Master Data--Add Vendor.png'                               => 'vendor_add.png',
'Master Data.png'                                           => 'master_data.png',
'Master Data--Reports--Assemblies.png'                      => 'assembly_report.png',
'Master Data--Reports--Customers.png'                       => 'customer_report.png',
'Master Data--Reports--Licenses.png'                        => 'license_report.png',
'Master Data--Reports--Parts.png'                           => 'part_report.png',
'Master Data--Reports.png'                                  => 'master_data_report.png',
'Master Data--Reports--Projects.png'                        => 'project_report.png',
'Master Data--Reports--Projecttransactions.png'             => 'project_transaction_report.png',
'Master Data--Reports--Services.png'                        => 'service_report.png',
'Master Data--Reports--Vendors.png'                         => 'vendor_report.png',
'Master Data--Update Prices.png'                            => 'prices_update.png',
'Neues Fenster.png'                                         => 'window_new.png',
'phone.png'                                                 => 'phone.png',
'Program--Logout.png'                                       => 'logout.png',
'Program.png'                                               => 'program.png',
'Program--Preferences.png'                                  => 'preferences.png',
'Program--Version.png'                                      => 'version.png',
'Reports--Balance Sheet.png'                                => 'balance_sheet.png',
'Reports--Chart of Accounts.png'                            => 'chart_of_accounts.png',
'Reports--Income Statement.png'                             => 'income_statement.png',
'Reports.png'                                               => 'report.png',
'Reports--UStVa.png'                                        => 'ustva.png',
'System.png'                                                => 'system.png',
'Warehouse.png'                                             => 'warehouse.png',
'Warehouse--Produce Assembly.png'                           => 'assembly_produce.png',
'MDI-Text-Editor-16x16.png'                                 => 'mdi_text_editor.png',
'Productivity'                                              => 'productivity.png',
);

my %symlinks = (
'mdi_text_editor.png' => 'delivery_order_add.png', # symlink to MDI-Txt_editor
'mdi_text_editor.png' => 'delivery_order_report.png', # symlink to MDI-Txt_editor
);

sub checks {
  # check 1: no duplicate targets
  my %seen;
  for (values %icons) {
    next unless defined $_;
    die "duplicate target: $_" if $seen{$_}++;
  }

  # check2: all targets should end in .png, otherwise there's a typo
  for (values %icons) {
    next unless defined $_;
    die "target does not end in .png: $_" unless /\.png$/;
  }

  # check 3: all sources need to be real files in this dir
  for (keys %icons) {
    next unless defined $_;
    die "key $_ is not a file!" unless -f $_;
  }

  # check 4: all keys in symlinks need to be a target in icons
  for (keys %symlinks) {
    no warnings 'uninitialized';
    die "can't symlink this, because it's not a target of renaming: $_" unless { reverse %icons }->{$_};
  }
}

sub make_icons {
  # now do the actual renaming
  while (my ($from, $to) = each(%icons)) {
    if (defined $to) {
      # rename
      system("git mv '$from' '$to'");
    } else {
      # delete
      system("git rm '$from'");
    }
  }

  # and do some symlinking
  while (my ($from, $to) = each(%symlinks)) {
    system("ln -s '$from' '$to'");
    system("git add '$to'");
  }
}

sub translate_menu {
  my ($menu_file) = @_;

  my $new_file = $menu_file;
  $new_file =~ s/\./_new\./;

  open my $in,  "<", $menu_file or die "error opening $menu_file: $!";
  open my $out, ">", $new_file  or die "error opening $new_file:  $!";

  while (<$in>) {
    print $out $_;
    if (/^\[(.*)\]$/) {
      my $name = $1;
      # look if we got this in %icons
      if ($icons{ $name . '.png' }) {
        my $new_name = $icons{ $name . '.png' };
        $new_name =~ s/\.png$//;
        print $out "ICON=$icons{ $name . '.png' }\n";
      } else {
        warn "don't know what '$name' is in $menu_file";
      }
    }
  }
  system("mv $new_file $menu_file");
}

# checks();
# make_icons();

translate_menu('menus/erp.ini');
translate_menu('menus/admin.ini');
translate_menu('menus/crm.ini');
