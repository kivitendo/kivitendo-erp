package SL::DB::PurchaseInvoice;

use strict;

use Carp;

use SL::DB::MetaSetup::PurchaseInvoice;
use SL::DB::Manager::PurchaseInvoice;
use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::LinkedRecords;
use SL::Locale::String qw(t8);

# The calculator hasn't been adjusted for purchase invoices yet.
# use SL::DB::Helper::PriceTaxCalculator;

__PACKAGE__->meta->add_relationship(
  invoiceitems   => {
    type         => 'one to many',
    class        => 'SL::DB::InvoiceItem',
    column_map   => { id => 'trans_id' },
    manager_args => { with_objects => [ 'part' ] }
  },
  sepa_export_items => {
    type            => 'one to many',
    class           => 'SL::DB::SepaExportItem',
    column_map      => { id => 'ap_id' },
    manager_args    => { with_objects => [ 'sepa_export' ] }
  },
  custom_shipto     => {
    type            => 'one to one',
    class           => 'SL::DB::Shipto',
    column_map      => { id => 'trans_id' },
    query_args      => [ module => 'AP' ],
  },
  transactions   => {
    type         => 'one to many',
    class        => 'SL::DB::AccTransaction',
    column_map   => { id => 'trans_id' },
    manager_args => { with_objects => [ 'chart' ],
                      sort_by      => 'acc_trans_id ASC' }
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_html('notes');

sub items { goto &invoiceitems; }
sub add_items { goto &add_invoiceitems; }

sub items_sorted {
  my ($self) = @_;

  return [ sort {$a->position <=> $b->position } @{ $self->items } ];
}

sub is_sales {
  # For compatibility with Order, DeliveryOrder
  croak 'not an accessor' if @_ > 1;
  return 0;
}

sub date {
  goto &transdate;
}

sub reqdate {
  goto &duedate;
}

sub customervendor {
  goto &vendor;
}

sub abbreviation {
  my $self = shift;

  return t8('AP Transaction (abbreviation)') if !$self->invoice && !$self->storno;
  return t8('AP Transaction (abbreviation)') . '(' . t8('Storno (one letter abbreviation)') . ')' if !$self->invoice && $self->storno;
  return t8('Invoice (one letter abbreviation)'). '(' . t8('Storno (one letter abbreviation)') . ')' if $self->storno;
  return t8('Invoice (one letter abbreviation)');

};

sub pay_invoice {
  my ($self, %params) = @_;

  #Mark invoice as paid
  $self->paid($self->paid+$params{amount});
  $self->save;

  Common::check_params(\%params, qw(chart_id trans_id amount transdate));

  #account of bank account or cash
  my $account_bank = SL::DB::Manager::Chart->find_by(id => $params{chart_id});

  #Search the contra account
  my $acc_trans = SL::DB::Manager::AccTransaction->find_by(trans_id   => $params{trans_id},
                                                           or => [ chart_link => { like => "%:AP" },
                                                                   chart_link => { like => "AP:%" },
                                                                   chart_link => "AP" ]);
  my $contra_account = SL::DB::Manager::Chart->find_by(id => $acc_trans->chart_id);

  #Two new transfers in acc_trans (for bank account and for contra account)
  my $new_acc_trans = SL::DB::AccTransaction->new(trans_id   => $params{trans_id},
                                                  chart_id   => $account_bank->id,
                                                  chart_link => $account_bank->link,
                                                  amount     => $params{amount},
                                                  transdate  => $params{transdate},
                                                  source     => $params{source},
                                                  memo       => '',
                                                  taxkey     => 0,
                                                  tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
  $new_acc_trans->save;
  $new_acc_trans = SL::DB::AccTransaction->new(trans_id   => $params{trans_id},
                                               chart_id   => $contra_account->id,
                                               chart_link => $contra_account->link,
                                               amount     => (-1 * $params{amount}),
                                               transdate  => $params{transdate},
                                               source     => $params{source},
                                               memo       => '',
                                               taxkey     => 0,
                                               tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
  $new_acc_trans->save;
}

sub link {
  my ($self) = @_;

  my $html;
  $html   = SL::Presenter->get->purchase_invoice($self, display => 'inline') if $self->invoice;
  $html   = SL::Presenter->get->ap_transaction($self, display => 'inline') if !$self->invoice;

  return $html;
}

1;
