package SL::Presenter::Part;

use strict;

use SL::DB::Part;
use SL::DB::PartClassification;
use SL::Locale::String qw(t8);
use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(
  part_picker part select_classification classification_abbreviation
  type_abbreviation separate_abbreviation typeclass_abbreviation
);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use Carp;

sub part {
  my ($part, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=Part/edit&part.id=' . escape($part->id) . '">',
    escape($part->partnumber),
    $params{no_link} ? '' : '</a>',
  );

  is_escaped($text);
}

sub part_picker {
  my ($name, $value, %params) = @_;

  $value = SL::DB::Manager::Part->find_by(id => $value) if $value && !ref $value;
  my $id = $params{id} || name_to_id($name);

  my @classes = $params{class} ? ($params{class}) : ();
  push @classes, 'part_autocomplete';

  my $ret =
    input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => "@classes", type => 'hidden', id => $id,
      'data-part-picker-data' => JSON::to_json(\%params),
    ) .
    input_tag("", ref $value ? $value->displayable_name : '', id => "${id}_name", %params);

  $::request->layout->add_javascripts('kivi.Part.js');
  $::request->presenter->need_reinit_widgets($id);

  html_tag('span', $ret, class => 'part_picker');
}

sub picker { goto &part_picker }

#
# shortcut for article type
#
sub type_abbreviation {
  my ($part_type) = @_;
  return $::locale->text('Assembly (typeabbreviation)')   if $part_type eq 'assembly';
  return $::locale->text('Part (typeabbreviation)')       if $part_type eq 'part';
  return $::locale->text('Assortment (typeabbreviation)') if $part_type eq 'assortment';
  return $::locale->text('Service (typeabbreviation)');
}

#
# Translations for Abbreviations:
#
# $::locale->text('None (typeabbreviation)')
# $::locale->text('Purchase (typeabbreviation)')
# $::locale->text('Sales (typeabbreviation)')
# $::locale->text('Merchandise (typeabbreviation)')
# $::locale->text('Production (typeabbreviation)')
#
# and for descriptions
# $::locale->text('Purchase')
# $::locale->text('Sales')
# $::locale->text('Merchandise')
# $::locale->text('Production')

#
# shortcut for article type
#
sub classification_abbreviation {
  my ($id) = @_;
  SL::DB::Manager::PartClassification->cache_all();
  my $obj = SL::DB::PartClassification->load_cached($id);
  $obj && $obj->abbreviation ? t8($obj->abbreviation) : '';
}

sub typeclass_abbreviation {
  my ($part) = @_;
  return '' if !$part || !$part->isa('SL::DB::Part');
  return type_abbreviation($part->part_type) . classification_abbreviation($part->classification_id);
}

#
# shortcut for article type
#
sub separate_abbreviation {
  my ($id) = @_;
  SL::DB::Manager::PartClassification->cache_all();
  my $obj = SL::DB::PartClassification->load_cached($id);
  $obj && $obj->abbreviation && $obj->report_separate ? t8($obj->abbreviation) : '';
}

#
# generate selection tag
#
sub select_classification {
  my ($name, %attributes) = @_;

  $attributes{value_key} = 'id';
  $attributes{title_key} = 'description';

  my $classification_type_filter = delete $attributes{type} // [];

  my $collection = SL::DB::Manager::PartClassification->get_all_sorted( where => $classification_type_filter );
  $_->description($::locale->text($_->description)) for @{ $collection };
  select_tag( $name, $collection, %attributes );
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Presenter::Part - Part related presenter stuff

=head1 SYNOPSIS

  # Create an html link for editing/opening a part/service/assembly
  my $object = SL::DB::Manager::Part->get_first;
  my $html   = SL::Presenter->get->part($object, display => 'inline');

see also L<SL::Presenter>

=head1 DESCRIPTION

see L<SL::Presenter>

=head1 FUNCTIONS

=over 2

=item C<part, $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the part object C<$object>

C<%params> can include:

=over 4

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the part's name linked
to the corresponding 'edit' action.

=back

=back

=over 2

=item C<classification_abbreviation $classification_id>

Returns the shortcut of the classification

=back

=over 2

=item C<separate_abbreviation $classification_id>

Returns the shortcut of the classification if the classification has the separate flag set.

=back

=over 2

=item C<select_classification $name,%params>

Returns an HTML select tag with all available classifications.

C<%params> can include:

=over 4

=item * default

The id of the selected item.

=back

=back

=over 2

=item C<part_picker $name, $value, %params>

All-in-one picker widget for parts. The name will be both id and name
of the resulting hidden C<id> input field (but the ID can be
overwritten with C<$params{id}>).

An additional dummy input will be generated which is used to find
parts. For a detailed description of its behaviour, see section
C<PART PICKER SPECIFICATION>.

C<$value> can be a parts id or a C<Rose::DB:Object> instance.

If C<%params> contains C<part_type> only parts of this type will be used
for autocompletion. You may comma separate multiple types as in
C<part,assembly>.

If C<%params> contains C<unit> only parts with this unit will be used
for autocompletion. You may comma separate multiple units as in
C<h,min>.

If C<%params> contains C<convertible_unit> only parts with a unit
that's convertible to unit will be used for autocompletion.

Obsolete parts will by default not be displayed for selection. However they are
accepted as default values and can persist during updates. As with other
selectors though, they are not selectable once overridden.

C<part_picker> will register it's javascript for inclusion in the next header
rendering. If you write a standard controller that only calls C<render> once, it
will just work. In case the header is generated in a different render call
(multiple blocks, ajax, old C<bin/mozilla> style controllers) you need to
include C<kivi.Part.js> yourself.

On pressing <enter> the picker will try to commit the current selection,
resulting in one of the following events, whose corresponding callbacks can be
set in C<params.actions>:

=over 4

=item * C<commit_one>

If exactly one element matches the input, the internal id will be set to this
id, the internal state will be set to C<PICKED> and the C<change> event on the
picker will be fired. Additionally, if C<params> contains C<fat_set_item> a
special event C<set_item:PartPicker> will be fired which is guaranteed to
contain a complete JSON representation of the part.

After that the action C<commit_one> will be executed, which defaults to
clicking a button with id C<update_button> for backward compatibility reasons.

=item * C<commit_many>

If more than one element matches the input, the internal state will be set to
undefined.

After that the action C<commit_one> will be executed, which defaults to
opening a popup dialog for graphical interaction. If C<params> contains
C<multiple> an alternative popup will be opened, allowing multiple items to be
selected. Note however that this requires an additional callback
C<set_multi_items> to work.

=item * C<commit_none>

If no element matches the input, the internal state will be set to undefined.

If an action for C<commit_none> exists, it will be called with the picker
object and current term. The caller can then implement creation of new parts.

=back

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

Should not be constrained to exact matches

=item *

Must be atomic

=item *

Action should be overridable

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

An internal status of the part picker, indicating whether id input and dummy
input are consistent. After leaving the dummy input the part picker must
place itself in a consistent status.

=item 6

A clickable icon (popup trigger) attached to the dummy input, which triggers the popup layer.

=back

=head1 BUGS

None atm :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>

=cut
