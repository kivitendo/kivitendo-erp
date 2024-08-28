package SL::Presenter::Warehouse;

use strict;

use SL::DB::Bin;
use SL::DB::Warehouse;
use SL::Locale::String qw(t8);
use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(name_to_id div_tag select_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(
  wh_bin_select
);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);


sub wh_bin_select {
  my ($name, %attributes) = @_;

  my $div_name = $name;
  my $wh_name  = delete $attributes{wh_name}    || "${div_name}_wh";
  my $bin_name = delete $attributes{bin_name}   || "${div_name}_bin";
  my $div_id   = delete $attributes{id}         || name_to_id($name);
  my $wh_id    = delete $attributes{wh_id}      || name_to_id($wh_name)  || "${div_id}_wh";
  my $bin_id   = delete $attributes{bin_id}     || name_to_id($bin_name) || "${div_id}_bin";

  my $bin_default = delete $attributes{bin_default};
  my $wh_default  = delete $attributes{wh_default} || ($bin_default && SL::DB::Bin->new(id => $bin_default)->load->warehouse_id);
  my $with_empty  = delete $attributes{with_empty};

  my %wh_additional_condition = $wh_default ? (id => $wh_default) : undef;
  my $all_warehouses = SL::DB::Manager::Warehouse->get_all_sorted( where => [or => [invalid  => undef, invalid  => 0, %wh_additional_condition]]);
  my $all_bins       = $wh_default ? SL::DB::Warehouse->new(id => $wh_default)->load->bins_sorted_naturally
                     : $with_empty ? undef
                     : $all_warehouses->[0]->bins_sorted_naturally;

  my $data_validate  = delete $attributes{'data-validate'};
  my %div_attributes = (
    name => $div_name,
    id   => $div_id,
    %attributes
  );

  my %wh_attributes = (
    name                => $wh_name,
    id                  => $wh_id,
    default             => $wh_default,
    with_empty          => $with_empty,
    title_key           => 'description',
    onchange            => 'kivi.Warehouse.wh_changed(this);',
    'data-bin-dom-name' => $bin_name,
    'data-bin-dom-id'   => $bin_id,
    ('data-validate'    => $data_validate)x!!$data_validate,
    %attributes
  );

  my %bin_attributes = (
    name             => $bin_name,
    id               => $bin_id,
    default          => $bin_default,
    title_key        => 'description',
    ('data-validate' => $data_validate)x!!$data_validate,
    %attributes
  );

  $::request->layout->add_javascripts('kivi.Warehouse.js');

  div_tag(select_tag("${name}_wh", $all_warehouses, %wh_attributes) .
          select_tag($bin_name,    $all_bins,       %bin_attributes),
          %div_attributes);
}


1;
