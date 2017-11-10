package SL::DB::CustomDataExportQueryParameter;

use strict;

use SL::DB::MetaSetup::CustomDataExportQueryParameter;
use SL::DB::Manager::CustomDataExportQueryParameter;

__PACKAGE__->meta->initialize;

sub _default_value_type_fixed_value        { $_[0]->default_value }
sub _default_value_type_current_user_login { $::myconfig{login} }

sub _default_value_type_sql_query {
  my ($self) = @_;

  return '' if !$self->default_value;

  my @result = $self->db->dbh->selectrow_array($self->default_value);
  $::form->dberror if !@result;

  return $result[0];
}

sub calculate_default_value {
  my ($self) = @_;

  my $method = "_default_value_type_" . ($self->default_value_type // '');
  return $self->can($method) ? $self->$method : '';
}

1;
