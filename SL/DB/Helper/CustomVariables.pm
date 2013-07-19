package SL::DB::Helper::CustomVariables;

use strict;
use Carp;
use Data::Dumper;
use List::Util qw(first);

use constant META_CVARS => 'cvars_config';

sub import {
  my ($class, %params) = @_;
  my $caller_package = caller;

  # TODO: if module is empty, module overloading needs to take effect
  # certain stuff may have more than one overload, odr even more than one type
  defined $caller_package     or croak 'need to be included from a caller reference';

  $params{module}     ||= _calc_modules_from_overloads(%params) if $params{overloads};
  $params{sub_module} ||= '';
  $params{id}         ||= _get_primary_key_column($caller_package);

  $params{module} || $params{sub_module}  or croak 'need param module or sub_module';

  return unless save_meta_info($caller_package, %params);
  make_cvar_accessor($caller_package, %params);
  make_cvar_alias($caller_package, %params)      if $params{cvars_alias};
  make_cvar_by_configs($caller_package, %params);
  make_cvar_by_name($caller_package, %params);
}

sub save_meta_info {
  my ($caller_package, %params) = @_;

  my $meta = $caller_package->meta;
  return 0 if $meta->{META_CVARS()};

  $meta->{META_CVARS()} = \%params;

  return 1;
}

sub make_cvar_accessor {
  my ($caller_package, %params) = @_;

  my @module_filter = $params{module} ?
    ("config_id" => [ \"(SELECT custom_variable_configs.id FROM custom_variable_configs WHERE custom_variable_configs.module = '$params{module}')" ]) :
    ();

  $caller_package->meta->add_relationships(
    custom_variables => {
      type         => 'one to many',
      class        => 'SL::DB::CustomVariable',
      column_map   => { $params{id} => 'trans_id' },
      query_args   => [ sub_module => $params{sub_module}, @module_filter ],
    }
  );
}

sub make_cvar_alias {
  my ($caller_package) = @_;
  no strict 'refs';
  *{ $caller_package . '::cvars' } =  sub {
    goto &{ $caller_package . '::custom_variables' };
  }
}

# this is used for templates where you need to list every applicable config
# auto vivifies non existent cvar objects as necessary.
sub make_cvar_by_configs {
  my ($caller_package, %params) = @_;

  no strict 'refs';
  *{ $caller_package . '::cvars_by_config' } = sub {
    my ($self) = @_;
    @_ > 1 and croak "not an accessor";

    my $configs     = _all_configs(%params);
    my $cvars       = $self->custom_variables;
    my %cvars_by_config = map { $_->config_id => $_ } @$cvars;

    my @return = map(
      {
        if ( $cvars_by_config{$_->id} ) {
          $cvars_by_config{$_->id};
        }
        else {
          my $cvar = _new_cvar($self, %params, config => $_);
          $self->add_custom_variables($cvar);
          $cvar;
        }
      }
      @$configs
    );

    return \@return;
  }
}

# this is used for print templates where you need to refer to a variable by name
# TODO typically these were referred as prefix_'cvar'_name
sub make_cvar_by_name {
  my ($caller_package, %params) = @_;

  no strict 'refs';
  *{ $caller_package . '::cvar_by_name' } = sub {
    my ($self, $name) = @_;

    my $configs = _all_configs(%params);
    my $cvars   = $self->custom_variables;
    my $config  = first { $_->name eq $name } @$configs;

    croak "unknown cvar name $name" unless $config;

    my $cvar    = first { $_->config_id eq $config->id } @$cvars;

    if (!$cvar) {
      $cvar = _new_cvar($self, %params, config => $config);
      $self->add_custom_variables($cvar);
    }

    return $cvar;
  }
}

sub _all_configs {
  my (%params) = @_;

  require SL::DB::CustomVariableConfig;

  $params{module}
    ? SL::DB::Manager::CustomVariableConfig->get_all(query => [ module => $params{module} ])
    : SL::DB::Manager::CustomVariableConfig->get_all;
}

sub _overload_by_module {
  my ($module, %params) = @_;

  keys %{ $params{overloads} }; # reset each iterator
  while (my ($fk, $def) = each %{ $params{overloads} }) {
    return ($fk, $def->{class}) if $def->{module} eq $module;
  }

  croak "unknown overload, cannot resolve module $module";
}

sub _new_cvar {
  my ($self, %params) = @_;
  my $inherited_value;
  # check overloading first
  if ($params{sub_module}) {
    my ($fk, $class) = _overload_by_module($params{config}->module, %params);
    my $base_cvar = $class->new(id => $self->$fk)->load->cvar_by_name($params{config}->name);
    $inherited_value = $base_cvar->value;
  }

  my $cvar = SL::DB::CustomVariable->new(
    config     => $params{config},
    trans_id   => $self->${ \ $params{id} },
    sub_module => $params{sub_module},
  );
  # value needs config
  $inherited_value
   ? $cvar->value($inherited_value)
   : $cvar->value($params{config}->default_value);
  return $cvar;
}

sub _calc_modules_from_overloads {
  my (%params) = @_;
  my %modules;

  for my $def (values %{ $params{overloads} || {} }) {
    $modules{$def->{module}} = 1;
  }

  return [ keys %modules ];
}

sub _get_primary_key_column {
  my ($caller_package) = @_;
  my $meta             = $caller_package->meta;

  my $column_name;
  $column_name = $meta->{primary_key}->{columns}->[0] if $meta->{primary_key} && (ref($meta->{primary_key}->{columns}) eq 'ARRAY') && (1 == scalar(@{ $meta->{primary_key}->{columns} }));

  croak "Unable to retrieve primary key column name: meta information for package $caller_package not set up correctly" unless $column_name;

  return $column_name;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::Helper::CustomVariables - Mixin to provide custom variables relations

=head1 SYNOPSIS

  # use in a primary class
  use SL::DB::Helper::CustomVariables (
    module      => 'IC',
    cvars_alias => 1,
  );

  # use overloading in a secondary class
  use SL::DB::Helper::CustomVariables (
    sub_module  => 'orderitems',
    cvars_alias => 1,
    overloads   => {
      parts_id    => {
        class => 'SL::DB::Part',
        module => 'IC',
      }
    }
  );

=head1 DESCRIPTION

This module provides methods to deal with named custom variables. Two concepts are understood.

=head2 Primary CVar Classes

Primary classes are those that feature cvars for themselves. Currently those
are Part, Contact, Customer and Vendor. cvars for these will get saved directly
for the object.

=head2 Secondary CVar Classes

Secondary classes inherit their cvars from member relationships. This is built
so that orders can save a copy of the cvars of their parts, customers and the
like to be immutable later on.

Secondary classes may currently not have cvars of their own.

=head1 INSTALLED METHODS

=over 4

=item C<custom_variables [ CUSTOM_VARIABLES ]>

This is a Rose::DB::Object::Relationship accessor, generated for cvars. Use it
like any other OneToMany relationship.

=item C<cvars [ CUSTOM_VARIABLES ]>

Alias to C<custom_variables>. Will only be installed if C<cvars_alias> was
passed to import.

=item C<cvars_by_config>

Thi will return a list of CVars with the following changes over the standard accessor:

=over 4

=item *

The list will be returned in the sorted order of the configs.

=item *

For every config exactly one CVar will be returned.

=item *

If no cvar was found for a config, a new one will be vivified, set to the
correct config, module etc, and registered into the object.

=item *

Vivified cvars for secondary classes will first try to find their base object
and use that value. If no such value or cvar is found the default value from
configs applies.

=back

This is useful if you need to list every possible CVar, like in CRUD masks.

=item C<cvar_by_name NAME [ VALUE ]>

Returns the CVar object for this object which matches the given internal name.
Useful for print templates. If the requested cvar is not present, it will be
vivified with the same rules as in C<cvars_by_config>.

=back

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
