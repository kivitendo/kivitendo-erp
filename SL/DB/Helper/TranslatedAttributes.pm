package SL::DB::Helper::TranslatedAttributes;

use strict;

use SL::DB::GenericTranslation;

use parent qw(Exporter);
our @EXPORT = qw(translated_attribute save_attribute_translation);

use Carp;

sub translated_attribute {
  my ($self, $attribute, $language_id, $verbatim) = @_;

  $language_id        = _check($self, $attribute, $language_id, $verbatim);
  my $translation_obj = _find_translation($self, $attribute, $language_id, 0);
  my $translation     = $translation_obj ? $translation_obj->translation : '';

  return $translation if $verbatim || $translation;

  $translation_obj = _find_translation($self, $attribute, undef, 0);
  $translation     = $translation_obj ? $translation_obj->translation : '';

  return $translation || $self->$attribute;
}

sub save_attribute_translation {
  my ($self, $attribute, $language_id, $value) = @_;

  $language_id = _check($self, $attribute, $language_id);

  return _find_translation($self, $attribute, $language_id, 1)->update_attributes(translation => $value);
}

sub _check {
  my ($self, $attribute, $language_id, $verbatim) = @_;

  croak "Invalid attribute '${attribute}'" unless $self->can($attribute);
  croak "Object has not been saved yet"    unless $self->id || $verbatim;

  return (ref($language_id) eq 'SL::DB::Language' ? $language_id->id : $language_id) || undef;
}

sub _find_translation {
  my ($self, $attribute, $language_id, $new_if_not_found) = @_;

  my %params = (language_id      => $language_id,
                translation_type => ref($self). '/' . $attribute,
                translation_id   => $self->id);

  return SL::DB::Manager::GenericTranslation->find_by(%params) || ($new_if_not_found ? SL::DB::GenericTranslation->new(%params) : undef);
}

1;

__END__

=encoding utf8

=head1 NAME

SL::DB::Helper::TranslatedAttributes - Mixin for retrieving and saving
translations for certain model attributes in the table
I<generic_translations>

=head1 SYNOPSIS

Declaration:

  package SL::DB::SomeObject;
  use SL::DB::Helper::Translated;

Usage:

  my $object   = SL::DB::SomeObject->new(id => $::form->{id})->load;
  my $language = SL::DB::Manager::Language->find_by(description => 'Deutsch');
  print "Untranslated name: " . $object->name . " translated: " . $object->translated_attribute('name', $language) . "\n";

  print "Now saving new value\n";
  my $save_ok = $object->save_attribute_translation('name', $language, 'Lieferung frei Haus');

=head1 FUNCTIONS

=over 4

=item C<translated_attribute $attribute, $language_id, $verbatim>

Returns the translation stored for the attribute C<$attribute> and the
language C<$language_id> (either an ID or an instance of
L<SL::DB::Language>).

If C<$verbatim> is falsish and either no translation exists for
C<$language_id> or if C<$language_id> is undefined then the default
translation is looked up.

If C<$verbatim> is falsish and neither translation exists then the
value of C<< $self->$attribute >> is returned.

Requires that C<$self> has a primary ID column named C<id> and that
the object has been saved.

=item C<save_attribute_translation $attribute, $language_id, $value>

Saves the translation C<$value> for the attribute C<$attribute> and
the language C<$language_id> (either an ID or an instance of
L<SL::DB::Language>).

If C<$language_id> is undefined then the default translation will be
saved.

Requires that C<$self> has a primary ID column named C<id> and that
the object has been saved.

Returns the same value as C<save>.

=back

=head1 EXPORTS

This mixin exports the functions L</translated_attribute> and
L</save_attribute_translation>.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
