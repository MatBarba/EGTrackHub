package EGTH::PlantTrackHub;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;
use Log::Log4perl qw( :easy );
my $logger = get_logger();
use Data::Dumper;

use Moose;
extends 'EGTH::TrackHub';
use namespace::autoclean;

use Getopt::Long;          # to use the options when calling the script
use POSIX qw(strftime);    # to get GMT time stamp
use EGTH::ENA;
use EGTH::EG;
use EGTH::AEStudy;
use EGTH::TrackHub::SubTrack;
use EGTH::TrackHub::SuperTrack;

sub load_plant_data {
  my $self = shift;
  my ( $plant_names, $assembly_map ) = @_;

  $logger->info( "Load study " . $self->id );
  my $ae_study = EGTH::AEStudy->new(
    study_id    => $self->id,
    plant_names => $plant_names
  );
  $logger->info("Load data for the study");
  $self->_load_study( $ae_study, $assembly_map );

  return 1;
}

sub _load_study {
  my $self = shift;
  my ( $study, $assembly_map ) = @_;

  $self->prepare_hub();
  $self->prepare_genomes( $study, $assembly_map );
}

sub prepare_hub {
  my $self = shift;

  $logger->info("Prepare HUB text");
  my $study_id = $self->id;

  # Short label
  $self->shortLabel("RNA-Seq alignment hub $study_id");

  # Long label: use study description
  my $ena_study_title = EGTH::ENA::get_ENA_study_title($study_id);

  if ( $ena_study_title eq "not yet in ENA" ) {
    croak "Study is not yet in ENA: $study_id";
  }

  if ( $ena_study_title eq "Study title was not found in ENA" ) {
    carp "I cannot get study title for $study_id from ENA\n";
    $self->longLabel(
      "<a href=\"http://www.ebi.ac.uk/ena/data/view/$study_id\">$study_id</a>"
    );
  }
  else {
    $self->longLabel(
      "$ena_study_title; <a href=\"http://www.ebi.ac.uk/ena/data/view/$study_id\">$study_id</a>"
    );
  }
  return 1;
}

sub prepare_genomes {
  my $self = shift;
  my ( $study, $assembly_map ) = @_;

  $logger->info("Prepare Genomes");
  my $assembly_names = $study->get_assembly_names;
  my $study_id       = $study->id;

  # Create genomes
  foreach my $aname ( keys %{$assembly_names} ) {
    $logger->warn("Assembly: $aname");
    my $genome = EGTH::TrackHub::Genome->new(
      id      => $aname,
      insdc   => $assembly_map->{$aname},
      hub_dir => $self->hub_dir
    );

    # Add the tracks for this study and genome
    my @sample_ids = keys %{ $study->get_sample_ids($aname) };

    if ( @sample_ids == 0 ) {
      croak "No samples found for study $study_id";
    }

    my $num_tracks = 0;
    foreach my $sample_id (@sample_ids) {
      $logger->info("Sample: $sample_id");
      my $super_track = $self->make_biosample_super_track_obj($sample_id);

      # Load all different tracks for this sample under the same supertrack
      my $bioreps = $study->get_biorep_ids_from_sample_id($sample_id);
      foreach my $biorep_id ( keys %$bioreps ) {
        $logger->info("Biorep: $biorep_id");

        # Create a subtrack
        my $sub_track =
          $self->make_biosample_sub_track_obj( $study, $biorep_id, $sample_id );
        $sub_track->visibility( $num_tracks > 10 ? 'hide' : 'pack' );

        # Add this subtrack to the supertrack
        $super_track->add_sub_track($sub_track);

        $num_tracks++;
      }

      $genome->add_track($super_track);
    }

    # Add this populated genome to the trackhub
    $self->add_genome($genome);
  }
}

# i want they key of the key-value pair of the metadata to have "_" instead of space if they are more than 1 word
sub printlabel_key {

  my $string = shift;
  my @array = split( / /, $string );

  if ( scalar @array > 1 ) {
    $string =~ s/ /_/g;

  }
  return $string;
}

# I want the value of the key-value pair of the metadata to have quotes in the whole string if the value is more than 1 word.
sub printlabel_value {

  my $string = shift;
  my @array = split( / /, $string );

  if ( scalar @array > 1 ) {

    $string = "\"" . $string . "\"";

  }
  return $string;
}

sub get_ENA_biorep_title {

  my $study_obj = shift;
  my $biorep_id = shift;

  my $biorep_title;
  my %run_titles;

  my @run_ids = @{ $study_obj->get_run_ids_of_biorep_id($biorep_id) };

  if ( scalar @run_ids > 1 ) {    # then it is a clustered biorep
    foreach my $run_id (@run_ids) {

      $run_titles{ EGTH::ENA::get_ENA_title($run_id) } = 1; # I get all distinct run titles
    }
    my @distinct_run_titles = keys(%run_titles);
    $biorep_title = join( " ; ", @distinct_run_titles ); # the run titles are seperated by comma

    return $biorep_title;
  }
  else {    # the biorep_id is the same as a run_id
    return EGTH::ENA::get_ENA_title($biorep_id);
  }
}

sub make_biosample_super_track_obj {

  # i need 3 pieces of data to make the track obj :  track_name, long_label , metadata
  my $self      = shift;
  my $sample_id = shift;    # track name

  my $ena_sample_title = EGTH::ENA::get_ENA_title($sample_id);
  my $short_label      = $sample_id;
  my $long_label;

  # there are cases where the sample doesnt have title ie : SRS429062 doesn't have sample title
  if ( $ena_sample_title and $ena_sample_title !~ /^ *$/ ) {
    $long_label =
        "$ena_sample_title ; <a href=\"http://www.ebi.ac.uk/ena/data/view/"
      . $sample_id . "\">"
      . $sample_id . "</a>";

  }
  else {
    $long_label =
        "<a href=\"http://www.ebi.ac.uk/ena/data/view/"
      . $sample_id . "\">"
      . $sample_id . "</a>";
    print STDERR
      "Could not get sample title from ENA API for sample $sample_id\n\n";

  }

  my $date_string = strftime "%a %b %e %H:%M:%S %Y %Z", gmtime; # date is of this type: "Tue Feb  2 17:57:14 2016 GMT"
  my $metadata_string =
      "hub_created_date="
    . printlabel_value($date_string)
    . " biosample_id="
    . $sample_id;

  my $meta_keys_aref = EGTH::ENA::get_all_sample_keys(); # array ref that has all the keys for the ENA warehouse metadata
                                                         # returns a has ref or 0 if unsuccessful
  my $metadata_respose =
    EGTH::ENA::get_sample_metadata_response_from_ENA_warehouse_rest_call(
    $sample_id, $meta_keys_aref );
  if ( $metadata_respose == 0 ) {

    print STDERR
      "No metadata values found in ENA warehouse for sample $sample_id\n";
    return 0;

  }
  else {                                                 # if there is metadata
    my %metadata_pairs = %{$metadata_respose};
    my @meta_pairs;

    foreach my $meta_key ( keys %metadata_pairs ) { # printing the sample metadata

      my $meta_value = $metadata_pairs{$meta_key};
      my $pair =
        printlabel_key($meta_key) . "=" . printlabel_value($meta_value);
      push( @meta_pairs, $pair );
    }
    $metadata_string = $metadata_string . " " . join( " ", @meta_pairs );
  }

  my $super_track_obj = EGTH::TrackHub::SuperTrack->new(
    track      => $sample_id,
    shortLabel => $short_label,
    longLabel  => $long_label,

    # Metadata is deprecated
    #$metadata_string
  );
  return $super_track_obj;
}

sub make_biosample_sub_track_obj {

  # i need 5 pieces of data to make the track obj, to return:  track_name, parent_name, big_data_url , long_label ,file_type
  my $self = shift;

  my $study_obj  = shift;
  my $biorep_id  = shift;    #track name
  my $parent_id  = shift;
  my $visibility = shift;

  #my $big_data_url = $study_obj->get_big_data_file_location_from_biorep_id($biorep_id);

  my $study_id = $study_obj->id;

  $logger->debug("Get ENA cram location for $biorep_id");
  my $big_data_url = EGTH::ENA::get_ENA_cram_location($biorep_id);

  if ( !$big_data_url ) { # if the cram file is not yet in ENA the method ENA::get_ENA_cram_location($biorep_id) returns 0

    print STDERR
      "This biorep id $biorep_id (study id $study_id) has not yet its CRAM file in ENA\n";
    return "no cram in ENA";
  }
  my $short_label_ENA;
  my $long_label_ENA;

  $logger->debug("Get ENA biorep title for $biorep_id");
  my $ena_title = get_ENA_biorep_title( $study_obj, $biorep_id );

  if ( $biorep_id !~ /biorep/ ) {
    $short_label_ENA = "ENA Run:$biorep_id";

    if ( !$ena_title ) {    # if return is 0
      print STDERR
        "Biorep id $biorep_id of study id $study_id was not found to have a title in ENA\n\n";
      $long_label_ENA =
          "<a href=\"http://www.ebi.ac.uk/ena/data/view/"
        . $biorep_id . "\">"
        . $biorep_id . "</a>";

    }
    elsif ( $ena_title eq "not yet in ENA" ) {
      print STDERR
        "Biorep id $biorep_id of study id $study_id is not yet in ENA, this track will not be written in the trackDb.txt file of the TH\n\n";
      return 0;
    }
    else {
      $long_label_ENA =
          $ena_title
        . " ; <a href=\"http://www.ebi.ac.uk/ena/data/view/"
        . $biorep_id . "\">"
        . $biorep_id . "</a>";
    }

  }
  else {    # run id would be "E-MTAB-2037.biorep4"

    $short_label_ENA = "ArrayExpress:$biorep_id";
    my $biorep_accession;
    if ( $biorep_id =~ /(.+)\.biorep.*/ ) {
      $biorep_accession = $1;
    }

    if ( !$ena_title ) {
      print STDERR
        "first run of biorep id $biorep_id of study id $study_id was not found to have a title in ENA\n\n";

      # i want the link to be like: http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/E-GEOD-55482.bioreps.txt
      $long_label_ENA =
        "<a href=\"http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/"
        . $1
        . ".bioreps.txt" . "\">"
        . $biorep_id . "</a>";

    }
    else {
      $long_label_ENA =
          $ena_title
        . ";<a href=\"http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/"
        . $biorep_accession
        . ".bioreps.txt" . "\">"
        . $biorep_id . "</a>";
    }
  }

  $logger->debug("Get ENA data type for $big_data_url");
  my $file_type = EGTH::ENA::give_big_data_file_type($big_data_url);
  my $track_obj = EGTH::TrackHub::SubTrack->new(
    track      => $biorep_id,
    parent     => $parent_id,
    bigDataUrl => $big_data_url,
    shortLabel => $short_label_ENA,
    longLabel  => $long_label_ENA,
    type       => $file_type,
    visibility => $visibility
  );
  return $track_obj;

}

1;
