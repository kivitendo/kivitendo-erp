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

  my %div_attributes = (
    name => $div_name,
    id   => $div_id,
    %attributes
  );

  my %wh_attributes = (
    id                  => $wh_id,
    default             => $wh_default,
    with_empty          => $with_empty,
    title_key           => 'description',
    onchange            => 'kivi.Warehouse.wh_changed(this);',
    'data-bin-dom-name' => $bin_name,
    'data-bin-dom-id'   => $bin_id,
    %attributes
  );

  my %bin_attributes = (
    id        => $bin_id,
    default   => $bin_default,
    title_key => 'description',
    %attributes
  );

  $::request->layout->add_javascripts('kivi.Warehouse.js');

  div_tag(select_tag($wh_name, $all_warehouses, %wh_attributes) .
          select_tag($bin_name,    $all_bins,       %bin_attributes),
          %div_attributes);
}


1;


__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Warehouse - Presenter module for warehouse and bin objects

=head1 SYNOPSIS

In template code use:

  [% USE P %]
  [% P.warehouse.wh_bin_select('wh') %]
  with_empty: [% P.warehouse.wh_bin_select('wh2', with_empty=1) %]

=head1 FUNCTIONS

=over 4

=item C<wh_bin_select $name %attributes>

Returns a rendered version of select tags surrounded by a div tag for selecting
a warehouse and a bin. The surrounding div tag gets the name C<$name>.

The presenter takes care of updating the bin selection (via js) when the
warehose selection is changed (see also
L<SL::Controller::Warehouse::action_wh_bin_select_update_bins> and
L<js/kivi.Warehouse.js>).

All valid warehouses are presented for selection.

Remaining C<%attributes> not listed here are passed to the
div and select tag presenters.

C<%attributes> can include:

=over 2

=item * wh_name

The name for the warehouse select tag. It defaults the name
of the div with '_wh' added.

=item * bin_name

The name for the bin select tag.  It defaults the name
of the div with '_bin' added.

=item * id

The id of the div tag. It is derived from the div's name if not given.

=item * wh_id

The id for the warehouse select tag. It defaults the id
of the div with '_wh' added.

=item * bin_id

The id for the bin select tag. It defaults the id
of the div with '_bin' added.

=item * wh_default

An id of a warehouse object to be preselected. It defaults to the warehouse
a given default bin belongs to.

=item * bin_default

An id of a bin object to be preselected.

=item * with_empty

Over an empty selection for the warehouse if this is truish.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
