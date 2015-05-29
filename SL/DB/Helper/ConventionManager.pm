package SL::DB::Helper::ConventionManager;

use strict;

use Rose::DB::Object::ConventionManager;

use base qw(Rose::DB::Object::ConventionManager);

sub auto_manager_class_name {
  my $self         = shift;
  my $object_class = shift || $self->meta->class;

  my @parts        = split m/::/, $object_class;
  my $last         = pop @parts;

  return join('::', @parts, 'Manager', $last);
}

# Base name used for 'make_manager_class', e.g. 'get_all',
# 'update_all'
sub auto_manager_base_name {
  return 'all';
}

sub auto_manager_base_class {
  return 'SL::DB::Helper::Manager';
}

sub auto_foreign_key_name
{
  my($self, $f_class, $current_name, $key_columns, $used_names) = @_;

  my $f_meta = $f_class->meta or return $current_name;
  my $package_name = SL::DB::Helper::Mappings::get_name_for_table($f_meta->table);
  my $name = $package_name || $current_name;

  if(keys %$key_columns == 1)
  {
    my($local_column, $foreign_column) = %$key_columns;

    # Try to lop off foreign column name.  Example:
    # my_foreign_object_id -> my_foreign_object
    if($local_column =~ s/_$foreign_column$//i)
    {
      $name = $local_column;
    }
    else
    {
      $name = $package_name || $current_name;
    }
  }

  # Avoid method name conflicts
  if($self->method_name_conflicts($name) || $used_names->{$name})
  {
    foreach my $s ('_obj', '_object')
    {
      # Try the name with a suffix appended
      unless($self->method_name_conflicts($name . $s) ||
             $used_names->{$name . $s})
      {
        return $name . $s;
      }
    }

    my $i = 1;

    # Give up and go with numbers...
    $i++  while($self->method_name_conflicts($name . $i) ||
                $used_names->{$name . $i});

    return $name . $i;
  }

  return $name;
}

1;
