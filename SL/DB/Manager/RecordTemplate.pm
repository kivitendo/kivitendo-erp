package SL::DB::Manager::RecordTemplate;

use strict;

use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;
use SL::DB::Helper::Filtered;

use List::MoreUtils qw(any);

sub object_class { 'SL::DB::RecordTemplate' }

__PACKAGE__->make_manager_methods;

__PACKAGE__->add_filter_specs(
  type => sub {
    my ($key, $value, $prefix) = @_;
    return __PACKAGE__->type_filter($value, $prefix);
  },
);

sub type_filter {
  my $class  = shift;
  my $type   = lc(shift || '');
  my $prefix = shift || '';

  # remove '_template' if needed
  my $template_type = $type;
  $template_type =~ s/_template$//;

  return ("${prefix}template_type" => $template_type) if( any {$template_type eq $_} (
      'gl_transaction',
      'ar_transaction',
      'ap_transaction',
    ));

  die "Unknown type $type";
}

sub _sort_spec {
  return (
    default => [ 'template_name', 1 ],
    columns => {
      SIMPLE        => 'ALL',
      template_name => 'lower(template_name)',
    },
  );
}

1;
