use SL::AccTransCorrections;
use SL::Form;
use SL::Locale::String qw(t8);
use SL::User;
use Data::Dumper;

require "bin/mozilla/common.pl";

use strict;

sub analyze_filter {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  setup_analyze_filter_action_bar();

  $form->{title}    = $locale->text('General ledger corrections');
  $form->header();
  print $form->parse_html_template('acctranscorrections/analyze_filter');

  $main::lxdebug->leave_sub();
}

sub analyze {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->{title} = $locale->text('General ledger corrections');

  delete @{ $form }{qw(transdate_from transdate_to)} if ($form->{scope} eq 'full');

  my $callback = 'acctranscorrections.pl?action=analyze';
  map { $callback .= "&${_}=" . $form->escape($form->{$_}) } grep { $form->{$_} } qw(transdate_from transdate_to);
  $callback = $form->escape($callback);

  my $analyzer = AccTransCorrections->new();

  my %params   = map { $_ => $form->{$_} } qw(transdate_from transdate_to);
  my @problems = $analyzer->analyze(%params, 'callback' => $callback);

  if (!scalar @problems) {
    $form->show_generic_information($locale->text('No problems were recognized.'));

    $main::lxdebug->leave_sub();
    return;
  }

  setup_analyze_action_bar();

  $form->header();
  print $form->parse_html_template('acctranscorrections/analyze_overview',
                                   { 'PROBLEMS' => \@problems,
                                     'callback' => $callback,
                                   });

  $main::lxdebug->leave_sub();
}

sub assistant {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->{title} = $locale->text('Assistant for general ledger corrections');

  $form->isblank('trans_id', $locale->text('Transaction ID missing.'));

  my $analyzer  = AccTransCorrections->new();
  my ($problem) = $analyzer->analyze('trans_id' => $form->{trans_id}, 'full_analysis' => 1);

  if (!$problem) {
    my $module =
        $form->{trans_module} eq 'ar' ? $locale->text('AR Transaction')
      : $form->{trans_module} eq 'ap' ? $locale->text('AP Transaction')
      :                                 $locale->text('General Ledger Transaction');

    $form->show_generic_information($locale->text('The assistant could not find anything wrong with #1. Maybe the problem has been solved in the meantime.',
                                                  "$module $form->{trans_reference}"));

    $main::lxdebug->leave_sub();
    return;
  }

  if ($problem->{type} eq 'wrong_taxkeys') {
    assistant_for_wrong_taxkeys($problem);

  } elsif ($problem->{type} eq 'wrong_taxes') {
    assistant_for_wrong_taxkeys($problem);
#     assistant_for_wrong_taxes($problem);

  } else {
    $form->show_generic_error($locale->text('Unknown problem type.'));
  }

  $main::lxdebug->leave_sub();
}

sub assistant_for_ap_ar_wrong_taxkeys {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->{title} = $locale->text('Assistant for general ledger corrections');

  $form->header();
  print $form->parse_html_template('acctranscorrections/assistant_for_ap_ar_wrong_taxkeys');

  $main::lxdebug->leave_sub();
}

sub fix_ap_ar_wrong_taxkeys {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  my $analyzer = AccTransCorrections->new();
  $analyzer->fix_ap_ar_wrong_taxkeys();

  $form->{title} = $locale->text('Assistant for general ledger corrections');
  $form->header();
  print $form->parse_html_template('acctranscorrections/fix_ap_ar_wrong_taxkeys');

  $main::lxdebug->leave_sub();
}

sub assistant_for_invoice_inventory_with_taxkeys {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->{title} = $locale->text('Assistant for general ledger corrections');

  $form->header();
  print $form->parse_html_template('acctranscorrections/assistant_for_invoice_inventory_with_taxkeys');

  $main::lxdebug->leave_sub();
}

sub fix_invoice_inventory_with_taxkeys {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  my $analyzer  = AccTransCorrections->new();
  $analyzer->fix_invoice_inventory_with_taxkeys();

  $form->{title} = $locale->text('Assistant for general ledger corrections');
  $form->header();
  print $form->parse_html_template('acctranscorrections/fix_invoice_inventory_with_taxkeys');

  $main::lxdebug->leave_sub();
}

sub assistant_for_wrong_taxes {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  my $problem = shift;

  $form->{title} = $locale->text('Assistant for general ledger corrections');

  $form->header();
  print $form->parse_html_template('acctranscorrections/assistant_for_wrong_taxes', { 'problem' => $problem, });

  $main::lxdebug->leave_sub();
}

sub assistant_for_wrong_taxkeys {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  my $problem = shift;

  $form->{title} = $locale->text('Assistant for general ledger corrections');

  $form->header();
  print $form->parse_html_template('acctranscorrections/assistant_for_wrong_taxkeys', { 'problem' => $problem, });

  $main::lxdebug->leave_sub();
}

sub fix_wrong_taxkeys {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  my $fixes = ref $form->{fixes} eq 'ARRAY' ? $form->{fixes} : [];

  my $analyzer  = AccTransCorrections->new();
  $analyzer->fix_wrong_taxkeys('fixes' => $fixes);

  $form->{title} = $locale->text('Assistant for general ledger corrections');
  $form->header();
  print $form->parse_html_template('acctranscorrections/fix_wrong_taxkeys');

  $main::lxdebug->leave_sub();
}

sub delete_transaction {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->{title} = $locale->text('Delete transaction');
  $form->header();

  if (!$form->{confirmation}) {
    print $form->parse_html_template('acctranscorrections/delete_transaction_confirmation');
  } else {
    my $analyzer  = AccTransCorrections->new();
    $analyzer->delete_transaction('trans_id' => $form->{trans_id});

    print $form->parse_html_template('acctranscorrections/delete_transaction');
  }

  $main::lxdebug->leave_sub();
}

sub redirect {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $form->redirect('Missing callbcak');

  $main::lxdebug->leave_sub();
}

sub dispatcher {
  my $form     = $main::form;
  my $locale   = $main::locale;

  foreach my $action (qw(fix_wrong_taxkeys delete_transaction)) {
    if ($form->{"action_${action}"}) {
      call_sub($action);
      return;
    }
  }

  $form->error($locale->text('No action defined.'));
}

sub setup_analyze_filter_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Analyze'),
        submit    => [ '#form' ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_analyze_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Back'),
        call => [ 'kivi.history_back' ],
      ],
    );
  }
}

1;
