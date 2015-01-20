# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::CustomVariable;

use strict;
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

  if ($type =~ m{^(?:customer|vendor|part|bool|number)}) {
    return $self->number_value(defined($unparsed) ? $unparsed * 1 : undef);
  }

  if ($type =~ m{^(?:date|timestamp)}) {
    return $self->timestamp_value(defined($unparsed) ? DateTime->from_kivitendo($unparsed) : undef);
  }

  # text, textfield, select
  $self->text_value($unparsed);
}

sub value {
  my $self = $_[0];
  my $type = $self->_ensure_config->type;

  if (scalar(@_) > 1) {
    $self->unparsed_value($_[1]);
    $self->parse_value;
  }

  goto &bool_value      if $type eq 'bool';
  goto &timestamp_value if $type eq 'timestamp';
  goto &number_value    if $type eq 'number';

  if ( $type eq 'customer' ) {
    require SL::DB::Customer;

    my $id = int($self->number_value);
    return $id ? SL::DB::Customer->new(id => $id)->load() : undef;
  } elsif ( $type eq 'vendor' ) {
    require SL::DB::Vendor;

    my $id = int($self->number_value);
    return $id ? SL::DB::Vendor->new(id => $id)->load() : undef;
  } elsif ( $type eq 'part' ) {
    require SL::DB::Part;

    my $id = int($self->number_value);
    return $id ? SL::DB::Part->new(id => $id)->load() : undef;
  }

  goto &text_value; # text, textfield, date and select
}

sub value_as_text {
  my $self = $_[0];
  my $cfg  = $self->_ensure_config;
  my $type = $cfg->type;

  die 'not an accessor' if @_ > 1;

  if ($type eq 'boolean') {
    return $self->bool_value ? $::locale->text('Yes') : $::locale->text('No');
  } elsif ($type eq 'timestamp') {
    return $::locale->reformat_date( { dateformat => 'yy-mm-dd' }, $self->timestamp_value->ymd, $::myconfig{dateformat});
  } elsif ($type eq 'number') {
    return $::form->format_amount(\%::myconfig, $self->number_value, $cfg->processed_options->{PRECISION});
  } elsif ( $type eq 'customer' ) {
    require SL::DB::Customer;

    my $id = int($self->number_value);
    my $customer =  $id ? SL::DB::Customer->new(id => $id)->load() : 0;
    return $customer ? $customer->name : '';
  } elsif ( $type eq 'vendor' ) {
    require SL::DB::Vendor;

    my $id = int($self->number_value);
    my $vendor =  $id ? SL::DB::Vendor->new(id => $id)->load() : 0;
    return $vendor ? $vendor->name : '';
  } elsif ( $type eq 'part' ) {
    require SL::DB::Part;

    my $id = int($self->number_value);
    my $part = $id ? SL::DB::Part->new(id => $id)->load() : 0;
    return $part ? $part->description : '';
  }

  goto &text_value; # text, textfield, date and select
}

sub is_valid {
  my ($self) = @_;

  require SL::DB::CustomVariableValidity;

  my $query = [config_id => $self->config_id, trans_id => $self->trans_id];
  return (SL::DB::Manager::CustomVariableValidity->get_all_count(query => $query) == 0) ? 1 : 0;
}

1;
