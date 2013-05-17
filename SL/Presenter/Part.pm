package SL::Presenter::Part;

use strict;

use Exporter qw(import);
our @EXPORT = qw(part_picker);

sub part_picker {
  my ($self, $name, $value, %params) = @_;
  my $name_e    = $self->escape($name);

  my $ret =
    $self->input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => 'part_autocomplete', type => 'hidden') .
    $self->input_tag("", delete $params{type}, id => $self->name_to_id("$name_e\_type"), type => 'hidden') .
    $self->input_tag("", (ref $value && $value->can('description')) ? $value->description : '', id => $self->name_to_id("$name_e\_name"), %params) .
    $self->input_tag("", delete $params{column}, id => $self->name_to_id("$name_e\_column"), type => 'hidden');

  $self->html_tag('span', $ret, class => 'part_picker');
}

1;
