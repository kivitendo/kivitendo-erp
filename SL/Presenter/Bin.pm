package SL::Presenter::Bin;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag);
use SL::DB::Bin;
use SL::DB::Warehouse;
use List::Util qw(any);

use Exporter qw(import);
our @EXPORT_OK = qw(bin_picker warehousepicker);

use Carp;

sub warehousepicker {
  my ($name, $curr, %params) = @_;

  my $all = delete $params{objects} // SL::DB::Manager::Warehouse->get_all();
  unshift @$all, $curr if $curr && !any { $_->id == $curr } @$all;

  select_tag($name, $all, %params, default_sub => sub { $curr && $_[0]->id == $curr }, title_key => 'description');
}

sub bin_picker {
  my ($name, $value,%params) = @_;

  $value      = SL::DB::Manager::Bin->find_by(id => $value) if $value && !ref $value;
  my $id      = delete($params{id}) || name_to_id($name);
  my @classes = $params{class} ? ($params{class}) : ();
  push @classes, 'bin_autocomplete';

  my $ret =
    input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => "@classes", type => 'hidden', id => $id) .
    join('', map { $params{$_} ? input_tag("", delete $params{$_}, id => "${id}_${_}", type => 'hidden') : '' } qw(warehouse_field)) .
    input_tag("", ref $value ? $value->displayable_name : '', id => "${id}_name", %params);

  $::request->layout->add_javascripts('autocomplete_bin.js');
  $::request->presenter->need_reinit_widgets($id);

  html_tag('span', $ret, class => 'bin_picker');
}

sub picker { goto &bin_picker };

1;
