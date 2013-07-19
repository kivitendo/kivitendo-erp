package SL::Presenter::Part;

use strict;

use SL::DB::Part;

use Exporter qw(import);
our @EXPORT = qw(part_picker);

sub part_picker {
  my ($self, $name, $value, %params) = @_;

  $value = SL::DB::Manager::Part->find_by(id => $value) if $value && !ref $value;
  my $id = delete($params{id}) || $self->name_to_id($name);

  my $ret =
    $self->input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => 'part_autocomplete', type => 'hidden', id => $id) .
    join('', map { $params{$_} ? $self->input_tag("", delete $params{$_}, id => "${id}_${_}", type => 'hidden') : '' } qw(column type unit convertible_unit)) .
    $self->input_tag("", (ref $value && $value->can('description')) ? $value->description : '', id => "${id}_name", %params);

  $::request->presenter->need_reinit_widgets($id);

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

If C<%params> contains C<convertible_unit> only parts with a unit
that's convertible to unit will be used for autocompletion.

Obsolete parts will by default not displayed for selection. However they are
accepted as default values and can persist during updates. As with other
selectors though, they are not selectable once overridden.

Currently you must include C<js/autocomplete_part.js> in your controller, the
presenter can not do this from the template.

=back

=head1 PART PICKER SPECIFICATION

The following list of design goals were applied:

=over 4

=item *

Parts should not be perceived by the user as distinct inputs of partnumber and
description but as a single object

=item *

Easy to use without documentation for novice users

=item *

Fast to use with keyboard for experienced users

=item *

Possible to use without any keyboard interaction for mouse (or touchscreen)
users

=item *

Must not leave the current page in event of ambiguity (cf. current select_item
mechanism)

=item *

Should be useable with hand scanners or similar alternative keyboard devices

=item *

Should not require a feedback/check loop in the common case

=item *

Should not be constraint to exact matches

=back

The implementation consists of the following parts which will be referenced later:

=over 4

=item 1

A hidden input (id input), used to hold the id of the selected part. The only
input that gets submitted

=item 2

An input (dummy input) containing a description of the currently selected part,
also used by the user to search for parts

=item 3

A jquery.autocomplete mechanism attached to the dummy field

=item 4

A popup layer for both feedback and input of additional data in case of
ambiguity.

=item 5

An internal status of the part picker, indicating wether id input and dummy
input are consistent. After leaving the dummy input the part picker must
place itself in a consistent status.

=item 6

A clickable icon (popup trigger) attached to the dummy input, which triggers the popup layer.

=back

=head1 BUGS

None atm :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
