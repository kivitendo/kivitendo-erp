use strict;
use threads;
use lib 't';
use Support::Files;
use Sys::CPU;
use Test::More;
use Thread::Pool::Simple;

if (eval { require PPI; 1 }) {
  plan tests => scalar(@Support::Files::testitems);
} else {
  plan skip_all => "PPI not installed";
}

my @testitems = @Support::Files::testitems;

sub test_file {
  my ($file) = @_;

  my $clean = 1;
  my $source;
  {
    local $^W = 0; # don't care about invalid chars in comments
    local $/ = undef;
    open my $fh, '<:utf8', $file or die $!;
    $source = <$fh>;
  }

  my $doc = PPI::Document->new(\$source) or do {
    print "?: PPI error for file $file: " . PPI::Document::errstr() . "\n";
    ok 0, $file;
    next;
  };
  my $stmts = $doc->find(sub { $_[1]->isa('PPI::Token::Quote::Double') || $_[1]->isa('PPI::Token::Quote::Interpolate') });

  for my $stmt (@{ $stmts || [] }) {
    my $content = $stmt->content;

    if ($content =~ /(\$\w+::)\$/) {
      print "?: @{[ $stmt->content ]} contains $1 \n";
      $clean = 0;
    }
  }

  ok $clean, $file;
}

my $pool = Thread::Pool::Simple->new(
  min    => 2,
  max    => Sys::CPU::cpu_count() + 1,
  do     => [ \&test_file ],
  passid => 0,
);

$pool->add($_) for @testitems;

$pool->join;
