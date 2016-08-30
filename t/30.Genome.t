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
use_ok('Bio::EnsEMBL::TrackHub::Hub::Genome');

# Prepare dummy data
my %ex = (
  id    => 'genome_id_1',
  insdc => 'GCA00000001.1',
);
my %tr = (
  track      => 'track_1',
  shortLabel => 'track_title_1',
  longLabel  => 'Description of track 1',
  type       => 'bigwig',
  bigDataUrl => 'ftp://example.com/track1.bw',
);
my $expected_trackdb_text = "track $tr{track}
shortLabel $tr{shortLabel}
longLabel $tr{longLabel}
type $tr{type}
bigDataUrl $tr{bigDataUrl}
";

# Test creation of a Genome
throws_ok {
  my $gen = Bio::EnsEMBL::TrackHub::Hub::Genome->new();
}
'Moose::Exception::AttributeIsRequired',
  "Creating a Genome object without any parameters should fail";

ok(
  my $gen = Bio::EnsEMBL::TrackHub::Hub::Genome->new(%ex),
  "Creating a Genome object with all required fields"
);
isa_ok(
  $gen,
  'Bio::EnsEMBL::TrackHub::Hub::Genome',
  'Right object created'
);
cmp_ok(
  $gen->id, 'eq', $ex{id},
  "Correct id"
);

# Create directory for trackdb files

dies_ok {
  $gen->make_genome_dir
}
"Create genome dir without defined dir should fail";

# Create genome dir
my $tmp_dir = File::Temp->newdir;
ok(
  $gen->hub_dir( $tmp_dir . '' ),
  "Set directory to $tmp_dir"
);
ok(
  $gen->make_genome_dir,
  "Create genome dir with defined dir"
);

my $genome_dir_path = File::Spec->catfile(
  $gen->hub_dir,
  $gen->id
);
ok(
  -d $genome_dir_path,
  "Genome dir created"
);

# Now create the trackDB file
dies_ok {
  $gen->make_trackdb_file;
}
"Create trackdb file without tracks should die";

# Add a track and create the file
#ok(
#  not $gen->add_track(),
#  "Adding undef track should fail (but not die)"
#);

ok(
  my $track = Bio::EnsEMBL::TrackHub::Hub::Track->new(%tr),
  "Create 1 generic track"
);

ok(
  $gen->add_track($track),
  "Add 1 generic track"
);

ok(
  $gen->make_trackdb_file,
  "Create trackdb file with 1 generic track"
);

done_testing();

