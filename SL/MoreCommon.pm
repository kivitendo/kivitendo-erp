package SL::MoreCommon;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(save_form restore_form);

use YAML;

sub save_form {
  $main::lxdebug->enter_sub();

  my $old_form = YAML::Dump($main::form);
  $old_form =~ s|!|!!|g;
  $old_form =~ s|\n|!n|g;
  $old_form =~ s|\r|!r|g;

  $main::lxdebug->leave_sub();

  return $old_form;
}

sub restore_form {
  $main::lxdebug->enter_sub();

  my ($old_form, $no_delete) = @_;

  my $form = $main::form;

  map { delete $form->{$_}; } keys %{$form} unless ($no_delete);

  $old_form =~ s|!r|\r|g;
  $old_form =~ s|!n|\n|g;
  $old_form =~ s|!!|!|g;

  my $new_form = YAML::Load($old_form);
  map { $form->{$_} = $new_form->{$_}; } keys %{$new_form};

  $main::lxdebug->leave_sub();
}

1;
