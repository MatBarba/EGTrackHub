#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use Test::More;
use Test::Exception;
use Test::File;
use File::Temp;
use File::Spec;
use Data::Dumper;
use Perl6::Slurp qw(slurp);

# checks if the modules can load
use_ok('EGTrackHubs::TrackHubDB');
use_ok('EGTrackHubs::TrackHubDB::Genome');

# Prepare dummy data
my %ex = (
  id               => 'th_id_1',
  short_label      => 'Trackhub_1',
  long_label       => 'Trackhub number 1',
  description_url  => 'http://example.org',
  email            => 'john@smith.org',
);
my $expected_hub = "hub $ex{id}
shortLabel $ex{short_label}
longLabel $ex{long_label}
genomesFile genomes.txt
email $ex{email}
descriptionUrl $ex{description_url}
";

# Test creation of a TrackhubDB
throws_ok {
  my $th = EGTrackHubs::TrackHubDB->new();
  } 'Moose::Exception::AttributeIsRequired',
  "Creating a Trackhub object without any parameters should fail";

throws_ok {
  my $th = EGTrackHubs::TrackHubDB->new(id => $ex{id});
  } 'Moose::Exception::AttributeIsRequired',
  "Creating a Trackhub object without all required fields should fail";
  
ok (
  my $th = EGTrackHubs::TrackHubDB->new(%ex),
  "Creating a Trackhub object with all required fields"
);
isa_ok(
  $th,
  'EGTrackHubs::TrackHubDB',
  'Right object created'
);
cmp_ok(
  $th->id, 'eq', $ex{id},
  "Correct id"
);

# Test writing to hub.txt
ok(
  my $hub = $th->hub_file_content,
  "Print TH hub content with all required data",
);
cmp_ok(
  $hub, 'eq', $expected_hub,
  "Hub content is as expected"
);

# Create an actual file
my $tmp_dir = File::Temp->newdir;

dies_ok {
  $th->make_hub_file
  }  "Create hub file without defined dir should fail";
ok(
  $th->dir($tmp_dir.''),
  "Set directory to $tmp_dir"
);
ok(
  $th->make_hub_file,
  "Create hub file with defined dir"
);

my $hub_path = File::Spec->catfile(
  $th->{dir},
  $th->{hub_file}
);
ok(
  -s $hub_path,
  "Non empty hub file created"
);

my $hub_file_txt = slurp $hub_path;
cmp_ok(
  $hub_file_txt, 'eq', $expected_hub,
  "Hub file content is as expected"
);

# Now, add a genome
my %genome_sample = (
  id  => 'genome_1',
);
ok(
  my $genome = EGTrackHubs::TrackHubDB::Genome->new(%genome_sample),
  "Create a genome"
);
ok(
  $th->add_genome($genome),
  "Add a genome to the TrackHub"
);
dies_ok {
  $th->add_genome($genome);
} "Add a genome to the TrackHub with the same id should fail";

done_testing();

