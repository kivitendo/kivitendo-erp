#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
######################################################################
#
# Stuff that can be used from other modules
#
######################################################################

use Data::Dumper;

sub save_form {
  $lxdebug->enter_sub();

  my (@names, @values);
  foreach my $key (keys(%{$form})) {
    push(@names, "\$form->{\"$key\"}");
    push(@values, $form->{$key});
  }
  my $dumper = Data::Dumper->new(\@values, \@names);
  $dumper->Indent(0);
  my $old_form = $dumper->Dump();

  $lxdebug->leave_sub();

  return $old_form;
}

sub restore_form {
  $lxdebug->enter_sub();

  my ($old_form, $no_delete) = @_;

  map({ delete($form->{$_}); } keys(%{$form})) unless ($no_delete);
  eval($old_form);

  $lxdebug->leave_sub();
}

sub H {
  return $form->quote_html($_[0]);
}

1;
