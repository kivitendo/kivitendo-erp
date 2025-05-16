use strict;

use lib 't';

use Support::Templates;
use Support::TestSetup;

use File::Spec;
use File::Slurp;
use Template;
use Template::Provider;
use Test::More tests => ( scalar(@referenced_files));

my $template_path = 'templates/design40_webpages/';

my $provider = Template::Provider->new(Support::TestSetup::template_config());

foreach my $ref (@Support::Templates::referenced_files) {
  my $file              = "${template_path}${ref}.html";
  my ($result, $not_ok) = $provider->fetch($file);

  if (!$not_ok) {
    ok(1, "${file} does not contain errors");

  } elsif (ref($result) eq 'Template::Exception') {
    print STDERR $result->as_string;
    ok(0, "${file} contains syntax errors");

  } else {
    die "Unknown result type: " . ref($result) . " for file " . $file;
  }
}

exit 0;
