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
use FindBin;
use lib $FindBin::Bin . '/../lib';
use_ok('Bio::EnsEMBL::TrackHub::Hub::SubTrack');

# Prepare dummy data
my %tr = (
  track      => 'track_1',
  shortLabel => 'track_title_1',
  longLabel  => 'Description of track 1',
  type       => 'bigwig',
  bigDataUrl => 'ftp://example.com/track1.bw',
);
my $parent_id             = 'supertrack_A';
my $expected_trackdb_text = "track $tr{track}
type $tr{type}
shortLabel $tr{shortLabel}
longLabel $tr{longLabel}
bigDataUrl $tr{bigDataUrl}
visibility hide
parent $parent_id
";

dies_ok {
  my $track = Bio::EnsEMBL::TrackHub::Hub::SubTrack->new;
}
"Creating a track without id should fail";

dies_ok {
  my $track = Bio::EnsEMBL::TrackHub::Hub::SubTrack->new(%tr),
}
"Creating a subtrack without parent should fail";

$tr{parent} = $parent_id;
ok(
  my $track = Bio::EnsEMBL::TrackHub::Hub::SubTrack->new(%tr),
  "Create 1 generic track"
);

cmp_ok(
  $track->to_string,
  'eq',
  $expected_trackdb_text,
  "Trackdb text from track is as expected"
);

done_testing();

