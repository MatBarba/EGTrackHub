#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use Test::More;
use Test::Exception;
use Test::File;
use File::Temp;
use Data::Dumper;

# checks if the modules can load
use_ok('EGTrackHubs::TrackHubDB');

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
descriptionUrl $ex{description_url}";

# Test creation of a TrackhubDB
throws_ok {
  my $th = EGTrackHubs::TrackHubDB->new();
} 'Moose::Exception::AttributeIsRequired', "Creating a Trackhub object without any parameters should fail";
throws_ok {
  my $th = EGTrackHubs::TrackHubDB->new(id => $ex{id});
} 'Moose::Exception::AttributeIsRequired', "Creating a Trackhub object without all required fields should fail";
ok (
  my $th = EGTrackHubs::TrackHubDB->new(%ex),
  "Creating a Trackhub object with all required fields"
);
isa_ok($th, 'EGTrackHubs::TrackHubDB', 'Right object created');
ok($th->id eq $ex{id}, "Correct id");

# Test writing to hub.txt
ok(
  my $hub = $th->create_hub_file_content, "Print TH hub.txt with all required data",
);
ok($hub eq $expected_hub, "Hub file content is as expected");


done_testing();

