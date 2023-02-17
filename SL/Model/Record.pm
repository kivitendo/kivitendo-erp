package SL::Model::Record;

use strict;

use Carp;

use SL::DB::Employee;
use SL::DB::Order;
use SL::DB::DeliveryOrder;
use SL::DB::Reclamation;
use SL::DB::RequirementSpecOrder;
use SL::DB::History;
use SL::DB::Invoice;
use SL::DB::Status;
use SL::DB::ValidityToken;
use SL::DB::Helper::TypeDataProxy;
use SL::DB::Order::TypeData qw(:types);
use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::Reclamation::TypeData qw(:types);

use SL::Util qw(trim);
use SL::Locale::String qw(t8);


sub update_after_new {
  my ($class, $new_record, $subtype, %flags) = @_;

  $new_record->transdate(DateTime->now_local());

  # build TypeDataProxy
  # TODO: remove when type is set in record and not infered form customer/vendor_id
  my $type_data_proxy = SL::DB::Helper::TypeDataProxy->new(ref $new_record, $subtype);
  $new_record->reqdate($type_data_proxy->defaults('reqdate'));

  return $new_record;
}

sub new_from_workflow {
  my ($class, $source_object, $target_type, $target_subtype, %flags) = @_;

  $flags{destination_type} = $target_subtype;
  my %defaults_flags = (
    no_linked_records => 0,
  );
  %flags = (%defaults_flags, %flags);

  my $target_object = ${target_type}->new_from($source_object, %flags);
  return $target_object;
}

sub new_from_workflow_multi {
  my ($class, $source_objects, $target_type, $target_subtype, %flags) = @_;

  my $target_object = ${target_type}->new_from_multi($source_objects, %flags);

  return $target_object;
}

sub increment_subversion {
  my ($class, $record, %flags) = @_;

  $record->increment_version_number if $record->type_data->features('subversions');

  return;
}

sub delete {
  my ($class, $record, %flags) = @_;

  my $errors = [];
  my $db = $record->db;

  $db->with_transaction(
    sub {
      my @spoolfiles = grep { $_ } map { $_->spoolfile } @{ SL::DB::Manager::Status->get_all(where => [ trans_id => $record->id ]) };
      $record->delete;
      my $spool = $::lx_office_conf{paths}->{spool};
      unlink map { "$spool/$_" } @spoolfiles if $spool;

      _save_history($record,'DELETED');

      1;
  }) || push(@{$errors}, $db->error);

    die t8("Errors delete records:") . "\n" . join("\n", @{$errors}) . "\n" if scalar @{$errors};
}

sub _get_history_snumbers {
  my ($record) = @_;

  my $number_type = $record->type_data->properties( 'nr_key');
  my $snumbers    = $number_type . '_' . $record->$number_type;

  return $snumbers;
}

sub _save_history {
  my ($record, $addition) = @_;

  SL::DB::History->new(
    trans_id    => $record->id,
    employee_id => SL::DB::Manager::Employee->current->id,
    what_done   => $record->type,
    snumbers    => _get_history_snumbers($record),
    addition    => $addition,
  )->save;
}

sub save {
  my ($class, $record, %params) = @_;

  $record->calculate_prices_and_taxes() if $record->type_data->features('price_tax');

  foreach my $item (@{ $record->items }) {
    # autovivify all cvars that are not in the form (cvars_by_config can do it).
    # workaround to pre-parse number-cvars (parse_custom_variable_values does not parse number values).
    foreach my $var (@{ $item->cvars_by_config }) {
      $var->unparsed_value($::form->parse_amount(\%::myconfig, $var->{__unparsed_value})) if ($var->config->type eq 'number' && exists($var->{__unparsed_value}));
    }
    $item->parse_custom_variable_values;
  }

  SL::DB->client->with_transaction(sub {
    # validity token
    my $validity_token;
    if (my $validity_token_specs = $params{with_validity_token}) {
      if (!defined $validity_token_specs->{scope} || !exists $validity_token_specs->{token}) {
        croak ('you must provide a hash ref "with_validity_token" with the keys "scope" and "token" if you want the token to be handled');
      }

      if (!$record->id) {
        $validity_token = SL::DB::Manager::ValidityToken->fetch_valid_token(
          scope => $validity_token_specs->{scope},
          token => $validity_token_specs->{token},
        );

        die $::locale->text('The form is not valid anymore.') if !$validity_token;
      }
    }

    # delete custom shipto if it is to be deleted or if it is empty
    if ($params{delete_custom_shipto}) { # flag?
      if ($record->custom_shipto) {
        $record->custom_shipto->delete if $record->custom_shipto->shipto_id;
        $record->custom_shipto(undef);
      }
    }

    $_->delete for @{ $params{items_to_delete} || [] };

    $record->save(cascade => 1);

    if ($params{objects_to_close} && @{$params{objects_to_close}}) {
      $_->update_attributes(closed => 1) for @{$params{objects_to_close}};
    }

    # link records for requirement specs
    if (my $converted_from_ids = $params{link_requirement_specs_linking_to_created_from_objects}) {
      _link_requirement_specs_linking_to_created_from_objects($record, $converted_from_ids);
    }

    if ($params{set_project_in_linked_requirement_specs}) { # flag?
      _set_project_in_linked_requirement_specs($record);
    }

    _save_history($record, 'SAVED');

    $validity_token->delete if $validity_token;

    1;
  });
}

# Todo: put this into SL::DB::Order?
sub _link_requirement_specs_linking_to_created_from_objects {
  my ($record, $converted_from_oe_ids) = @_;

  return unless  $converted_from_oe_ids;
  return unless @$converted_from_oe_ids;

  my $rs_orders = SL::DB::Manager::RequirementSpecOrder->get_all(where => [ order_id => $converted_from_oe_ids ]);
  foreach my $rs_order (@{ $rs_orders }) {
    SL::DB::RequirementSpecOrder->new(
      order_id            => $record->id,
      requirement_spec_id => $rs_order->requirement_spec_id,
      version_id          => $rs_order->version_id,
    )->save;
  }
}

sub _set_project_in_linked_requirement_specs {
  my ($record) = @_;

  return unless $record->globalproject_id;

  my $rs_orders = SL::DB::Manager::RequirementSpecOrder->get_all(where => [ order_id => $record->id ]);
  foreach my $rs_order (@{ $rs_orders }) {
    next if $rs_order->requirement_spec->project_id == $record->globalproject_id;

    $rs_order->requirement_spec->update_attributes(project_id => $record->globalproject_id);
  }
}

sub clone_for_save_as_new {
  my ($class, $saved_record, $changed_record, %params) = @_;

  # changed_record
  my %new_attrs;
  # Lets assign a new number if the user hasn't changed the previous one.
  # If it has been changed manually then use it as-is.
  $new_attrs{record_number}    = (trim($changed_record->record_number) eq $saved_record->record_number)
                        ? ''
                        : trim($changed_record->record_number);

  # Clear transdate unless changed
  $new_attrs{transdate} = ($changed_record->transdate == $saved_record->transdate)
                        ? DateTime->today_local
                        : $changed_record->transdate;

  # Set new reqdate unless changed if it is enabled in client config
  if ($changed_record->reqdate == $saved_record->reqdate) {
      $new_attrs{reqdate} = $changed_record->type_data->defaults('reqdate');
  }

  # Update employee
  $new_attrs{employee}  = SL::DB::Manager::Employee->current;


  my $new_record = SL::Model::Record->new_from_workflow($changed_record, ref($changed_record), $saved_record->type, no_linked_records => 1, attributes => \%new_attrs);

  # return: nichts
  # fehler: exception
  return $new_record;
}


1;

__END__

=encoding utf-8

=head1 NAME

SL::Model::Record - shared computations for orders (Order), delivery orders (DeliveryOrder), invoices (Invoice) and reclamations (Reclamation)

=head1 DESCRIPTION

This module contains shared behaviour among the main record object types. A given record needs to be already parsed into a Rose object.
All records are treated agnostically and the underlying class needs to implement a type_data call to query for differing behaviour.

Currently the following types and subtypes are supported:

=over 4

=item * L<SL::DB::Order>

=over 4

=item * C<sales_order>

=item * C<purchase_order>

=item * C<sales_quotation>

=item * C<purchase_quotation>

=back

=item * L<SL::DB::DeliveryOrder>

=over 4

=item * C<sales_delivery_order>

=item * C<purchase_delivery_order>

=item * C<supplier_delivery_order>

=item * C<rma_delivery_order>

=back

=item * L<SL::DB::Reclamation>

=over 4

=item * C<sales_reclamation>

=item * C<purchase_reclamation>

=back

=back

The base record types need to implement a type_data call that can be queried
for various type informations.

Invoices are not supported as of now, but are planned for the future.

The old delivery order C<sales_delivery_order> and C<purchase_delivery_order> must be implemented
in the new DeliveryOrder Controller

=head1 METHODS

=over 4

=item C<update_after_new>

Creates a new record_object by record_type and sub_type.
Sets reqdate and transdate if required by type_data.

Returns the record object.

=item C<new_from_workflow>

Expects source_object, target_type, target_subtype and can have flags.
Creates a new record from a target_subtype by target_type->new_from(source_record).
Set default flag no_link_record to false.

Throws an error if the target_type doesn't exist.

Returns the new record object.

=item C<new_from_workflow_multi>

Expects an arrayref with source_objects, target_type, target_subtype and can have flags.
Creates a new record object from one or more source objects.

Returns the new record object.

=item C<increment_subversion>

Only for orders.

Increments the record's subversion number.

TODO: check type data if this is allowed/supported for this record and trow exception or error

=item C<delete>

Expects a record to delete.
Deletes the whole record and puts an entry in the history.
Cleans up the spool directory.
Dies and throws an error if there is a dberror.

TODO: check status order once old deliveryorder (do) is implemented.

=item C<save>

Expects a record to be saved and params to handle stuff like validity_token, custom_shipto,
items_to_delete, close objects and requirement_specs.

=over 2

=item * L<params:>

=over 4

=item * C<with_validity_token → scope>

=item * C<delete custom shipto if empty>

=item * C<items_to_delete>

=item * C<objects_to_close>

=item * C<link_requirement_specs_linking_to_created_from_objects>

=item * C<set_project_in_linked_requirement_specs>

=back

Sets an entry in the history.

Dies and throws an error when there is an error.

=back

=back

=over 4

=item C<clone_for_save_as_new>

Expects the saved record and the record to be changed.

Sets the actual employee.

Also sets a new transdate, new reqdate and an empty recordnumber if it wasn't already changed in the old record.

=item C<_save_history>

Expects a record and an addition reason for the history (SAVED,DELETED,...)

=item C<_get_history_snumbers>

Expects a record, returns snumber for the history entry.

=back

=head1 BUGS

None yet. :)

=head1 AUTHORS

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

Werner Hahn E<lt>wh@futureworldsearch.netE<gt>

...

=cut
