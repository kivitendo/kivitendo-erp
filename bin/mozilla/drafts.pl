#======================================================================
# LX-Office ERP
#
#======================================================================
#
# Saving and loading drafts
#
#======================================================================

use SL::Drafts;

require "bin/mozilla/common.pl";

sub save_draft {
  $lxdebug->enter_sub();

  if (!$form->{draft_id} && !$form->{draft_description}) {
    restore_form($form->{SAVED_FORM}, 1) if ($form->{SAVED_FORM});
    $form->{SAVED_FORM} = save_form();

    $form->header();
    print($form->parse_html_template("drafts/save_new"));
    return $lxdebug->leave_sub();
  }

  my ($draft_id, $draft_description) =
    ($form->{draft_id}, $form->{draft_description});

  restore_form($form->{SAVED_FORM}, 1);
  delete($form->{SAVED_FORM});

  Drafts->save(\%myconfig, $form, $draft_id, $draft_description);

  $form->{saved_message} = $locale->text("Draft saved.");

  update();

  $lxdebug->leave_sub();
}

sub remove_draft {
  $lxdebug->enter_sub();

  Drafts->remove(\%myconfig, $form, $form->{draft_id}) if ($form->{draft_id});

  delete($form->{draft_id});
  delete($form->{draft_description});

  $lxdebug->leave_sub();
}

sub load_draft_maybe {
  $lxdebug->enter_sub();

  $lxdebug->leave_sub() and return 0 if ($form->{DONT_LOAD_DRAFT});

  my ($draft_nextsub) = @_;

  my @drafts = Drafts->list(\%myconfig, $form);

  $lxdebug->leave_sub() and return 0 unless (@drafts);

  $draft_nextsub = "add" unless ($draft_nextsub);

  delete($form->{action});
  my $saved_form = save_form();

  $form->header();
  print($form->parse_html_template("drafts/load",
                                   { "DRAFTS" => \@drafts,
                                     "SAVED_FORM" => $saved_form,
                                     "draft_nextsub" => $draft_nextsub }));

  $lxdebug->leave_sub();

  return 1;
}

sub dont_load_draft {
  $lxdebug->enter_sub();

  my $draft_nextsub = $form->{draft_nextsub};
  $draft_nextsub = "add" unless ($form->{draft_nextsub});
  restore_form($form->{SAVED_FORM}, 1);
  delete($form->{action});
  $form->{DONT_LOAD_DRAFT} = 1;

  &{ $draft_nextsub }();

  $lxdebug->leave_sub();
}

sub load_draft {
  $lxdebug->enter_sub();

  my ($old_form, $id, $description) = Drafts->load(\%myconfig, $form, $form->{id});
  if ($old_form) {
    restore_form($old_form, 1);
    $form->{draft_id} = $id;
    $form->{draft_description} = $description;
  }

  update();

  $lxdebug->leave_sub();
}

1;
