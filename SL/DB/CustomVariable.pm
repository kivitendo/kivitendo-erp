# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::CustomVariable;

use strict;

use List::MoreUtils qw(any);

use SL::DB::MetaSetup::CustomVariable;

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub unparsed_value {
  my ($self, $new) = @_;

  $self->{__unparsed_value} = $new;
}

sub _ensure_config {
  my ($self) = @_;

  return $self->config if  defined $self->{config};
  return undef         if !defined $self->config_id;

  no warnings 'once';
  return $::request->cache('config_by_id')->{$self->config_id} //= SL::DB::CustomVariableConfig->new(id => $self->config_id)->load;
}

sub parse_value {
  my ($self) = @_;
  my $type   = $self->_ensure_config->type;

  return unless exists $self->{__unparsed_value};

  my $unparsed = delete $self->{__unparsed_value};

  if ($type =~ m{^(?:customer|vendor|part)}) {
    return $self->number_value(!defined($unparsed) ? undef
                               : (any { ref($unparsed) eq $_ } qw(SL::DB::Customer SL::DB::Vendor SL::DB::Part)) ? $unparsed->id
                               : $unparsed * 1);
  }

  if ($type =~ m{^(?:number)}) {
    return $self->number_value(!defined($unparsed) ? undef : $::form->parse_amount(\%::myconfig, $unparsed));
  }

  if ($type =~ m{^(?:bool)}) {
    return $self->bool_value(defined($unparsed) ? !!$unparsed : undef);
  }

  if ($type =~ m{^(?:date|timestamp)}) {
    return $self->timestamp_value(!defined($unparsed) ? undef : ref($unparsed) eq 'DateTime' ? $unparsed->clone : DateTime->from_kivitendo($unparsed));
  }

  if ($type =~ m{^(?:multiselect)}) {
    return $self->text_value(!defined($unparsed) || 'ARRAY' ne ref $unparsed ? undef : '##' . join('##', @$unparsed) . '##');
  }

  # text, textfield, htmlfield and select
  $self->text_value($unparsed);
}

sub _set_value {
  my ($self, $value) = @_;

  my $type = $self->_ensure_config->type;

  my $method = 'text_value';

  if ($type =~ m{^(?:customer|vendor|part|number)}) {
    $method = 'number_value';
    $value *= 1 if defined $value;

  } elsif ($type =~ m{^(?:bool)}) {
    $method = 'bool_value';

  } elsif ($type =~ m{^(?:date|timestamp)}) {
    $method = 'timestamp_value';
    $value  = undef if !$value;

  } elsif ($type =~ m{^(?:multiselect)}) {
    $value = 'ARRAY' ne ref $value ? undef : '##' . join('##', @$value) . '##';
  }

  $self->$method($value);
}

sub value {
  my $self = $_[0];
  my $type = $self->_ensure_config->type;

  if (scalar(@_) > 1) {
    $self->_set_value($_[1]);
    @_ = ($self);
  }

  goto &bool_value      if $type eq 'bool';
  goto &timestamp_value if $type eq 'timestamp';

  if ($type eq 'number') {
    return defined($self->number_value) ? $self->number_value * 1 : undef;
  }

  if ( $type =~ m{^(?:customer|vendor|part)$}) {
    my $class = "SL::DB::" . ucfirst($type);
    eval "require $class";

    return defined($self->number_value) ? int($self->number_value) : undef;

  } elsif ( $type eq 'date' ) {
    return $self->timestamp_value ? $self->timestamp_value->clone->truncate(to => 'day') : undef;
  }

  goto &text_value; # text, textfield, htmlfield and select
}

sub value_as_text {
  my $self = $_[0];
  my $cfg  = $self->_ensure_config;
  my $type = $cfg->type;

  die 'not an accessor' if @_ > 1;

  if ($type eq 'bool') {
    return $self->bool_value ? $::locale->text('Yes') : $::locale->text('No');

  } elsif ($type =~ m{^(?:timestamp|date)}) {
    return '' if !$self->timestamp_value;
    return $::locale->reformat_date( { dateformat => 'yy-mm-dd' }, $self->timestamp_value->ymd, $::myconfig{dateformat});

  } elsif ($type eq 'number') {
    return $::form->format_amount(\%::myconfig, $self->number_value, $cfg->processed_options->{PRECISION});

  } elsif ( $type =~ m{^(?:customer|vendor|part)$}) {
    my $class = "SL::DB::" . ucfirst($type);
    eval "require $class";
    my $object =  $class->_get_manager_class->find_by(id => int($self->number_value));
    return $object ? $object->displayable_name : '';
  }

  goto &text_value; # text, textfield, htmlfield and select
}

sub value_normalized {
  my $self = $_[0];
  my $cfg  = $self->_ensure_config;
  my $type = $cfg->type;

  die 'not an accessor' if @_ > 1;

  if ($type =~ m{^(?:timestamp|date)}) {
    return '' if !$self->timestamp_value;
    return $self->timestamp_value->to_kivitendo;

  } elsif ( $type =~ m{^(?:customer|vendor|part)$}) {
    my $class = "SL::DB::" . ucfirst($type);
    eval "require $class";
    my $object =  $class->_get_manager_class->find_by(id => int($self->number_value));
    return $object;

  } elsif ( $type eq 'multiselect' ) {
    return $self->text_value ? [ split /##/, ($self->text_value =~ s/^##|##$//gr) ] : [];

  } elsif ($type eq 'number') {
    return $::form->format_amount(\%::myconfig, $self->number_value, $cfg->processed_options->{PRECISION});
  }

  goto &value;
}

sub is_valid {
  my ($self) = @_;

  require SL::DB::CustomVariableValidity;

  # only base level custom variables can be invalid. ovverloaded ones could potentially clash on trans_id, so disallow them
  return 1 if $self->sub_module;

  $self->{is_valid} //= do {
    my $query = [config_id => $self->config_id, trans_id => $self->trans_id];
    (SL::DB::Manager::CustomVariableValidity->get_all_count(query => $query) == 0) ? 1 : 0;
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::CustomVariable - database object for custom variables

See also C<SL::DB::Helper::CustomVariables>.

=head1 FUNCTIONS

=head2 C<unparsed_value>

This object method should be used to store the unparsed user input
from a form.
These unparsed values are parsed by C<parse_value>.

=head2 C<value>

This method can be used as getter and setter and dispatches to
the type depending methods/fields of the CVar.

This accessor does not parse the values. The should be given in
database representation and returned in database representation.

=head2 C<value_as_text>

Returns a textual representation of the value of the CVar.

=head2 C<value_normalized>

Returns an object representation of the value of the CVar for
types that store objects (part/customer/vendor/date/timestamp).
It also handles the multiselect type and returns an array ref
for that. The number type is formatted.
For other types it goes to C<value>.
These values can be used to set the field in a form.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>,
Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>
Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
