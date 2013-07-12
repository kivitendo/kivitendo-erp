package SL::Presenter::Part;

use strict;

use SL::DB::Part;

use Exporter qw(import);
our @EXPORT = qw(part_picker);

sub part_picker {
  my ($self, $name, $value, %params) = @_;

  $value = SL::DB::Manager::Part->find_by(id => $value) if !ref $value;
  my $id = delete($params{id}) || $self->name_to_id($name);

  my $ret =
    $self->input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => 'part_autocomplete', type => 'hidden', id => $id) .
    join('', map { $params{$_} ? $self->input_tag("", delete $params{$_}, id => "${id}_${_}", type => 'hidden') : '' } qw(column type unit)) .
    $self->input_tag("", (ref $value && $value->can('description')) ? $value->description : '', id => "${id}_name", %params);

  $self->html_tag('span', $ret, class => 'part_picker');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Presenter::Part - Part lelated presenter stuff

=head1 SYNOPSIS

see L<SL::Presenter>

=head1 DESCRIPTION

see L<SL::Presenter>

=head1 FUNCTIONS

=over 4

=item C<part_picker $name, $value, %params>

All-in-one picker widget for parts. The name will be both id and name
of the resulting hidden C<id> input field (but the ID can be
overwritten with C<$params{id}>).

An additional dummy input will be generated which is used to find
parts. For a detailed description of it's behaviour, see section
C<PART PICKER SPECIFICATION>.

C<$value> can be a parts id or a C<Rose::DB:Object> instance.

If C<%params> contains C<type> only parts of this type will be used
for autocompletion. You may comma separate multiple types as in
C<part,assembly>.

If C<%params> contains C<unit> only parts with this unit will be used
for autocompletion. You may comma separate multiple units as in
C<h,min>.

Obsolete parts will by default not displayed for selection. However they are
accepted as default values and can persist during updates. As with other
selectors though, they are not selectable once overridden.

Currently you must include C<js/autocomplete_part.js> in your controller, the
presenter can not do this from the template.

=back

=head1 BUGS

=over 4

=item *

Picker icons aren't displayed with css menu, because the spritemap is not loaded.

=back

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
