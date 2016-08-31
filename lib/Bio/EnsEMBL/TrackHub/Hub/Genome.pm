package Bio::EnsEMBL::TrackHub::Hub::Genome;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;

use Moose;
use namespace::autoclean;
use File::Path qw(make_path);

use Bio::EnsEMBL::TrackHub::Hub::Track;

###############################################################################
# ATTRIBUTES
# As defined in https://genome.ucsc.edu/goldenPath/help/hgTrackHubHelp.html
has id => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has insdc => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has hub_dir => (
  is     => 'rw',
  isa    => 'Str',
  writer => '_set_hub_dir',
  reader => '_get_hub_dir',
);

has genome_dir => (
  is  => 'rw',
  isa => 'Str',
);

has trackdb_file => (
  is      => 'rw',
  isa     => 'Str',
  default => 'trackdb.txt',
);

has tracks => (
  is      => 'rw',
  isa     => 'HashRef[Bio::EnsEMBL::TrackHub::Hub::Track]',
  default => sub { {} },
);

###############################################################################
# ATTRIBUTES BUILDERS

# Purpose   : Set the hub_dir (and derive the genome_dir from it)
# Parameters: hub dir
sub hub_dir {
  my $self = shift;
  my ($dir) = @_;

  if ( defined $dir ) {
    $self->_set_hub_dir($dir);
    $self->_update_genome_dir;
  }

  return $self->_get_hub_dir;
}

# Purpose   : Define the genome_dir based on the hub_dir
# Parameters: none
sub _update_genome_dir {
  my ($self) = shift;
  die "Can't update genome dir if the hub dir is not defined"
    if not defined $self->_get_hub_dir;

  my $genome_dir = File::Spec->catfile( $self->_get_hub_dir, $self->id );
  $self->genome_dir($genome_dir);
}

###############################################################################
# INSTANCE METHODS

# INSTANCE METHOD
# Purpose   : create the text content of genomes.txt
# Parameters: none
sub config_text {
  my $self = shift;

  if ( not defined $self->genome_dir ) {
    croak "Can't create config text without a directory.";
  }

  # Create the path NB: here we want the relative path, so we use the id as directory
  my $trackdb_path = File::Spec->catfile( $self->id, $self->trackdb_file );

  my %content = (
    genome  => $self->id,
    trackDb => $trackdb_path,
  );
  my @content_order = qw(
    genome
    trackDb
  );

  my @lines;
  my %missing_keys;
  for my $key (@content_order) {
    if ( defined $content{$key} ) {
      push @lines, "$key $content{$key}";
    }
    else {
      $missing_keys{$key}++;
    }
  }

  if (%missing_keys) {
    croak "Missing keys: " . join( ', ', sort keys %missing_keys );
  }

  return join( "\n", @lines ) . "\n";
}

# INSTANCE METHOD
# Purpose   : Create a subdirectory for this genome
# Parameters: none
sub make_genome_dir {
  my $self = shift;

  if ( not defined $self->genome_dir ) {
    croak "Can't create genome file without a directory.";
  }

  make_path $self->genome_dir;
  return 1;
}

# INSTANCE METHOD
# Purpose   : Append a Track object to the list of the genome
# Parameters: A Bio::EnsEMBL::TrackHub::Hub::Track object
sub add_track {
  my $self = shift;
  my ($track) = @_;

  if ( not $track ) {
    carp "Warning: no track given to add to the genome";
    return;
  }
  $self->tracks->{ $track->track } = $track;
  return 1;
}

# INSTANCE METHOD
# Purpose   : Create a trackdb file
# Parameters: none
sub make_trackdb_file {
  my $self = shift;

  # Init file
  my $trackdb_file =
    File::Spec->catfile( $self->genome_dir, $self->trackdb_file );
  open( my $trackdb_fh, '>', $trackdb_file );
  print $trackdb_fh $self->trackdb_file_content;
  close $trackdb_fh;
  return 1;
}

# INSTANCE METHOD
# Purpose   : prepare the trackdb.txt file content
# Parameters: none
sub trackdb_file_content {
  my $self = shift;

  croak "Can't create trackdb content without tracks"
    if not keys %{ $self->tracks };

  my @track_lines;
  foreach my $track_id ( keys %{ $self->tracks } ) {
    my $track = $self->tracks->{$track_id};
    push @track_lines, $track->to_string;
  }

  return join( "\n\n", @track_lines );
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 DESCRIPTION

Object representing a track hub Genome.

A Genome object consists of an id, an INSDC accession and a list of
Bio::EnsEMBL::TrackHub::Hub::Track.

=head1 ATTRIBUTES

=over

=item I<id> 

A unique string identifying the Genome. This must be an accession identifier.

=item I<insdc>

A string: INSDC accession for this assembly.

=item I<hub_dir>

Dir where the parent hub is installed. NB: this parameter is automatically
set by the Hub object when the genome is added to it.

=back

=head1 METHODS

=head2 new

Only the 3 attributes id, shortLabel and longLabel are mandatory to create an
object. But the root_dir is mandatory to create the files, and the server_dir
to register the track hub.

Usage:

  my $genome = Bio::EnsEMBL::TrackHub::Hub::Genome->new(
    id    => 'Assembly_name',
    insdc => 'GCA00000000',
  );

=head2 config_text

Create and returns the text content of genomes.txt. This is used by the Hub
object to create the file.

Usage:
  my $text = $genome->config_text();

=head2 add_track

Append a new L<Bio::EnsEMBL::TrackHub::Hub::Track> object to the genome.

Usage:

  $genome->add_track($track_object);


=cut

