# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::SearchProfileSetting;

use strict;

use Carp;

use SL::DB::MetaSetup::SearchProfileSetting;
use SL::DB::Manager::SearchProfileSetting;

__PACKAGE__->meta->initialize;

sub parsed_value {
  my ($self, $value) = @_;

  croak "type is not set yet!" if !$self->type;

  if ($self->type eq 'boolean') {
    $self->boolean_value($value ? 1 : 0) if scalar(@_) > 1;
    return $self->boolean_value;
  }

  if ($self->type eq 'text') {
    $self->text_value($value) if scalar(@_) > 1;
    return $self->text_value;
  }

  if ($self->type eq 'date') {
    if (scalar(@_) > 1) {
      $value = !defined($value) ? undef
             : ref($value)      ? $value
             : $value eq ''     ? undef
             :                    DateTime->from_kivitendo($value);
      $self->date_value($value);
    }

    return undef if !defined $self->date_value;
    return $self->date_value->to_kivitendo;
  }

  if ($self->type eq 'integer') {
    $value = !defined($value) ? undef
           : $value eq ''     ? undef
           :                    $value;
    $self->integer_value($value) if scalar(@_) > 1;
    return $self->integer_value;
  }

  croak "unsupported field type '" . $self->type . "'";
}

1;
