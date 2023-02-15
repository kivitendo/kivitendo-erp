package SL::Model::Record;

use strict;

use Carp;

use SL::DB::Order;
use SL::DB::DeliveryOrder;
use SL::DB::Reclamation;
use SL::DB::History;
use SL::DB::Invoice;
use SL::DB::Status;
use SL::DB::ValidityToken;

use SL::Util qw(trim);
use SL::Locale::String qw(t8);

sub new {
  my ($class, $target_type, %flags) = @_;

  # target_type: der angeforderte typ
  # flags: zusätzliche informationen zu der behanldung (soll    )

  # (aus add) neues record mit vorbereitenden sachen wie transdate/reqdate
  #
  # rückgabe: neues objekt
  # fehlerfall: exception
}

sub new_from_workflow {
  my ($class, $source_object, $target_subtype, %flags) = @_;

  # source: ein quellobjekt
  # target type: sollte ein subtype sein. wer das hier implementiert, sollte auch eine subtype registratur bauen in der man subtypes nachschlagen kann
  # flags: welche extra behandlungen sollen gemacht werden, z.B. record_links setzen

  # (muss prüfen ob diese umwandlung korrekt ist)
  # muss das entsprechende new_from in den objekten selber benutzen
  # und dann evtl nachbearbeitung machen (die bisher im controller stand)

  # new_from_workflow: (aus add_from_*) workflow umwandlung von bestehenden records

  # fehlerfall: exception aus unterliegendem code bubblen oder neue exception werfen
  # rückgabe: das neue objekt

  $flags{destination_type} = $target_subtype;
  my %defaults_flags = (
    no_linked_records => 0,
  );
  %flags = (%flags, %defaults_flags);

  my %subtype_to_type = (
    # Order
    "request_quotation" => "SL::DB::Order",
    "purchase_order"    => "SL::DB::Order",
    "sales_quotation"   => "SL::DB::Order",
    "sales_order"       => "SL::DB::Order",
    # DeliveryOrder
    "sales_delivery_order"    => "SL::DB::DeliveryOrder",
    "purchase_delivery_order" => "SL::DB::DeliveryOrder",
    "rma_delivery_order"      => "SL::DB::DeliveryOrder",
    "supplier_delivery_order" => "SL::DB::DeliveryOrder",
    # Reclamation
    "sales_reclamation"    => "SL::DB::Reclamation",
    "purchase_reclamation" => "SL::DB::Reclamation",
  );
  my $target_type = $subtype_to_type{$target_subtype};
  unless ($target_type) {
    croak("Conversion not supported to $target_subtype");
  }

  my $target_object = ${target_type}->new_from($source_object, %flags);
  return $target_object;
}

sub new_from_workflow_multi {
  my ($class, $source_objects, $target_subtype, %flags) = @_;
  # source: ein arrayref von quellobjekten.
  # target type: sollte ein subtype sein. wer das hier implementiert, sollte auch eine subtype registratur bauen in der man subtypes nachschlagen kann
  # flags: welche extra behandlungen sollen gemacht werden, z.B. record_links setzen

  # muss prüfen ob diese umwandlung korrekt ist
  # muss das entsprechende new_from_multi in den objekten selber benutzen
  # und dann evtl nachbearbeitung machen (die bisher im controller stand)

  # new_from_workflow_multi: (aus action_edit_collective) workflow umwandlung von bestehenden records

  # fehlerfall: exception aus unterliegendem code bubblen oder neue exception werfen
  # rückgabe: das neue objekt

  my %subtype_to_type = (
    # Order
    "sales_order" => "SL::DB::Order",
  );
  my $target_type = $subtype_to_type{$target_subtype};
  unless ($target_type) {
    croak("Conversion not supported to $target_subtype");
  }

  my $target_object = ${target_type}->new_from_multi($source_objects, %flags);

  return $target_object;
}

# im Moment nur bei Aufträgen
sub increment_subversion {
  my ($class, $record, %flags) = @_;

  # erhöht die version des auftrags
  # setzt die neue auftragsnummer
  # legt OrderVersion objekt an
  # speichert
  #
  # return - nichts
  # fehlerfall: exception

  # Todo: check type data if this is allowed/supported for this record

  $record->increment_version_number;

  return;
}

sub delete {
  my ($class, $record, %params) = @_;

  my $errors = [];
  my $db = $record->db;

  $db->with_transaction(
    sub {
      my @spoolfiles = grep { $_ } map { $_->spoolfile } @{ SL::DB::Manager::Status->get_all(where => [ trans_id => $record->id ]) };
      $record->delete;
      my $spool = $::lx_office_conf{paths}->{spool};
      unlink map { "$spool/$_" } @spoolfiles if $spool;

      _save_history($record,'DELETED', %{$params{history}});

      1;
  }) || push(@{$errors}, $db->error);

    croak t8("Errors delete records:") . "\n" . join("\n", @{$errors}) . "\n" if scalar @{$errors};
  # das hier sollte der code sein der in sub delete aus den controllern liegt
  # nicht nur record->delete, sondern auch andere elemente aufräumen
  # spool aufräumen
  # status aufräumen
  # history eintrag
  #
  # return: nichts
  # fehler: exception
}

sub _save_history {
  my ($record, $addition, %history) = @_;

  SL::DB::History->new(
    trans_id    => $record->id,
    employee_id => SL::DB::Manager::Employee->current->id,
    what_done   => $record->type,
    snumbers    => $history{snumbers},
    addition    => $addition,
  )->save;
}

sub save {
  my ($class, $record, %params) = @_;

  # record: das zu speichernde objekt
  # params:
  #   - with_validity_token -> scope
  #   - delete custom shipto if empty
  #   - item_ids_to_delete
  #   - order version behandlung


  # muss linked_records aus converted_from_* erzeugen -> verschieben in after_save hooks
  # wenn aus quotation erstellt, muss beim speichern das angebot geschlossen werden
  # wenn aus lieferschein erstellt muss beim speichern delivered setzen (wenn in config aktiviert)
  # muss auch link requirement_specs machen (was tut das?)
  # set project in linked requirementspecs (nur aufträge -> flag)
  #
  # history einträge erstellen

  # rückgabe: nichts
  # fehler: exception

  $record->calculate_prices_and_taxes() if $params{calculate_prices_and_taxes}; # flag or type data?

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
      if (!defined $validity_token_specs->{scope} || !defined $validity_token_specs->{token}) {
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

    # # link records
    # if (@converted_from_oe_ids) {
    #   $self->link_requirement_specs_linking_to_created_from_objects(@converted_from_oe_ids);
    # }

    # $self->set_project_in_linked_requirement_specs if $self->order->globalproject_id;

    _save_history($record, 'SAVED', %{$params{history}});

    $validity_token->delete if $validity_token;

    1;
  });
}

sub update_for_save_as_new {
  my ($class, $saved_record, $changed_record, %params) = @_;

  # der übergebene beleg wurde mit new_from erstellt und muss nachbearbeitet werden:
  # - transadte, reqdate müssen überschrieben werden
  # - number muss überschrieben werden
  # - employee auf aktuellen setzen

  my $type_info = {
    # order
    sales_quotation => {
      get_new_reqdate => sub {
        if ($::instance_conf->get_reqdate_on) {
          return DateTime->today_local->next_workday(
            extra_days => $::instance_conf->get_reqdate_interval());
        } else {
          return '';
        }
      },
    },
    sales_order => {
      get_new_reqdate => sub {
        if ($::instance_conf->get_deliverydate_on) {
          return DateTime->today_local->next_workday(
            extra_days => $::instance_conf->get_delivery_date_interval());
        } else {
          return '';
        }
      },
    },
    request_quotation => {
      get_new_reqdate => sub { DateTime->today_local->next_workday(extra_days => 1); },
    },
    purchase_order => {
      get_new_reqdate => sub { DateTime->today_local->next_workday(extra_days => 1); },
    },
    # delivery_order
    rma_delivery_order => {
      get_new_reqdate => sub {
        DateTime->today_local->next_workday(extra_days => 1);
      },
    },
    sales_delivery_order => {
      get_new_reqdate => sub {
        DateTime->today_local->next_workday(extra_days => 1);
      },
    },
    supplier_delivery_order => {
      get_new_reqdate => sub {
        DateTime->today_local->next_workday(extra_days => 1);
      },
    },
    purchase_delivery_order => {
      get_new_reqdate => sub {
        DateTime->today_local->next_workday(extra_days => 1);
      },
    },
    # reclamation
    sales_reclamation => {
      get_new_reqdate => sub {
        '';
      },
    },
    purchase_reclamation => {
      get_new_reqdate => sub {
        '';
      },
    },
  };

  # changed_record
  my %new_attrs;
  # Lets assign a new number if the user hasn't changed the previous one.
  # If it has been changed manually then use it as-is.
  $new_attrs{number}    = (trim($changed_record->number) eq $saved_record->number)
                        ? ''
                        : trim($changed_record->number);

  # Clear transdate unless changed
  $new_attrs{transdate} = ($changed_record->transdate == $saved_record->transdate)
                        ? DateTime->today_local
                        : $changed_record->transdate;

  # Set new reqdate unless changed if it is enabled in client config
  if ($changed_record->reqdate == $saved_record->reqdate) {
      $new_attrs{reqdate} = $type_info->{$saved_record->type}->{get_new_reqdate}->();
  }

  # Update employee
  $new_attrs{employee}  = SL::DB::Manager::Employee->current;


  my $new_record = SL::Model::Record->new_from_workflow($changed_record, $saved_record->type, no_linked_records => 1, attributes => \%new_attrs);

  # return: nichts
  # fehler: exception
  return $new_record;
}


1;

__END__

=encoding utf-8

=head1 NAME

SL::Model::Record - shared computations for orders (Order), delivery orders (DeliveryOrder), invoices (Invoice) and reclamations (Reclamation)

=head1 SYNOPSIS



=head1 DESCRIPTION

=over 4

=item C<increment_subversion>

Increments the record's subversion number.

=item C<delete>

Deletes the whole record and puts an entry in the history.
Expects a record with %params for history params{history} = \%history

=item C<_save_history>

Expects a record for id, addition for text (SAVED,...) and %history{snumber}

=back

=head1 BUGS

None yet. :)

=head1 AUTHORS

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>
Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>
...

=cut
