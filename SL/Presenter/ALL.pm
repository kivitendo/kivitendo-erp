package SL::Presenter::ALL;

use strict;

use SL::Presenter::Chart;
use SL::Presenter::CustomerVendor;
use SL::Presenter::DeliveryOrder;
use SL::Presenter::EscapedText;
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
use SL::Presenter::ShopOrder;
use SL::Presenter::Text;
use SL::Presenter::Tag;
use SL::Presenter::BankAccount;

our %presenters = (
  chart                       => 'SL::Presenter::Chart',
  customer_vendor             => 'SL::Presenter::CustomerVendor',
  delivery_order              => 'SL::Presenter::DeliveryOrder',
  escaped_text                => 'SL::Presenter::EscapedText',
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
  shop_order                  => 'SL::Presenter::ShopOrder',
  text                        => 'SL::Presenter::Text',
  tag                         => 'SL::Presenter::Tag',
  bank_account                => 'SL::Presenter::BankAccount',
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
