package EGTrackHubs::ArrayExpress;

use strict;
use warnings;

use EGTrackHubs::JsonResponse;

# AE public server if the REST URLs
my $array_express_url = "http://www.ebi.ac.uk/fg/rnaseq/api/json/70";
#my $array_express_url =  "http://plantain:3000/json/70";   # AE private server if the REST URLs

# gives all distinct plant names with processed runs by ENA
my $plants_url = $array_express_url . "/getOrganisms/plants";


# On success: return a hash with keys = plant_names
# On failure: return undef
sub get_plant_names_AE_API {
    my %plant_names;

#response:
#[{"ORGANISM":"aegilops_tauschii","REFERENCE_ORGANISM":"aegilops_tauschii"},{"ORGANISM":"amborella_trichopoda","REFERENCE_ORGANISM":"amborella_trichopoda"},
#{"ORGANISM":"arabidopsis_kamchatica","REFERENCE_ORGANISM":"arabidopsis_lyrata"},{"ORGANISM":"arabidopsis_lyrata","REFERENCE_ORGANISM":"arabidopsis_lyrata"},
#{"ORGANISM":"arabidopsis_lyrata_subsp._lyrata","REFERENCE_ORGANISM":"arabidopsis_lyrata"},{"ORGANISM":"arabidopsis_thaliana","REFERENCE_ORGANISM":"arabidopsis_thaliana"},
  
    try {
        my $plants_data = EGTrackHubs::JsonResponse::get_Json_response($plants_url);

        foreach my $plant_data_ref (@$plants_data) {
            # this hash has all possible names of plants that Robert is using in his REST calls;
            # I get them from here: http://www.ebi.ac.uk/fg/rnaseq/api/json/70/getOrganisms/plants
            $plant_names{ $plant_data_ref->{"REFERENCE_ORGANISM"} } = 1;
        }

        return \%plant_names;
    } catch {
      return;
    }
}

# No study: return undef
# On success: return json ref
# On failure: die
sub get_runs_json_for_study {
    my $study_id = shift;
    
    if (defined $study_id) {
      my $url = "$array_express_url/getRunsByStudy/$study_id";
      return EGTrackHubs::JsonResponse::get_Json_response($url);
    } else {
      return;
    }
}

# Return all studies with status "Complete"
sub get_completed_study_ids_for_plants
{
    my ($plant_names_href_EG) = @_;

    my %study_ids;
    
    # gets all the bioreps by organism to date that AE has processed so far
    my $get_runs_by_organism_endpoint = $array_express_url . "/getRunsByOrganism/";

    my $n = 0;
    foreach my $plant_name ( keys %{$plant_names_href_EG} ) {
        my $biorep_url = $get_runs_by_organism_endpoint . $plant_name;
        my $biorep_stanza_json = EGTrackHubs::JsonResponse::get_Json_response($biorep_url);

        foreach my $hash_ref (@$biorep_stanza_json) {
          if ( $hash_ref->{"STATUS"} eq "Complete" ) {
            $study_ids{ $hash_ref->{"STUDY_ID"} } = 1;
          }
        }
        $n++;
    }

    return \%study_ids;
}

sub get_study_ids_for_plant {
    my $plant_name = shift;
    return if not $plant_name;
    
    my $url = "$array_express_url/getRunsByOrganism/$plant_name";

    my %study_ids;

#response:
#[{"STUDY_ID":"DRP000315","SAMPLE_IDS":"SAMD00009892","BIOREP_ID":"DRR000749","RUN_IDS":"DRR000749","ORGANISM":"oryza_sativa_japonica_group","REFERENCE_ORGANISM":"oryza_sativa","STATUS":"Complete","ASSEMBLY_USED":"IRGSP-1.0","ENA_LAST_UPDATED":"Fri Jun 19 2015 17:39:45","LAST_PROCESSED_DATE":"Mon Sep 07 2015 00:39:36","CRAM_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000749/DRR000749.cram","MAPPING_QUALITY":70},
    
    try {
      my $plant_names_json = EGTrackHubs::JsonResponse::get_Json_response($url);

      foreach my $hash_ref (@$plant_names_json) {
        if ( $hash_ref->{"STATUS"} eq "Complete" ) {
          # this hash has all possible names of plants that Robert is using in his REST calls;
          # I get them from here: http://www.ebi.ac.uk/fg/rnaseq/api/json/70/getOrganisms/plants
          $study_ids{ $hash_ref->{"STUDY_ID"} } = 1;
        }
      }

      return \%study_ids;
    } catch {
      return;
    }
}

1;
