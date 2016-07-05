#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use Test::More;
use Data::Dumper;
use Test::Exception;
use Test::File;
use File::Temp;

# -----
# checks if the modules can load
# -----
use_ok('EGTrackHubs::PlantTrackHubDB');

# -----
# test constructor
# -----

my $study_id  = "DRP000391";
my $plant_names = { 'oryza_sativa' => 1 };
my $email     = 'example@example.com';

ok(my $plant_trackhub = EGTrackHubs::PlantTrackHubDB->new(
  id       => $study_id,
  email    => $email,
), "Creating a plant trackhub object with correct attributes");

isa_ok($plant_trackhub, 'EGTrackHubs::PlantTrackHubDB', 'the object constructed is of my class type');

# Create the files in a temp dir
dies_ok {
  $plant_trackhub->create_files;
} "Creating the trackhub files should fail without a root dir";

my $tmp_dir = File::Temp->newdir();
dies_ok {
  $plant_trackhub->create_files( $tmp_dir . '' );
} "Creating all the trackhub files fail without any data";

dies_ok{
  $plant_trackhub->load_plant_data;
} "Loading plant data without plant names should fail";

ok(
  $plant_trackhub->load_plant_data($plant_names),
  "Load plant data with plant names"
);
ok($plant_trackhub->create_files( $tmp_dir . '' ), "Creating all the trackhub files in $tmp_dir");
sleep 60;

done_testing();

