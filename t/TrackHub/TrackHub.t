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
use_ok('EGTH::TrackHub');
use_ok('EGTH::TrackHub::Genome');
use_ok('EGTH::TrackHub::Track');

# Prepare dummy data
my %ex = (
  id             => 'th_id_1',
  shortLabel     => 'Trackhub_1',
  longLabel      => 'Trackhub number 1',
  descriptionUrl => 'http://example.org',
  email          => 'john@smith.org',
);
my $expected_hub = "hub $ex{id}
shortLabel $ex{shortLabel}
longLabel $ex{longLabel}
genomesFile genomes.txt
email $ex{email}
descriptionUrl $ex{descriptionUrl}
";

# Test creation of a TrackhubDB
throws_ok {
  my $th = EGTH::TrackHub->new();
  } 'Moose::Exception::AttributeIsRequired',
  "Creating a Trackhub object without any parameters should fail";

ok (
  my $th = EGTH::TrackHub->new(%ex),
  "Creating a Trackhub object with all required fields"
);
isa_ok(
  $th,
  'EGTH::TrackHub',
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
  $th->root_dir($tmp_dir.''),
  "Set directory to $tmp_dir"
);
ok(
  $th->make_hub_file,
  "Create hub file with defined dir"
);

my $hub_path = File::Spec->catfile(
  $th->hub_dir,
  $th->hub_file
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

# Try to create genomes files without genomes
dies_ok {
  my $genomes_content = $th->genomes_file_content;
} "Creating a genome file content without genomes should die";
dies_ok {
  $th->make_genomes_file;
} "Creating a genome file without genomes should die";

# Now, add a genome
my %genome_sample = (
  id  => 'genome_1',
);
ok(
  my $genome = EGTH::TrackHub::Genome->new(%genome_sample),
  "Create a genome"
);
ok(
  $th->add_genome($genome),
  "Add a genome to the TrackHub"
);
dies_ok {
  $th->add_genome($genome);
} "Add a genome to the TrackHub with the same id should fail";

# Create the genomes file
ok (
  my $genomes_content = $th->genomes_file_content,
  "Create a genome file content with genomes"
);
ok (
  $th->make_genomes_file,
  "Creating a genome file without genomes should die"
);

# Create genomes dirs
ok (
   $th->make_genomes_dirs,
  "Create genomes dirs",
);

# Make the trackdb files
dies_ok {
  $th->make_trackdb_files;
}  "Creating trackdb files without tracks should fail";

# Add a track to the genome
my %tr = (
  track      => 'track_1',
  shortLabel => 'track_title_1',
  longLabel  => 'Description of track 1',
  type       => 'bigwig',
  bigDataUrl => 'ftp://example.com/track1.bw',
);
my $track   = EGTH::TrackHub::Track->new( %tr );
$genome->add_track($track);

my $ret = $th->make_trackdb_files;

ok(
  $th->make_trackdb_files,
  "Creating trackdb files with 1 track"
);

done_testing();

