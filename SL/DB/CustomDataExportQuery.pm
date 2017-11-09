package SL::DB::CustomDataExportQuery;

use strict;

use SL::DB::MetaSetup::CustomDataExportQuery;
use SL::DB::Manager::CustomDataExportQuery;

__PACKAGE__->meta->add_relationship(
  parameters => {
    type       => 'one to many',
    class      => 'SL::DB::CustomDataExportQueryParameter',
    column_map => { id => 'query_id' },
  },
);

__PACKAGE__->meta->initialize;

sub used_parameter_names {
  my ($self) = @_;

  my %parameters;

  my $sql_query   = $self->sql_query // '';
  $parameters{$1} = 1 while $sql_query =~ m{<\%(.+?)\%>}g;

  return sort keys %parameters;
}

1;
