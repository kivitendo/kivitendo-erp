#======================================================================
# LX-Office ERP
#
#======================================================================
#
# Saving and loading drafts
#
#======================================================================

use YAML;

use SL::Drafts;

require "bin/mozilla/common.pl";

use strict;

sub save_draft {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  if (!$form->{draft_id} && !$form->{draft_description}) {
    restore_form($form->{SAVED_FORM}, 1) if ($form->{SAVED_FORM});
    delete $form->{SAVED_FORM};

    $form->{SAVED_FORM}   = save_form(qw(login password));
    $form->{remove_draft} = 1;

    $form->header();
    print($form->parse_html_template("drafts/save_new"));

    return $main::lxdebug->leave_sub();
  }

  my ($draft_id, $draft_description) = ($form->{draft_id}, $form->{draft_description});

  restore_form($form->{SAVED_FORM}, 1);
  delete $form->{SAVED_FORM};

  Drafts->save(\%myconfig, $form, $draft_id, $draft_description);

  $form->{saved_message} = $locale->text("Draft saved.");

  update();

  $main::lxdebug->leave_sub();
}

sub remove_draft {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  Drafts->remove(\%myconfig, $form, $form->{draft_id}) if ($form->{draft_id});

  delete @{$form}{qw(draft_id draft_description)};

  $main::lxdebug->leave_sub();
}

sub load_draft_maybe {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::lxdebug->leave_sub() and return 0 if ($form->{DONT_LOAD_DRAFT});

  my ($draft_nextsub) = @_;

  my @drafts = Drafts->list(\%myconfig, $form);

  $main::lxdebug->leave_sub() and return 0 unless (@drafts);

  $draft_nextsub = "add" unless ($draft_nextsub);

  delete $form->{action};
  my $saved_form = save_form(qw(login password));

  $form->header();
  print($form->parse_html_template("drafts/load",
                                   { "DRAFTS"        => \@drafts,
                                     "SAVED_FORM"    => $saved_form,
                                     "draft_nextsub" => $draft_nextsub }));

  $main::lxdebug->leave_sub();

  return 1;
}

sub dont_load_draft {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  my $draft_nextsub = $form->{draft_nextsub} || "add";

  restore_form($form->{SAVED_FORM}, 1);
  delete $form->{SAVED_FORM};

  $form->{DONT_LOAD_DRAFT} = 1;

  call_sub($draft_nextsub);

  $main::lxdebug->leave_sub();
}

sub load_draft {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my ($old_form, $id, $description) = Drafts->load(\%myconfig, $form, $form->{id});

  if ($old_form) {
    $old_form = YAML::Load($old_form);

    my %dont_save_vars      = map { $_ => 1 } Drafts->dont_save;
    my @restore_vars        = grep { !$dont_save_vars{$_} } keys %{ $old_form };

    @{$form}{@restore_vars} = @{$old_form}{@restore_vars};

    $form->{draft_id}              = $id;
    $form->{draft_description}     = $description;
    $form->{remove_draft}          = 'checked';
  }
  # Ich vergesse bei Rechnungsentwürfe das Rechnungsdatum zu ändern. Dadurch entstehen
  # ungültige Belege. Vielleicht geht es anderen ähnlich jan 19.2.2011
  $form->{invdate} = $form->current_date(\%myconfig); # Aktuelles Rechnungsdatum  ...
  $form->{duedate} = $form->current_date(\%myconfig); # Aktuelles Fälligkeitsdatum  ...
  update();

  $main::lxdebug->leave_sub();
}

sub delete_drafts {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my @ids;
  foreach (keys %{$form}) {
    push @ids, $1 if (/^checked_(.*)/ && $form->{$_});
  }
  Drafts->remove(\%myconfig, $form, @ids) if (@ids);

  restore_form($form->{SAVED_FORM}, 1);
  delete $form->{SAVED_FORM};

  add();

  $main::lxdebug->leave_sub();
}

sub draft_action_dispatcher {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  if ($form->{draft_action} eq $locale->text("Skip")) {
    dont_load_draft();

  } elsif ($form->{draft_action} eq $locale->text("Delete drafts")) {
    delete_drafts();
  }

  $main::lxdebug->leave_sub();
}

1;
