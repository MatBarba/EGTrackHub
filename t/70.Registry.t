#!/usr/bin/env perl
use strict;
use warnings;
use Carp;

#use Test::More skip_all => "TODO";
use Test::More qw(no_plan);
use Test::Exception;

# -----
# checks if the module can load
# -----
use_ok('Bio::EnsEMBL::TrackHub::Registry');

# -----
# test constructor
# -----
my $user = $ENV{'THR_USER'};
my $pass = $ENV{'THR_PASS'};

SKIP: {
  skip
    "credentials needed to test the registry API (define THR_USER and THR_PASS in the environment)"
    unless $user and $pass;

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
    'http://www.ebi.ac.uk/~mbarba/rnaseq/hubs/anopheles_minimus/VBRNAseq_SRP021068/hub.txt';
  my %assemblies = (
    'AminM1' => 'GCA_000349025.1',
  );

  ok(
    $registry->register_track_hub(
      $th_id,
      $hub_url,
      \%assemblies
    ),
    "Can register a trackhub with correct data"
  );

  ok(
    $registry->delete_track_hubs($th_id),
    "Can delete a trackhub"
  );

}

__END__

