#!/usr/bin/env perl
use strict;
use warnings;
use Carp;

#use Test::More skip_all => "TODO";
use Test::More qw(no_plan);
use Test::Exception;

use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($DEBUG);
my $logger = get_logger();
use Data::Dumper;

use LWP::Simple qw($ua head);
$ua->timeout(5);

# -----
# checks if the module can load
# -----
use FindBin;
use lib $FindBin::Bin . '/../lib';
use_ok('Bio::EnsEMBL::TrackHub::Registry');

# -----
# test constructor
# -----
my $user = $ENV{'THR_USER'};
my $pass = $ENV{'THR_PASS'};

SKIP: {
  diag "No user" if not $user;
  diag "No password" if not $pass;
  skip
    "credentials needed to test the registry API (define THR_USER and THR_PASS in the environment)"
    if not ($user and $pass);

  # First, test the login
  dies_ok {
    my $registry = Bio::EnsEMBL::TrackHub::Registry->new;
  }
  "Login without credentials fails";

  # Wrong credentials
  dies_ok {
    my $registry = Bio::EnsEMBL::TrackHub::Registry->new(
      user => "00000000000000000",
      pass => "password"
    );
  }
  "Login with wrong credentials fails";

  # Actual credentials
  ok(
    my $registry = Bio::EnsEMBL::TrackHub::Registry->new(
      user     => $user,
      password => $pass
    ),
    "Login with right credentials"
  );

  isa_ok(
    $registry,
    'Bio::EnsEMBL::TrackHub::Registry',
    'The object constructed is of my class type'
  );

  dies_ok {
    Bio::EnsEMBL::TrackHub::Registry->new("blabla");
  }
  'Wrong object construction dies';

  ok( $registry->is_public == 0,    "The registry is not public by default" );
  ok( $registry->is_public(1) == 1, "Set the registry to public mode" );
  ok( $registry->is_public(0) == 0, "Set the registry back to private mode" );
  
  # Check registered
  ok(
    my $reg = $registry->get_registered(),
    "Can get list of registered hubs"
  );
  
  # Not a test, but a check: we don't want to touch non-test track hubs!
  croak "The current registry for the test user is not empty.
  Please make sure that the test account has no hubs (this is to prevent mistakes)." if not $reg or @$reg > 0;

  # Register 1 trackhub
  dies_ok {
    $registry->register_track_hub(
      "trackhub_id",
      "https://wrong.address/hub.txt"
    );
  }
  "Can't register a trackhub with wrong hub.txt url";

  my $th_id = 'VBRNAseq_SRP021068';
  my $hub_url =
    'http://www.ebi.ac.uk/~mbarba/testing/eg-trackhub/VBRNAseq_SRP021068/hub.txt';
  my %assemblies = (
    'AminM1' => 'GCA_000349025.1',
  );

  # Check that the file is accessible, otherwise skip this test
  SKIP: {
    skip "hub.txt url in not accessible" if not head($hub_url);
    ok(
      $registry->register_track_hub(
        id           => $th_id,
        url          => $hub_url,
        assembly_map => \%assemblies
      ),
      "Can register a trackhub with correct data"
    );

    ok(
      my $reg = $registry->get_registered(),
      "Can get list of registered hubs"
    );

    ok(
      @$reg == 1,
      "The list contains 1 registered hub",
    );

    ok(
      $registry->delete_track_hubs($th_id),
      "Can delete a trackhub"
    );
  }
}

__END__

