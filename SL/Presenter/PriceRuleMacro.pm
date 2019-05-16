package SL::Presenter::PriceRuleMacro;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag link_tag);
use SL::Presenter::CustomerVendor qw(customer_vendor_picker);
use SL::Presenter::Business qw(business_picker);
use SL::Presenter::PartsGroup qw(partsgroup_picker);
use SL::Presenter::Pricegroup qw(pricegroup_picker);

use SL::Locale::String qw(t8);

use Exporter qw(import);
our @EXPORT_OK = qw();

use Carp;

my $num_compare_ops = [
  [ 'eq', t8('is equal to') ],
  [ 'le', t8('is lower than or equal') ],
  [ 'ge', t8('is greater than or equal') ],
];

my $date_compare_ops = [
  [ 'eq', t8('is equal to') ],
  [ 'gt', t8('is after') ],
  [ 'lt', t8('is before') ],
];

sub typed_fieldset {
  my ($type, $title, $content, %params) = @_;

  html_tag('fieldset', join('',
    html_tag('legend', remove_control() . ' ' . $title),
    html_tag('div', $content)),
    %params,
  )
}

sub condition_input {
  my ($item, $prefix) = @_;
  for ($item) {
    /^container_and$/ && condition_container_and_input(@_);
    /^container_or$/  && condition_container_or_input(@_);
    /^customer$/      && condition_customer_input(@_);
    /^vendor$/        && condition_vendor_input(@_);
    /^business$/      && condition_business_input(@_);
    /^part$/          && condition_part_input(@_);
    /^partsgroup$/    && condition_partsgroup_input(@_);
    /^pricegroup$/    && condition_pricegroup_input(@_);
    /^ve$/            && condition_ve_input(@_);
    /^qty$/           && condition_qty_input(@_);
    /^qty_range$/     && condition_qty_range_input(@_);
    /^transdate$/     && condition_transdate_input(@_);
    /^reqdate$/       && condition_reqdate_input(@_);
  }
}

sub condition_container_and_input {
  my ($item, $prefix) = @_;

  typed_fieldset(
    'container_and',
    t8('And'),
    join '', map({
        html_tag('div', condition_input($_, $prefix))
      }
      listify($item->condition)),
      add_element_control($item)
  );
}

sub condition_container_or_input {
  my ($item, $prefix) = @_;

  typed_fieldset(
    'container_or',
    t8('Or'),
    join '',
      map({
        html_tag('div', condition_input($_, $prefix))
      } listify($item->condition)),
      add_element_control($item)
  );
}

sub condition_id_input {
  my ($item, $prefix, $picker_sub) = @_;

  typed_fieldset(
    $item->type,
    $item->description . ' ' . t8('is'),
    join '',
      map({
        remove_control(),
        $picker_sub->($_),
      } listify($item->id)),
      add_element($item)
  );
}

sub condition_customer_input {
  my ($item, $prefix) = @_;

  condition_id_input( $item, $prefix, sub { customer_vendor_picker($prefix, $_, type => 'customer') });
}

sub condition_vendor_input {
  my ($item, $prefix) = @_;

  condition_id_input( $item, $prefix, sub { customer_vendor_picker($prefix, $_, type => 'vendor') });
}

sub condition_business_input {

}

sub add_element {
  html_tag('span', t8('Add value'), class => 'interact cursor-pointer');
}

1;
