#!/usr/bin/env perl
use strict;
use warnings;
use Carp;

#use Test::More skip_all => "TODO";
use Test::More qw(no_plan);
use Test::Exception;

use Log::Log4perl qw( :easy );
#Log::Log4perl->easy_init($DEBUG);
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
use_ok('Bio::EnsEMBL::TrackHub::Hub');

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
  dies_ok { my $registry = Bio::EnsEMBL::TrackHub::Registry->new; }
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
  ok( my $registry = Bio::EnsEMBL::TrackHub::Registry->new(
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

  dies_ok { Bio::EnsEMBL::TrackHub::Registry->new("blabla"); }
    'Wrong object construction dies';

  ok( $registry->is_public    == 0, "The registry is not public by default" );
  ok( $registry->is_public(1) == 1, "Set the registry to public mode" );
  ok( $registry->is_public(0) == 0, "Set the registry back to private mode" );
  
  # Check registered
  ok(
    (my @reg = $registry->get_registered()) == 0,
    "Can get list of registered hubs"
  );
  
  # Not a test, but a check: we don't want to touch non-test track hubs!
  croak "The current registry for the test user is not empty.
  Please make sure that the test account has no hubs (this is to prevent mistakes)." if @reg > 0;

  # Register 1 trackhub
  dies_ok {
    $registry->register_track_hub_data(
      id  => "trackhub_id",
      url => "https://wrong.address/hub.txt"
    );
  }
  "Can't register a trackhub with wrong parameters";

  my $th_id       = 'VBRNAseq_SRP021068';
  my $hub_root    = 'http://www.ebi.ac.uk/~mbarba/testing/eg-trackhub/VBRNAseq_SRP021068';
  my $hub_url     = "$hub_root/hub.txt";
  my $genome_name = 'AminM1';
  my $insdc       = 'GCA_000349025.1';
  my %assemblies = (
    $genome_name => $insdc,
  );

  # Check that the file is accessible, otherwise skip this test
  SKIP: {
    skip "hub.txt url in not accessible" if not head($hub_url);
    ok(
      $registry->register_track_hub_data(
        id           => $th_id,
        url          => $hub_url,
        assembly_map => \%assemblies
      ),
      "Can register a trackhub with correct data"
    );

    # Check that the registration worked
    ok( my $reg = $registry->get_registered(),
      "Can get list of registered hubs" );

    ok( @$reg == 1,
      "The list contains 1 registered hub" );

    # Get information
    ok( my @meta = $registry->get_registered(), "Get track hubs data");

    ok( my $last_time     = $registry->get_registered_last_update(), "Get last update time");
    ok( $last_time =~ /^\d+$/, "Last update time is in a correct format");

    # Delete this specific track hub
    ok( $registry->delete_track_hubs($th_id),
      "Can delete a trackhub" );

    # Register the hub again with a different method
    my $hub = Bio::EnsEMBL::TrackHub::Hub->new(
      id          => $th_id,
      shortLabel  => 'Trackhub test1',
      longLabel   => 'Trackhub test1 long label',
      root_dir    => $hub_root,
    );
    my $genome = Bio::EnsEMBL::TrackHub::Hub::Genome->new(
      id    => $genome_name,
      insdc => $insdc,
    );
    $hub->add_genome($genome);
    ok( $registry->register_track_hubs($hub),
      "Can register a trackhub with a Hub object" );

    # And delete all trackhubs for the user
    ok( $registry->delete_all_track_hubs(),
      "Can delete all trackhubs" );

    # No more track hubs
    ok( my @regend = $registry->get_registered(), "Check registered tracks after complete deletion");
    ok( @regend == 0, "There are no more tracks" );
  }
}

__END__

