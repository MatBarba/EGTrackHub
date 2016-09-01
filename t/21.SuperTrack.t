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
use_ok('Bio::EnsEMBL::TrackHub::Hub::SuperTrack');
use_ok('Bio::EnsEMBL::TrackHub::Hub::Track');

# Prepare dummy data
my %super = (
  track      => 'supertrack_1',
  shortLabel => 'Supertrack_title_1',
  longLabel  => 'Description of supertrack 1',
  type       => 'bigwig',
);
my %sub = (
  track      => 'track_1',
  shortLabel => 'track_title_1',
  longLabel  => 'Description of track 1',
  type       => 'bigwig',
  bigDataUrl => 'ftp://example.com/track1.bw',
  parent     => $super{track},
);

my $expected_super_text = "track $super{track}
type $super{type}
shortLabel $super{shortLabel}
longLabel $super{longLabel}
superTrack on show
";
my $expected_sub_text = "track $sub{track}
type $sub{type}
shortLabel $sub{shortLabel}
longLabel $sub{longLabel}
bigDataUrl $sub{bigDataUrl}
visibility hide
";
my $expected_trackdb_text =
  $expected_super_text . "\n" . $expected_sub_text . "parent $sub{parent}\n";

dies_ok {
  my $supertrack = Bio::EnsEMBL::TrackHub::Hub::SuperTrack->new;
}
"Creating a super-track without id should fail";

ok(
  my $supertrack = Bio::EnsEMBL::TrackHub::Hub::SuperTrack->new(%super),
  "Create 1 super-track"
);

ok(
  my $subtrack = Bio::EnsEMBL::TrackHub::Hub::Track->new(%sub),
  "Create 1 sub-track as a normal track"
);
cmp_ok(
  $subtrack->to_string,
  'eq',
  $expected_sub_text,
  "Trackdb text from subtrack is as expected"
);

dies_ok {
  $supertrack->add_sub_track,
}
"Adding an undef sub-track should fail";

ok(
  $supertrack->add_sub_track($subtrack),
  "Add the subtrack to the super-track"
);

cmp_ok(
  $supertrack->to_string,
  'eq',
  $expected_trackdb_text,
  "Trackdb text from track is as expected"
);

done_testing();

