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
use SL::DB::Part;
use SL::DB::Status;
use SL::DB::Translation;
use SL::DB::ValidityToken;
use SL::DB::Order::TypeData qw(:types);
use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::Reclamation::TypeData qw(:types);
use SL::DB::Helper::Record qw(get_class_from_type);

use SL::Util qw(trim);
use SL::Locale::String qw(t8);
use SL::PriceSource;


sub update_after_new {
  my ($class, $new_record, %flags) = @_;

  $new_record->transdate(DateTime->now_local());

  my $default_reqdate = $new_record->type_data->defaults('reqdate');
  $new_record->reqdate($default_reqdate);

  return $new_record;
}

sub update_after_customer_vendor_change {
  my ($class, $record) = @_;
  my $new_customervendor = $record->customervendor;

  $record->$_($new_customervendor->$_) for (qw(
    taxzone_id payment_id delivery_term_id currency_id language_id
    ));

  $record->intnotes($new_customervendor->notes);

  return $record if !$record->is_sales;
  if ($record->is_sales) {
    my $new_customer = $new_customervendor;
    $record->salesman_id($new_customer->salesman_id
      || SL::DB::Manager::Employee->current->id);
    $record->taxincluded(defined($new_customer->taxincluded_checked)
      ? $new_customer->taxincluded_checked
      : $::myconfig{taxincluded_checked});
    if ($record->type_data->features('price_tax')) {
      my $address = $new_customer->default_billing_address;;
      $record->billing_address_id($address ? $address->id : undef);
    }
  }

  return $record;
}

sub get_record {
  my ($class, $type, $id) = @_;
  my $record_class = get_class_from_type($type);
  return $record_class->new(id => $id)->load;
}

sub new_from_workflow {
  my ($class, $source_object, $target_type, %flags) = @_;

  $flags{destination_type} = $target_type;
  my %defaults_flags = (
    no_linked_records => 0,
  );
  %flags = (%defaults_flags, %flags);

  my $target_class = get_class_from_type($target_type);
  my $target_object = ${target_class}->new_from($source_object, %flags);
  return $target_object;
}

sub new_from_workflow_multi {
  my ($class, $source_objects, $target_type, %flags) = @_;

  my $target_class = get_class_from_type($target_type);
  my $target_object = ${target_class}->new_from_multi($source_objects, %flags);

  return $target_object;
}

sub increment_subversion {
  my ($class, $record, %flags) = @_;

  if ($record->type_data->features('subversions')) {
    $record->increment_version_number;
  } else {
    die t8('Subversions are not supported or disabled for this record type.');
  }

  return;
}

sub get_best_price_and_discount_source {
  my ($class, $record, $item, %flags) = @_;

  my $ignore_given = !!$flags{ignore_given};

  my $price_source = SL::PriceSource->new(record_item => $item, record => $record);

  my $price_src;
  if ( $item->part->is_assortment ) {
    # add assortment items with price 0, as the components carry the price
    $price_src = $price_source->price_from_source("");
    $price_src->price(0);
  } elsif (!$ignore_given && defined $item->sellprice) {
    $price_src = $price_source->price_from_source("");
    $price_src->price($item->sellprice);
  } else {
    $price_src = $price_source->best_price
               ? $price_source->best_price
               : $price_source->price_from_source("");

    $price_src->price($::form->round_amount($price_src->price / $record->exchangerate, 5)) if $record->can('exchangerate') && $record->exchangerate;
    $price_src->price(0) if !$price_source->best_price;
  }

  my $discount_src;
  if (!$ignore_given && defined $item->discount) {
    $discount_src = $price_source->discount_from_source("");
    $discount_src->discount($item->discount);
  } else {
    $discount_src = $price_source->best_discount
                  ? $price_source->best_discount
                  : $price_source->discount_from_source("");
    $discount_src->discount(0) if !$price_source->best_discount;
  }

  return ($price_src, $discount_src);
}

sub get_part_texts {
  my ($class, $part_or_id, $language_or_id, %defaults) = @_;

  my $part        = ref($part_or_id)     ? $part_or_id         : SL::DB::Part->load_cached($part_or_id);
  my $language_id = ref($language_or_id) ? $language_or_id->id : $language_or_id;
  my $texts       = {
    description     => $defaults{description}     // $part->description,
    longdescription => $defaults{longdescription} // $part->notes,
  };

  return $texts unless $language_id;

  my $translation = SL::DB::Manager::Translation->get_first(
    where => [
      parts_id    => $part->id,
      language_id => $language_id,
    ]);

  $texts->{description}     = $translation->translation     if $translation && $translation->translation;
  $texts->{longdescription} = $translation->longdescription if $translation && $translation->longdescription;

  return $texts;
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

  die t8("Errors while deleting record:") . "\n" . join("\n", @{$errors}) . "\n" if scalar @{$errors};
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

  # Test for no items
  if (scalar @{$record->items} == 0
      && !grep { $record->record_type eq $_ }
         @{$::instance_conf->get_allowed_documents_with_no_positions() || []}) {
    die t8('The action you\'ve chosen has not been executed because the document does not contain any item yet.');
  }

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
  }) or die t8('Saving the record failed: #1', SL::DB->client->error);
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


  my $new_record = SL::Model::Record->new_from_workflow($changed_record, $saved_record->type, no_linked_records => 1, attributes => \%new_attrs);

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

Currently the following classes and types are supported:

=over 4

=item * L<SL::DB::Order>

=over 4

=item * C<sales_order>

=item * C<purchase_order>

=item * C<sales_quotation>

=item * C<purchase_quotation>

=item * C<purchase_quotation_intake>

=item * C<sales_order_intake>

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

     +-------+              type_data()      +-------------------------+
     | Order | ---------------proxy------->  | SL::DB::Order::TypeData |
     +-------+                               +-------------------------+

     +---------------+      type_data()      +---------------------------------+
     | DeliveryOrder |  ------proxy------->  | SL::DB::DeliveryOrder::TypeData |
     +---------------+                       +---------------------------------+

     ...

Any Record that implements the necessary type_data callbacks can be used as a
record in here .

Invoices are not supported as of now, but are planned for the future.

The old delivery order C<sales_delivery_order> and C<purchase_delivery_order>
must be implemented in the new DeliveryOrder Controller

=head1 METHODS

=over 4

=item C<update_after_new>

Updates a record_object corresponding to type_data.
Sets reqdate and transdate.

Returns the record object.

=item C<update_after_customer_vendor_change>

Updates a record_object corresponding to customer/vendor and type_data.
Sets taxzone_id, payment_id, delivery_term_id, currency_id, language_id and
intnotes to customer/vendor. For sales records salesman and taxincluded is set.
Also for sales record with the feature 'price_tax' the billing address is updated.

Returns the record object.

=item C<new_from_workflow>

Expects source_object, target_type and can have flags.
Creates a new record from a by target_class->new_from(source_record).
Set default flag no_link_record to false.

Throws an error if the target_type doesn't exist.

Returns the new record object.

=item C<new_from_workflow_multi>

Expects an arrayref with source_objects, target_type and can have flags.
Creates a new record object from one or more source objects.

Returns the new record object.

=item C<increment_subversion>

Only for orders.

Increments the record's subversion number.

=item C<get_best_price_and_discount_source>

Get the best price and discount source for an item. You have
to pass the record and the item.

If the flag C<ignore_given> is not set and a price or discount already exists
for this item, these will be used. This means, that the price source and
discount source are set to empty and price of the price source is set to
the existing price and/or the discount of the discount source is set to
the existing discount.

If the flag C<ignore_given> is set, the best price and discount source
is determined via C<SL::PriceSource> and a given price or discount in the
item will be ignored. This can be used to get an default price/discount
that can be displayed to the user even if a price/discount is already
entered.

Returns an reference to an array where the first element is the best
price source and the second element is the best discount source.

=item C<get_part_texts>

Get the description and longdescription of a part with or without translation.

Expects a part object or it's id as first parameter (mandatory) and a language
object or it's id as second parameter (optional).

You can give optional default values for the texts as a hash with the keys
C<description> and C<longdescription>. The defaults are returned if no
translation for one text can be found.

Returns a hasf ref with the keys C<description> and C<longdescription> and
the texts as values.

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

=head1 FURTHER WORK

=over 4

=item *

Handling of price sources and prices in controllers

=item *

Handling of shippedqty calculations in controllers

=item *

Autovivification of unparsed cvar configs is still in parsing code

=item *

sellprice changed handling

=back


The traits currently encoded in the type data classes should also be extended to cover:

=over 4

=item *

PeriodicInvoices

=item *

Exchangerates

=item *

Payments for invoices

=back

In later stages the following things should be implemented:

=over 4

=item *

Further encapsulate the linking logic for creating linked records.

=item *

Better tests for auto-close of quotations and auto-delivered of delivery orders on save. Best to move those into post-save hooks as well.

=item *

More tests of workflow related conversions from frontend (current tests are mostly at the SL::Model::Record boundary).

=item *

More tests for error handling in controllers. I.e. if the given recordnumber is kept.

=back

=head1 AUTHORS

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

Werner Hahn E<lt>wh@futureworldsearch.netE<gt>

...

=cut
