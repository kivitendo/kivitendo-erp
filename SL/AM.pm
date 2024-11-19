#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================
#
# Administration module
#    Chart of Accounts
#    template routines
#    preferences
#
#======================================================================

package AM;

use Carp;
use Data::Dumper;
use Encode;
use List::MoreUtils qw(any);
use SL::DBUtils;
use SL::DB::AuthUser;
use SL::DB::Default;
use SL::DB::Employee;
use SL::DB::Chart;
use SL::DB::Customer;
use SL::DB::Part;
use SL::DB::Vendor;
use SL::DB;
use SL::GenericTranslations;
use SL::Helper::UserPreferences::DisplayPreferences;
use SL::Helper::UserPreferences::PositionsScrollbar;
use SL::Helper::UserPreferences::PartPickerSearch;
use SL::Helper::UserPreferences::TimeRecording;
use SL::Helper::UserPreferences::UpdatePositions;
use SL::Helper::UserPreferences::ItemInputPosition;

use strict;

sub get_account {
  $main::lxdebug->enter_sub();

  # fetch chart-related data and set form fields
  # get_account is called by add_account in am.pl
  # always sets $form->{TAXKEY} and default_accounts
  # loads chart data when $form->{id} is passed

  my ($self, $myconfig, $form) = @_;

  # get default accounts
  map { $form->{$_} = $::instance_conf->{$_} } qw(inventory_accno_id income_accno_id expense_accno_id);

  require SL::DB::Tax;
  my $taxes = SL::DB::Manager::Tax->get_all( with_objects => ['chart'] , sort_by => 'taxkey' );
  $form->{TAXKEY} = [];
  foreach my $tk ( @{$taxes} ) {
    push @{ $form->{TAXKEY} },  { id          => $tk->id,
                                  chart_accno => $tk->chart_id ? $tk->chart->accno : undef,
                                  taxkey      => $tk->taxkey,
                                  tax         => $tk->id . '--' . $tk->taxkey,
                                  rate        => $tk->rate
                                };
  };

  if ($form->{id}) {

    my $chart_obj = SL::DB::Manager::Chart->find_by(id => $form->{id}) || die "Can't open chart";

    my @chart_fields = qw(accno description charttype category link pos_bilanz
                          pos_eur pos_er new_chart_id valid_from pos_bwa datevautomatik
                          invalid);
    foreach my $cf ( @chart_fields ) {
      $form->{"$cf"} = $chart_obj->$cf;
    }

    my $active_taxkey = $chart_obj->get_active_taxkey;
    if ($active_taxkey) {
      $form->{$_}  = $active_taxkey->$_ foreach qw(taxkey_id pos_ustva tax_id startdate);
      $form->{tax} = $active_taxkey->tax_id . '--' . $active_taxkey->taxkey_id;
    }

    # check if there are any transactions for this chart
    $form->{orphaned} = $chart_obj->has_transaction ? 0 : 1;

    # check if new account is active
    # The old sql query was broken since at least 2006 and always returned 0
    $form->{new_chart_valid} = $chart_obj->new_chart_valid;

    # get the taxkeys of the account
    $form->{ACCOUNT_TAXKEYS} = [];
    foreach my $taxkey ( sort { $b->startdate <=> $a->startdate } @{ $chart_obj->taxkeys } ) {
      push @{ $form->{ACCOUNT_TAXKEYS} }, { id             => $taxkey->id,
                                            chart_id       => $taxkey->chart_id,
                                            tax_id         => $taxkey->tax_id,
                                            taxkey_id      => $taxkey->taxkey_id,
                                            pos_ustva      => $taxkey->pos_ustva,
                                            startdate      => $taxkey->startdate->to_kivitendo,
                                            taxdescription => $taxkey->tax->taxdescription,
                                            rate           => $taxkey->tax->rate,
                                            accno          => defined $taxkey->tax->chart_id ? $taxkey->tax->chart->accno : undef,
                                          };
    }

    # get new accounts (Folgekonto). Find all charts with the same link
    $form->{NEWACCOUNT} = $chart_obj->db->dbh->selectall_arrayref('select id, accno,description from chart where link = ? and id != ? order by accno', {Slice => {}}, $chart_obj->link, $form->{id});

  } else { # set to orphaned for new charts, so chart_type can be changed (needed by $AccountIsPosted)
    $form->{orphaned} = 1;
  };

  $main::lxdebug->leave_sub();
}

sub save_account {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_save_account, $self, $myconfig, $form);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _save_account {
  # TODO: it should be forbidden to change an account to a heading if there
  # have been bookings to this account in the past

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  for (qw(AR_include_in_dropdown AP_include_in_dropdown summary_account)) {
    $form->{$form->{$_}} = $form->{$_} if $form->{$_};
  }

  # sanity check, can't have AR with AR_...
  if ($form->{AR} || $form->{AP} || $form->{IC}) {
    if (any { $form->{$_} } qw(AR_amount AR_tax AR_paid AP_amount AP_tax AP_paid IC_sale IC_cogs IC_taxpart IC_income IC_expense IC_taxservice)) {
      $form->error($::locale->text('It is not allowed that a summary account occurs in a drop-down menu!'));
    }
  }

  my @link_order = qw(AR AR_amount AR_tax AR_paid AP AP_amount AP_tax AP_paid IC IC_sale IC_cogs IC_taxpart IC_income IC_expense IC_taxservice);
  $form->{link} = join ':', grep $_, map $form->{$_}, @link_order;

  # strip blanks from accno
  map { $form->{$_} =~ s/ //g; } qw(accno);

  # collapse multiple (horizontal) whitespace in chart description (Ticket 148)
  map { $form->{$_} =~ s/\h+/ /g } qw(description);

  my ($query, $sth);

  if ($form->{id} eq "NULL") {
    $form->{id} = "";
  }

  $query = '
    SELECT accno
    FROM chart
    WHERE accno = ?';

  my @values = ($form->{accno});

  if ( $form->{id} ) {
    $query .= ' AND NOT id = ?';
    push(@values, $form->{id});
  }

  my ($accno) = selectrow_query($form, $dbh, $query, @values);

  if ($accno) {
    $form->error($::locale->text('Account number not unique!'));
  }


  if (!$form->{id} || $form->{id} eq "") {
    $query = qq|SELECT nextval('id')|;
    ($form->{"id"}) = selectrow_query($form, $dbh, $query);
    $query = qq|INSERT INTO chart (id, accno, link) VALUES (?, ?, ?)|;
    do_query($form, $dbh, $query, $form->{"id"}, $form->{"accno"}, '');
  }

  @values = ();


  if ($form->{id}) {

    # if charttype is heading make sure certain values are empty
    # specifically, if charttype is changed from an existing account, empty the
    # fields unnecessary for headings, so that e.g. heading doesn't appear in
    # drop-down menues due to still having a valid "link" entry

    if ( $form->{charttype} eq 'H' ) {
      $form->{link} = '';
      $form->{pos_bwa} = '';
      $form->{pos_bilanz} = '';
      $form->{pos_eur} = '';
      $form->{new_chart_id} = '';
      $form->{valid_from} = '';
    };

    $query = qq|UPDATE chart SET
                  accno = ?,
                  description = ?,
                  charttype = ?,
                  category = ?,
                  link = ?,
                  pos_bwa   = ?,
                  pos_bilanz = ?,
                  pos_eur = ?,
                  pos_er = ?,
                  new_chart_id = ?,
                  valid_from = ?,
                  datevautomatik = ?,
                  invalid = ?
                WHERE id = ?|;

    @values = (
                  $form->{accno},
                  $form->{description},
                  $form->{charttype},
                  $form->{category},
                  $form->{link},
                  conv_i($form->{pos_bwa}),
                  conv_i($form->{pos_bilanz}),
                  conv_i($form->{pos_eur}),
                  conv_i($form->{pos_er}),
                  conv_i($form->{new_chart_id}),
                  conv_date($form->{valid_from}),
                  ($form->{datevautomatik} eq 'T') ? 'true':'false',
                  $form->{invalid} ? 'true' : 'false',
                $form->{id},
    );


  }

  do_query($form, $dbh, $query, @values);

  #Save Taxkeys

  my @taxkeys = ();

  my $MAX_TRIES = 10; # Maximum count of taxkeys in form
  my $tk_count;

  READTAXKEYS:
  for $tk_count (0 .. $MAX_TRIES) {

    # Loop control

    # Check if the account already exists, else cancel

    print(STDERR "Keine Taxkeys weil ID =: $form->{id}\n");

    last READTAXKEYS if ( $form->{'id'} == 0);

    # check if there is a startdate
    if ( $form->{"taxkey_startdate_$tk_count"} eq '' ) {
      $tk_count++;
      next READTAXKEYS;
    }

    # Add valid taxkeys into the array
    push @taxkeys ,
      {
        id        => ($form->{"taxkey_id_$tk_count"} eq 'NEW') ? conv_i('') : conv_i($form->{"taxkey_id_$tk_count"}),
        tax_id    => conv_i($form->{"taxkey_tax_$tk_count"}),
        startdate => conv_date($form->{"taxkey_startdate_$tk_count"}),
        chart_id  => conv_i($form->{"id"}),
        pos_ustva => conv_i($form->{"taxkey_pos_ustva_$tk_count"}),
        delete    => ( $form->{"taxkey_del_$tk_count"} eq 'delete' ) ? '1' : '',
      };

    $tk_count++;
  }

  TAXKEY:
  for my $j (0 .. $#taxkeys){
    if ( defined $taxkeys[$j]{'id'} ){
      # delete Taxkey?

      if ($taxkeys[$j]{'delete'}){
        $query = qq{
          DELETE FROM taxkeys WHERE id = ?
        };

        @values = ($taxkeys[$j]{'id'});

        do_query($form, $dbh, $query, @values);

        next TAXKEY;
      }

      # UPDATE Taxkey

      $query = qq{
        UPDATE taxkeys
        SET taxkey_id = (SELECT taxkey FROM tax WHERE tax.id = ?),
            chart_id  = ?,
            tax_id    = ?,
            pos_ustva = ?,
            startdate = ?
        WHERE id = ?
      };
      @values = (
        $taxkeys[$j]{'tax_id'},
        $taxkeys[$j]{'chart_id'},
        $taxkeys[$j]{'tax_id'},
        $taxkeys[$j]{'pos_ustva'},
        $taxkeys[$j]{'startdate'},
        $taxkeys[$j]{'id'},
      );
      do_query($form, $dbh, $query, @values);
    }
    else {
      # INSERT Taxkey

      $query = qq{
        INSERT INTO taxkeys (
          taxkey_id,
          chart_id,
          tax_id,
          pos_ustva,
          startdate
        )
        VALUES ((SELECT taxkey FROM tax WHERE tax.id = ?), ?, ?, ?, ?)
      };
      @values = (
        $taxkeys[$j]{'tax_id'},
        $taxkeys[$j]{'chart_id'},
        $taxkeys[$j]{'tax_id'},
        $taxkeys[$j]{'pos_ustva'},
        $taxkeys[$j]{'startdate'},
      );

      do_query($form, $dbh, $query, @values);
    }

  }

  # Update chart.taxkey_id to the latest from taxkeys for this chart.
  $query = <<SQL;
    UPDATE chart
    SET taxkey_id = (
      SELECT taxkey_id
      FROM taxkeys
      WHERE taxkeys.chart_id = chart.id
      ORDER BY startdate DESC
      LIMIT 1
    )
    WHERE id = ?
SQL

  do_query($form, $dbh, $query, $form->{id});

  return 1;
}

sub delete_account {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_delete_account, $self, $myconfig, $form);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _delete_account {
  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  my $query = qq|SELECT count(*) FROM acc_trans a
                 WHERE a.chart_id = ?|;
  my ($count) = selectrow_query($form, $dbh, $query, $form->{id});

  if ($count) {
    return;
  }

  $query = qq|DELETE FROM tax
              WHERE chart_id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  # delete account taxkeys
  $query = qq|DELETE FROM taxkeys
              WHERE chart_id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  # delete chart of account record
  # last step delete chart, because we have a constraint
  # to taxkeys
  $query = qq|DELETE FROM chart
              WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  return 1;
}

sub get_language_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $id) = @_;

  my $dbh = SL::DB->client->dbh;

  my $query =
    "SELECT template_code, " .
    "  output_numberformat, output_dateformat, output_longdates " .
    "FROM language WHERE id = ?";
  my @res = selectrow_query($form, $dbh, $query, $id);

  $main::lxdebug->leave_sub();

  return @res;
}

sub prepare_template_filename {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my ($filename, $display_filename);

  $filename = $form->{formname};

  if ($form->{language}) {
    my ($id, $template_code) = split(/--/, $form->{language});
    $filename .= "_${template_code}";
  }

  if ($form->{printer}) {
    my ($id, $template_code) = split(/--/, $form->{printer});
    $filename .= "_${template_code}";
  }

  $filename .= "." . ($form->{format} eq "html" ? "html" : "tex");
  if ($form->{"formname"} =~ m|\.\.| || $form->{"formname"} =~ m|^/|) {
    $filename =~ s|.*/||;
  }
  $display_filename = $filename;
  $filename = SL::DB::Default->get->templates . "/$filename";

  $main::lxdebug->leave_sub();

  return ($filename, $display_filename);
}


sub load_template {
  $main::lxdebug->enter_sub();

  my ($self, $filename) = @_;

  my ($content, $lines) = ("", 0);

  local *TEMPLATE;

  if (open(TEMPLATE, $filename)) {
    while (<TEMPLATE>) {
      $content .= $_;
      $lines++;
    }
    close(TEMPLATE);
  }

  $content = Encode::decode('utf-8-strict', $content);

  $main::lxdebug->leave_sub();

  return ($content, $lines);
}

sub save_template {
  $main::lxdebug->enter_sub();

  my ($self, $filename, $content) = @_;

  local *TEMPLATE;

  my $error = "";

  if (open(TEMPLATE, ">", $filename)) {
    $content = Encode::encode('utf-8-strict', $content);
    $content =~ s/\r\n/\n/g;
    print(TEMPLATE $content);
    close(TEMPLATE);
  } else {
    $error = $!;
  }

  $main::lxdebug->leave_sub();

  return $error;
}

sub displayable_name_specs_by_module {
  +{
     'SL::DB::Customer' => {
       specs => SL::DB::Customer->displayable_name_specs,
       prefs => SL::DB::Customer->displayable_name_prefs,
     },
     'SL::DB::Vendor' => {
       specs => SL::DB::Vendor->displayable_name_specs,
       prefs => SL::DB::Vendor->displayable_name_prefs,
     },
     'SL::DB::Part' => {
       specs => SL::DB::Part->displayable_name_specs,
       prefs => SL::DB::Part->displayable_name_prefs,
     },
  };
}

sub positions_scrollbar_height {
  SL::Helper::UserPreferences::PositionsScrollbar->new()->get_height();
}

sub purchase_search_makemodel {
  SL::Helper::UserPreferences::PartPickerSearch->new()->get_purchase_search_makemodel();
}

sub sales_search_customer_partnumber {
  SL::Helper::UserPreferences::PartPickerSearch->new()->get_sales_search_customer_partnumber();
}

sub positions_show_update_button {
  SL::Helper::UserPreferences::UpdatePositions->new()->get_show_update_button();
}

sub time_recording_use_duration {
  SL::Helper::UserPreferences::TimeRecording->new()->get_use_duration();
}

sub longdescription_dialog_size_percentage {
  SL::Helper::UserPreferences::DisplayPreferences->new()->get_longdescription_dialog_size_percentage();
}

sub layout_style {
  SL::Helper::UserPreferences::DisplayPreferences->new()->get_layout_style();
}

sub part_picker_search_all_as_list_default {
  SL::Helper::UserPreferences::PartPickerSearch->new()->get_all_as_list_default();
}

sub order_item_input_position {
  SL::Helper::UserPreferences::ItemInputPosition->new()->get_order_item_input_position();
}

sub save_preferences {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  my $employee = SL::DB::Manager::Employee->current;
  $employee->update_attributes(name => $form->{name});

  my $user = SL::DB::Manager::AuthUser->find_by(login => $::myconfig{login});
  $user->update_attributes(
    config_values => {
      %{ $user->config_values },
      map { ($_ => $form->{$_}) } SL::DB::AuthUser::CONFIG_VARS(),
    });

  # Displayable name preferences
  my $displayable_name_specs_by_module = displayable_name_specs_by_module();
  foreach my $specs (@{ $form->{displayable_name_specs} }) {
    if (!$specs->{value} || $specs->{value} eq $displayable_name_specs_by_module->{$specs->{module}}->{prefs}->get_default()) {
      $displayable_name_specs_by_module->{$specs->{module}}->{prefs}->delete($specs->{value});
    } else {
      $displayable_name_specs_by_module->{$specs->{module}}->{prefs}->store_value($specs->{value});
    }
  }

  if (exists $form->{positions_scrollbar_height}) {
    SL::Helper::UserPreferences::PositionsScrollbar->new()->store_height($form->{positions_scrollbar_height})
  }
  if (exists $form->{purchase_search_makemodel}) {
    SL::Helper::UserPreferences::PartPickerSearch->new()->store_purchase_search_makemodel($form->{purchase_search_makemodel})
  }
  if (exists $form->{sales_search_customer_partnumber}) {
    SL::Helper::UserPreferences::PartPickerSearch->new()->store_sales_search_customer_partnumber($form->{sales_search_customer_partnumber})
  }
  if (exists $form->{positions_show_update_button}) {
    SL::Helper::UserPreferences::UpdatePositions->new()->store_show_update_button($form->{positions_show_update_button})
  }
  if (exists $form->{time_recording_use_duration}) {
    SL::Helper::UserPreferences::TimeRecording->new()->store_use_duration($form->{time_recording_use_duration})
  }
  if (exists $form->{longdescription_dialog_size_percentage}) {
    SL::Helper::UserPreferences::DisplayPreferences->new()->store_longdescription_dialog_size_percentage($form->{longdescription_dialog_size_percentage})
  }
  if (exists $form->{layout_style}) {
    SL::Helper::UserPreferences::DisplayPreferences->new()->store_layout_style($form->{layout_style})
  }
  if (exists $form->{part_picker_search_all_as_list_default}) {
    SL::Helper::UserPreferences::PartPickerSearch->new()->store_all_as_list_default($form->{part_picker_search_all_as_list_default})
  }
  if (exists $form->{order_item_input_position}) {
    SL::Helper::UserPreferences::ItemInputPosition->new()->store_order_item_input_position($form->{order_item_input_position})
  }

  $main::lxdebug->leave_sub();

  return 1;
}

sub get_defaults {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;

  my $defaults = selectfirst_hashref_query($form, $dbh, qq|SELECT * FROM defaults|) || {};

  $defaults->{weightunit} ||= 'kg';

  $main::lxdebug->leave_sub();

  return $defaults;
}

sub closedto {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  my $query = qq|SELECT closedto, max_future_booking_interval, revtrans FROM defaults|;
  my $sth   = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{closedto}, $form->{max_future_booking_interval}, $form->{revtrans}) = $sth->fetchrow_array;

  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub closebooks {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;

    my ($query, @values);

    # is currently NEVER trueish (no more hidden revtrans in $form)
    # if ($form->{revtrans}) {
    #   $query = qq|UPDATE defaults SET closedto = NULL, revtrans = '1'|;
    # -> therefore you can only set this to false (which is already the default)
    # and this flag is currently only checked in gl.pl. TOOD Can probably be removed

      $query = qq|UPDATE defaults SET closedto = ?, max_future_booking_interval = ?, revtrans = '0'|;
      @values = (conv_date($form->{closedto}), conv_i($form->{max_future_booking_interval}));

    # set close in defaults
    do_query($form, $dbh, $query, @values);
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub get_base_unit {
  my ($self, $units, $unit_name, $factor) = @_;

  $factor = 1 unless ($factor);

  my $unit = $units->{$unit_name};

  if (!defined($unit) || !$unit->{"base_unit"} ||
      ($unit_name eq $unit->{"base_unit"})) {
    return ($unit_name, $factor);
  }

  return AM->get_base_unit($units, $unit->{"base_unit"}, $factor * $unit->{"factor"});
}

sub retrieve_units {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $prefix) = @_;
  $prefix ||= '';

  my $dbh = SL::DB->client->dbh;

  my $query = "SELECT *, base_unit AS original_base_unit FROM units";

  my $sth = prepare_execute_query($form, $dbh, $query);

  my $units = {};
  while (my $ref = $sth->fetchrow_hashref()) {
    $units->{$ref->{"name"}} = $ref;
  }
  $sth->finish();

  my $query_lang = "SELECT id, template_code FROM language ORDER BY description";
  $sth = $dbh->prepare($query_lang);
  $sth->execute() || $form->dberror($query_lang);
  my @languages;
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@languages, $ref);
  }
  $sth->finish();

  $query_lang = "SELECT ul.localized, ul.localized_plural, l.id, l.template_code " .
    "FROM units_language ul " .
    "LEFT JOIN language l ON ul.language_id = l.id " .
    "WHERE ul.unit = ?";
  $sth = $dbh->prepare($query_lang);

  foreach my $unit (values(%{$units})) {
    ($unit->{"${prefix}base_unit"}, $unit->{"${prefix}factor"}) = AM->get_base_unit($units, $unit->{"name"});

    $unit->{"LANGUAGES"} = {};
    foreach my $lang (@languages) {
      $unit->{"LANGUAGES"}->{$lang->{"template_code"}} = { "template_code" => $lang->{"template_code"} };
    }

    $sth->execute($unit->{"name"}) || $form->dberror($query_lang . " (" . $unit->{"name"} . ")");
    while (my $ref = $sth->fetchrow_hashref()) {
      map({ $unit->{"LANGUAGES"}->{$ref->{"template_code"}}->{$_} = $ref->{$_} } keys(%{$ref}));
    }
  }
  $sth->finish;

  $main::lxdebug->leave_sub();

  return $units;
}

sub retrieve_all_units {
  $main::lxdebug->enter_sub();

  my $self = shift;

  if (!$::request->{cache}{all_units}) {
    $::request->{cache}{all_units} = $self->retrieve_units(\%main::myconfig, $main::form);
  }

  $main::lxdebug->leave_sub();

  return $::request->{cache}{all_units};
}


sub translate_units {
  $main::lxdebug->enter_sub();

  my ($self, $form, $template_code, $unit, $amount) = @_;

  my $units = $self->retrieve_units(\%main::myconfig, $form);

  my $h = $units->{$unit}->{"LANGUAGES"}->{$template_code};
  my $new_unit = $unit;
  if ($h) {
    if (($amount != 1) && $h->{"localized_plural"}) {
      $new_unit = $h->{"localized_plural"};
    } elsif ($h->{"localized"}) {
      $new_unit = $h->{"localized"};
    }
  }

  $main::lxdebug->leave_sub();

  return $new_unit;
}

sub units_in_use {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $units) = @_;

  my $dbh = SL::DB->client->dbh;

  map({ $_->{"in_use"} = 0; } values(%{$units}));

  foreach my $unit (values(%{$units})) {
    my $base_unit = $unit->{"original_base_unit"};
    while ($base_unit) {
      $units->{$base_unit}->{"in_use"} = 1;
      $units->{$base_unit}->{"DEPENDING_UNITS"} = [] unless ($units->{$base_unit}->{"DEPENDING_UNITS"});
      push(@{$units->{$base_unit}->{"DEPENDING_UNITS"}}, $unit->{"name"});
      $base_unit = $units->{$base_unit}->{"original_base_unit"};
    }
  }

  foreach my $unit (values(%{$units})) {
    map({ $_ = $dbh->quote($_); } @{$unit->{"DEPENDING_UNITS"}});

    foreach my $table (qw(parts invoice orderitems)) {
      my $query = "SELECT COUNT(*) FROM $table WHERE unit ";

      if (0 == scalar(@{$unit->{"DEPENDING_UNITS"}})) {
        $query .= "= " . $dbh->quote($unit->{"name"});
      } else {
        $query .= "IN (" . $dbh->quote($unit->{"name"}) . "," .
          join(",", map({ $dbh->quote($_) } @{$unit->{"DEPENDING_UNITS"}})) . ")";
      }

      my ($count) = $dbh->selectrow_array($query);
      $form->dberror($query) if ($dbh->err);

      if ($count) {
        $unit->{"in_use"} = 1;
        last;
      }
    }
  }

  $main::lxdebug->leave_sub();
}

sub convertible_units {
  $main::lxdebug->enter_sub();

  my $self        = shift;
  my $units       = shift;
  my $filter_unit = shift;
  my $not_smaller = shift;

  my $conv_units = [];

  $filter_unit = $units->{$filter_unit};

  foreach my $name (sort { lc $a cmp lc $b } keys %{ $units }) {
    my $unit = $units->{$name};

    if (($unit->{base_unit} eq $filter_unit->{base_unit}) &&
        (!$not_smaller || ($unit->{factor} >= $filter_unit->{factor}))) {
      push @{$conv_units}, $unit;
    }
  }

  my @sorted = sort { $b->{factor} <=> $a->{factor} } @{ $conv_units };

  $main::lxdebug->leave_sub();

  return \@sorted;
}

# if $a is translatable to $b, return the factor between them.
# else return 1
sub convert_unit {
  $main::lxdebug->enter_sub(2);
  my ($this, $a, $b, $all_units) = @_;

  if (!$all_units) {
    $all_units = $this->retrieve_all_units;
  }

  $main::lxdebug->leave_sub(2) and return 0 unless $a && $b;
  $main::lxdebug->leave_sub(2) and return 0 unless $all_units->{$a} && $all_units->{$b};
  $main::lxdebug->leave_sub(2) and return 0 unless $all_units->{$a}{base_unit} eq $all_units->{$b}{base_unit};
  $main::lxdebug->leave_sub(2) and return $all_units->{$a}{factor} / $all_units->{$b}{factor};
}

sub unit_select_data {
  $main::lxdebug->enter_sub();

  my ($self, $units, $selected, $empty_entry, $convertible_into) = @_;

  my $select = [];

  if ($empty_entry) {
    push(@{$select}, { "name" => "", "base_unit" => "", "factor" => "", "selected" => "" });
  }

  foreach my $unit (sort({ $units->{$a}->{"sortkey"} <=> $units->{$b}->{"sortkey"} } keys(%{$units}))) {
    if (!$convertible_into ||
        ($units->{$convertible_into} &&
         ($units->{$convertible_into}->{base_unit} eq $units->{$unit}->{base_unit}))) {
      push @{$select}, { "name"      => $unit,
                         "base_unit" => $units->{$unit}->{"base_unit"},
                         "factor"    => $units->{$unit}->{"factor"},
                         "selected"  => ($unit eq $selected) ? "selected" : "" };
    }
  }

  $main::lxdebug->leave_sub();

  return $select;
}

sub unit_select_html {
  $main::lxdebug->enter_sub();

  my ($self, $units, $name, $selected, $convertible_into) = @_;

  my $select = "<select name=${name}>";

  foreach my $unit (sort({ $units->{$a}->{"sortkey"} <=> $units->{$b}->{"sortkey"} } keys(%{$units}))) {
    if (!$convertible_into ||
        ($units->{$convertible_into} &&
         ($units->{$convertible_into}->{"base_unit"} eq $units->{$unit}->{"base_unit"}))) {
      $select .= "<option" . (($unit eq $selected) ? " selected" : "") . ">${unit}</option>";
    }
  }
  $select .= "</select>";

  $main::lxdebug->leave_sub();

  return $select;
}

sub sum_with_unit {
  $main::lxdebug->enter_sub();

  my $self  = shift;

  my $units = $self->retrieve_all_units();

  my $sum   = 0;
  my $base_unit;

  while (2 <= scalar(@_)) {
    my $qty  = shift(@_);
    my $unit = $units->{shift(@_)};

    croak "No unit defined with name $unit" if (!defined $unit);

    if (!$base_unit) {
      $base_unit = $unit->{base_unit};
    } elsif ($base_unit ne $unit->{base_unit}) {
      croak "Adding values with incompatible base units $base_unit/$unit->{base_unit}";
    }

    $sum += $qty * $unit->{factor};
  }

  $main::lxdebug->leave_sub();

  return $sum;
}

sub add_unit {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $name, $base_unit, $factor, $languages) = @_;

  SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;

    my $query = qq|SELECT COALESCE(MAX(sortkey), 0) + 1 FROM units|;
    my ($sortkey) = selectrow_query($form, $dbh, $query);

    $query = "INSERT INTO units (name, base_unit, factor, sortkey) " .
      "VALUES (?, ?, ?, ?)";
    do_query($form, $dbh, $query, $name, $base_unit, $factor, $sortkey);

    if ($languages) {
      $query = "INSERT INTO units_language (unit, language_id, localized, localized_plural) VALUES (?, ?, ?, ?)";
      my $sth = $dbh->prepare($query);
      foreach my $lang (@{$languages}) {
        my @values = ($name, $lang->{"id"}, $lang->{"localized"}, $lang->{"localized_plural"});
        $sth->execute(@values) || $form->dberror($query . " (" . join(", ", @values) . ")");
      }
      $sth->finish();
    }
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub save_units {
  my ($self, $myconfig, $form, $units, $delete_units) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_save_units, $self, $myconfig, $form, $units, $delete_units);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _save_units {
  my ($self, $myconfig, $form, $units, $delete_units) = @_;

  my $dbh = SL::DB->client->dbh;

  my ($base_unit, $unit, $sth, $query);

  $query = "DELETE FROM units_language";
  $dbh->do($query) || $form->dberror($query);

  if ($delete_units && (0 != scalar(@{$delete_units}))) {
    $query = "DELETE FROM units WHERE name IN (";
    map({ $query .= "?," } @{$delete_units});
    substr($query, -1, 1) = ")";
    $dbh->do($query, undef, @{$delete_units}) ||
      $form->dberror($query . " (" . join(", ", @{$delete_units}) . ")");
  }

  $query = "UPDATE units SET name = ?, base_unit = ?, factor = ? WHERE name = ?";
  $sth = $dbh->prepare($query);

  my $query_lang = "INSERT INTO units_language (unit, language_id, localized, localized_plural) VALUES (?, ?, ?, ?)";
  my $sth_lang = $dbh->prepare($query_lang);

  foreach $unit (values(%{$units})) {
    $unit->{"depth"} = 0;
    my $base_unit = $unit;
    while ($base_unit->{"base_unit"}) {
      $unit->{"depth"}++;
      $base_unit = $units->{$base_unit->{"base_unit"}};
    }
  }

  foreach $unit (sort({ $a->{"depth"} <=> $b->{"depth"} } values(%{$units}))) {
    if ($unit->{"LANGUAGES"}) {
      foreach my $lang (@{$unit->{"LANGUAGES"}}) {
        next unless ($lang->{"id"} && $lang->{"localized"});
        my @values = ($unit->{"name"}, $lang->{"id"}, $lang->{"localized"}, $lang->{"localized_plural"});
        $sth_lang->execute(@values) || $form->dberror($query_lang . " (" . join(", ", @values) . ")");
      }
    }

    next if ($unit->{"unchanged_unit"});

    my @values = ($unit->{"name"}, $unit->{"base_unit"}, $unit->{"factor"}, $unit->{"old_name"});
    $sth->execute(@values) || $form->dberror($query . " (" . join(", ", @values) . ")");
  }

  $sth->finish();
  $sth_lang->finish();

  return 1;
}

sub taxes {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  my $query = qq|SELECT
                   t.id,
                   t.taxkey,
                   t.taxdescription,
                   round(t.rate * 100, 2) AS rate,
                   tc.accno               AS taxnumber,
                   tc.description         AS account_description,
                   ssc.accno              AS skonto_chart_accno,
                   ssc.description        AS skonto_chart_description,
                   spc.accno              AS skonto_chart_purchase_accno,
                   spc.description        AS skonto_chart_purchase_description
                 FROM tax t
                 LEFT JOIN chart tc  ON (tc.id = t.chart_id)
                 LEFT JOIN chart ssc ON (ssc.id = t.skonto_sales_chart_id)
                 LEFT JOIN chart spc ON (spc.id = t.skonto_purchase_chart_id)
                 ORDER BY taxkey, rate|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{TAX} = [];
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    push @{ $form->{TAX} }, $ref;
  }

  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub get_tax_accounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  # get Accounts from chart
  my $query = qq{ SELECT
                 id,
                 accno || ' - ' || description AS taxaccount
               FROM chart
               WHERE link LIKE '%_tax%'
               ORDER BY accno
             };

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{ACCOUNTS} = [];
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    push @{ $form->{ACCOUNTS} }, $ref;
  }

  $form->{AR_PAID} = SL::DB::Manager::Chart->get_all(where => [ link => { like => '%AR_paid%' } ], sort_by => 'accno ASC');
  $form->{AP_PAID} = SL::DB::Manager::Chart->get_all(where => [ link => { like => '%AP_paid%' } ], sort_by => 'accno ASC');

  $form->{skontochart_value_title_sub} = sub {
    my $item = shift;
    return [
      $item->{id},
      $item->{accno} .' '. $item->{description},
    ];
  };

  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub get_tax {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  my $query = qq|SELECT
                   taxkey,
                   taxdescription,
                   round(rate * 100, 2) AS rate,
                   chart_id,
                   chart_categories,
                   (id IN (SELECT tax_id
                           FROM acc_trans)) AS tax_already_used,
                   skonto_sales_chart_id,
                   skonto_purchase_chart_id
                 FROM tax
                 WHERE id = ? |;

  my $sth = $dbh->prepare($query);
  $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

  my $ref = $sth->fetchrow_hashref("NAME_lc");

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # see if it is used by a taxkey
  $query = qq|SELECT count(*) FROM taxkeys
              WHERE tax_id = ? AND chart_id >0|;

  ($form->{orphaned}) = selectrow_query($form, $dbh, $query, $form->{id});

  $form->{orphaned} = !$form->{orphaned};
  $sth->finish;

  if (!$form->{orphaned} ) {
    $query = qq|SELECT DISTINCT c.id, c.accno
                FROM taxkeys tk
                JOIN   tax t ON (t.id = tk.tax_id)
                JOIN chart c ON (c.id = tk.chart_id)
                WHERE tk.tax_id = ?|;

    $sth = $dbh->prepare($query);
    $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

    $form->{TAXINUSE} = [];
    while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
      push @{ $form->{TAXINUSE} }, $ref;
    }

    $sth->finish;
  }

  $main::lxdebug->leave_sub();
}

sub save_tax {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_save_tax, $self, $myconfig, $form);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _save_tax {
  my ($self, $myconfig, $form) = @_;
  my $query;

  my $dbh = SL::DB->client->dbh;

  $form->{rate} = $form->{rate} / 100;

  my $chart_categories = '';
  $chart_categories .= 'A' if $form->{asset};
  $chart_categories .= 'L' if $form->{liability};
  $chart_categories .= 'Q' if $form->{equity};
  $chart_categories .= 'I' if $form->{revenue};
  $chart_categories .= 'E' if $form->{expense};
  $chart_categories .= 'C' if $form->{costs};

  my @values = ($form->{taxkey}, $form->{taxdescription}, $form->{rate}, conv_i($form->{chart_id}), conv_i($form->{skonto_sales_chart_id}), conv_i($form->{skonto_purchase_chart_id}), $chart_categories);
  if ($form->{id} ne "") {
    $query = qq|UPDATE tax SET
                  taxkey                   = ?,
                  taxdescription           = ?,
                  rate                     = ?,
                  chart_id                 = ?,
                  skonto_sales_chart_id    = ?,
                  skonto_purchase_chart_id = ?,
                  chart_categories         = ?
                WHERE id = ?|;

  } else {
    #ok
    ($form->{id}) = selectfirst_array_query($form, $dbh, qq|SELECT nextval('id')|);
    $query = qq|INSERT INTO tax (
                  taxkey,
                  taxdescription,
                  rate,
                  chart_id,
                  skonto_sales_chart_id,
                  skonto_purchase_chart_id,
                  chart_categories,
                  id
                )
                VALUES (?, ?, ?, ?, ?, ?,  ?, ?)|;
  }
  push(@values, $form->{id});
  do_query($form, $dbh, $query, @values);

  foreach my $language_id (keys %{ $form->{translations} }) {
    GenericTranslations->save('dbh'              => $dbh,
                              'translation_type' => 'SL::DB::Tax/taxdescription',
                              'translation_id'   => $form->{id},
                              'language_id'      => $language_id,
                              'translation'      => $form->{translations}->{$language_id});
  }
}

sub delete_tax {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my $query;

  SL::DB->client->with_transaction(sub {
    $query = qq|DELETE FROM tax WHERE id = ?|;
    do_query($form, SL::DB->client->dbh, $query, $form->{id});
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub save_warehouse {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  croak('Need at least one new bin') unless $form->{number_of_new_bins} > 0;

  SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;

    my ($query, @values, $sth);

    if (!$form->{id}) {
      $query        = qq|SELECT nextval('id')|;
      ($form->{id}) = selectrow_query($form, $dbh, $query);

      $query        = qq|INSERT INTO warehouse (id, sortkey) VALUES (?, (SELECT COALESCE(MAX(sortkey), 0) + 1 FROM warehouse))|;
      do_query($form, $dbh, $query, $form->{id});
    }

    do_query($form, $dbh, qq|UPDATE warehouse SET description = ?, invalid = ? WHERE id = ?|,
             $form->{description}, $form->{invalid} ? 't' : 'f', conv_i($form->{id}));

    if (0 < $form->{number_of_new_bins}) {
      my ($num_existing_bins) = selectfirst_array_query($form, $dbh, qq|SELECT COUNT(*) FROM bin WHERE warehouse_id = ?|, $form->{id});
      $query = qq|INSERT INTO bin (warehouse_id, description) VALUES (?, ?)|;
      $sth   = prepare_query($form, $dbh, $query);

      foreach my $i (1..$form->{number_of_new_bins}) {
        do_statement($form, $sth, $query, conv_i($form->{id}), "$form->{prefix}" . ($i + $num_existing_bins));
      }

      $sth->finish();
    }
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub save_bins {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;

    my ($query, @values, $sth);

    @values = map { $form->{"id_${_}"} } grep { $form->{"delete_${_}"} } (1..$form->{rowcount});

    if (@values) {
      $query = qq|DELETE FROM bin WHERE id IN (| . join(', ', ('?') x scalar(@values)) . qq|)|;
      do_query($form, $dbh, $query, @values);
    }

    $query = qq|UPDATE bin SET description = ? WHERE id = ?|;
    $sth   = prepare_query($form, $dbh, $query);

    foreach my $row (1..$form->{rowcount}) {
      next if ($form->{"delete_${row}"});

      do_statement($form, $sth, $query, $form->{"description_${row}"}, conv_i($form->{"id_${row}"}));
    }

    $sth->finish();
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub delete_warehouse {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $rc = SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;

    my $id      = conv_i($form->{id});
    my $query   = qq|SELECT i.bin_id FROM inventory i WHERE i.bin_id IN (SELECT b.id FROM bin b WHERE b.warehouse_id = ?) LIMIT 1|;
    my ($count) = selectrow_query($form, $dbh, $query, $id);

    if ($count) {
      return 0;
    }

    do_query($form, $dbh, qq|DELETE FROM bin       WHERE warehouse_id = ?|, conv_i($form->{id}));
    do_query($form, $dbh, qq|DELETE FROM warehouse WHERE id           = ?|, conv_i($form->{id}));

    return 1;
  });

  $main::lxdebug->leave_sub();

  return $rc;
}

sub get_all_warehouses {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  my $query = qq|SELECT w.id, w.description, w.invalid,
                   (SELECT COUNT(b.description) FROM bin b WHERE b.warehouse_id = w.id) AS number_of_bins
                 FROM warehouse w
                 ORDER BY w.sortkey|;

  $form->{WAREHOUSES} = selectall_hashref_query($form, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub get_warehouse {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  my $id    = conv_i($form->{id});
  my $query = qq|SELECT w.description, w.invalid
                 FROM warehouse w
                 WHERE w.id = ?|;

  my $ref   = selectfirst_hashref_query($form, $dbh, $query, $id);

  map { $form->{$_} = $ref->{$_} } keys %{ $ref };

  $query = <<SQL;
   SELECT b.*, use.in_use
     FROM bin b
     LEFT JOIN (
       SELECT DISTINCT bin_id, TRUE AS in_use FROM inventory
       UNION
       SELECT DISTINCT bin_id, TRUE AS in_use FROM parts
     ) use ON use.bin_id = b.id
     WHERE b.warehouse_id = ?
     ORDER by description;
SQL

  $form->{BINS} = selectall_hashref_query($form, $dbh, $query, conv_i($form->{id}));

  $main::lxdebug->leave_sub();
}

sub get_eur_categories {
  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;
  my %eur_categories = selectall_as_map($form, $dbh, "select * from eur_categories order by id", 'id', 'description');

  return \%eur_categories;
}

sub get_bwa_categories {
  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;
  my %bwa_categories = selectall_as_map($form, $dbh, "select * from bwa_categories order by id", 'id', 'description');

  return \%bwa_categories;
}

1;
