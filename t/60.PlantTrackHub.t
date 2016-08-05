#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use Test::More;
use Data::Dumper;
use Test::Exception;
use Test::File;
use File::Temp;
use Log::Log4perl qw( :easy );

#Log::Log4perl->easy_init($WARN);

# -----
# checks if the modules can load
# -----
use_ok('EGTH::PlantTrackHub');

# -----
# test constructor
# -----

my $study_id     = "DRP000391";
my $plant_names  = [qw( oryza_sativa )];
my %assembly_map = (
  'IRGSP-1.0' => 'GCA_001433935.1',
);
my $email = 'example@example.com';

ok(
  my $plant_trackhub = EGTH::PlantTrackHub->new(
    id    => $study_id,
    shortLabel  => 'Label_for_'.$study_id,
    longLabel   => 'Long_label_for_'.$study_id,
    email => $email,
  ),
  "Creating a plant trackhub object with correct attributes"
);

isa_ok(
  $plant_trackhub, 'EGTH::PlantTrackHub',
  'the object constructed is of my class type'
);

# Create the files in a temp dir
dies_ok {
  $plant_trackhub->create_files;
}
"Creating the trackhub files should fail without a root dir";

my $tmp_dir = File::Temp->newdir();
dies_ok {
  $plant_trackhub->create_files( $tmp_dir . '' );
}
"Creating all the trackhub files fail without any data";

dies_ok {
  $plant_trackhub->load_plant_data;
}
"Loading plant data without parameters should fail";

dies_ok {
  $plant_trackhub->load_plant_data($plant_names),
}
"Loading plant data without assembly map should fail";

ok(
  $plant_trackhub->load_plant_data( $plant_names, \%assembly_map ),
  "Load plant data with plant names and assembly map"
);
ok(
  $plant_trackhub->create_files( $tmp_dir . '' ),
  "Creating all the trackhub files in $tmp_dir"
);
sleep 60;

done_testing();

