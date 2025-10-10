package SL::Presenter::ALL;

use strict;

use SL::Presenter::Bin;
use SL::Presenter::Chart;
use SL::Presenter::CustomerVendor;
use SL::Presenter::DatePeriod;
use SL::Presenter::DeliveryOrder;
use SL::Presenter::Dunning;
use SL::Presenter::EmailJournal;
use SL::Presenter::EscapedText;
use SL::Presenter::FileObject;
use SL::Presenter::Invoice;
use SL::Presenter::GL;
use SL::Presenter::Letter;
use SL::Presenter::Order;
use SL::Presenter::Part;
use SL::Presenter::Project;
use SL::Presenter::Record;
use SL::Presenter::RequirementSpec;
use SL::Presenter::RequirementSpecItem;
use SL::Presenter::RequirementSpecTextBlock;
use SL::Presenter::SepaExport;
use SL::Presenter::SepaExportItem;
use SL::Presenter::ShopOrder;
use SL::Presenter::Text;
use SL::Presenter::Tag;
use SL::Presenter::BankAccount;
use SL::Presenter::BankTransaction;
use SL::Presenter::MaterialComponents;

our %presenters = (
  bin                         => 'SL::Presenter::Bin',
  chart                       => 'SL::Presenter::Chart',
  customer_vendor             => 'SL::Presenter::CustomerVendor',
  date_period                 => 'SL::Presenter::DatePeriod',
  delivery_order              => 'SL::Presenter::DeliveryOrder',
  dunning                     => 'SL::Presenter::Dunning',
  email_journal               => 'SL::Presenter::EmailJournal',
  escaped_text                => 'SL::Presenter::EscapedText',
  file_object                 => 'SL::Presenter::FileObject',
  invoice                     => 'SL::Presenter::Invoice',
  gl                          => 'SL::Presenter::GL',
  letter                      => 'SL::Presenter::Letter',
  order                       => 'SL::Presenter::Order',
  part                        => 'SL::Presenter::Part',
  project                     => 'SL::Presenter::Project',
  record                      => 'SL::Presenter::Record',
  requirement_spec            => 'SL::Presenter::RequirementSpec',
  requirement_spec_item       => 'SL::Presenter::RequirementSpecItem',
  requirement_spec_text_block => 'SL::Presenter::RequirementSpecTextBlock',
  sepa_export                 => 'SL::Presenter::SepaExport',
  sepa_exprot_item            => 'SL::Presenter::SepaExportItem',
  shop_order                  => 'SL::Presenter::ShopOrder',
  text                        => 'SL::Presenter::Text',
  tag                         => 'SL::Presenter::Tag',
  bank_account                => 'SL::Presenter::BankAccount',
  bank_transaction            => 'SL::Presenter::BankTransaction',
  M                           => 'SL::Presenter::MaterialComponents',
);

sub wrap {
  bless [ $_[0] ], 'SL::Presenter::ALL::Wrapper';
}

package SL::Presenter::ALL::Wrapper;

sub AUTOLOAD {
  our $AUTOLOAD;

  my ($self, @args) = @_;

  my $method = $AUTOLOAD;
  $method    =~ s/.*:://;

  return if $method eq 'DESTROY';

  splice @args, -1, 1, %{ $args[-1] } if @args && (ref($args[-1]) eq 'HASH');

  if (my $sub = $self->[0]->can($method)) {
    return $sub->(@args);
  }
}

1;
