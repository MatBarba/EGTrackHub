package Bio::EnsEMBL::TrackHub::Hub;

use strict;
use warnings;
use autodie;
use Carp;
use Log::Log4perl qw(:easy);
my $logger = get_logger();

use Moose;
use namespace::autoclean;
use File::Spec;
use File::Path qw(make_path);

use Bio::EnsEMBL::TrackHub::Hub::Genome;

###############################################################################
# ATTRIBUTES
# As defined in https://genome.ucsc.edu/goldenPath/help/hgTrackHubHelp.html
has id => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has [
  qw(
    shortLabel
    longLabel
    )
  ] => (
  is       => 'rw',
  isa      => 'Str',
  required => 1,
);

has [
  qw(
    email
    descriptionUrl
    )
  ] => (
  is  => 'rw',
  isa => 'Str',
  );

has hub_file => (
  is      => 'ro',
  isa     => 'Str',
  default => 'hub.txt'
);

has genomes_file => (
  is      => 'rw',
  isa     => 'Str',
  default => 'genomes.txt'
);

has root_dir => (
  is     => 'rw',
  isa    => 'Str',
  writer => '_set_root_dir',
  reader => '_get_root_dir',
);

has hub_dir => (
  is  => 'rw',
  isa => 'Str',
);

has server => (
  is  => 'rw',
  isa => 'Str',
);

has url => (
  is  => 'rw',
  isa => 'Str',
  lazy    => 1,
  'builder' => '_build_hub_url',
);

has genomes => (
  is      => 'rw',
  isa     => 'HashRef[Bio::EnsEMBL::TrackHub::Hub::Genome]',
  default => sub { {} },
);

###############################################################################
# ATTRIBUTES BUILDERS

# Purpose   : Set the root_dir (and derive the hub_dir from it)
# Parameters: root dir
sub root_dir {
  my $self = shift;
  my ($root_dir) = @_;

  if ( defined $root_dir ) {
    $self->_set_root_dir($root_dir);
    $self->update_hub_dir;
  }

  return $self->_get_root_dir;
}

# Purpose   : Define the hub_dir based on the root_dir
# Parameters: none
sub update_hub_dir {
  my ($self) = shift;
  
  die "Can't update hub dir if the root dir is not defined"
    if not defined $self->_get_root_dir;

  my $hub_dir = File::Spec->catfile( $self->_get_root_dir, $self->id );
  $self->hub_dir($hub_dir);
}

# Purpose   : Create the hub url
# Parameters: none
sub _build_hub_url {
  my $self = shift;
  
  die "Can't create hub url without server" if not $self->server;
  
  return $self->server . '/' . $self->id . '/' . $self->hub_file;
}

###############################################################################
# INSTANCE METHODS

# INSTANCE METHOD
# Purpose   : create all the files of a track hub
# Parameters: a directory used as root to create the filesV
sub create_files {
  my ( $self, $root_dir ) = @_;

  $self->root_dir($root_dir) if $root_dir;

  # Make trackhub dir
  make_path $self->hub_dir;

  # Generate files
  $self->make_hub_file();
  $self->make_genomes_file();
  $self->make_genomes_dirs();
  $self->make_trackdb_files();
  return 1;
}

# INSTANCE METHOD
# Purpose   : create the hub.txt file
# Parameters: none
sub make_hub_file {
  my $self = shift;

  croak "Can't create hub file without a directory."
    if ( not defined $self->hub_dir );
  my $hub_path = File::Spec->catfile( $self->hub_dir, $self->hub_file );

  make_path $self->hub_dir;
  open my $hub_fh, '>', $hub_path;
  print $hub_fh $self->hub_file_content;
  close $hub_fh;
  return 1;
}

# INSTANCE METHOD
# Purpose   : prepare the hub.txt file content
# Parameters: none
sub hub_file_content {
  my $self = shift;

  my %content = (
    hub            => $self->id,
    shortLabel     => $self->shortLabel,
    longLabel      => $self->longLabel,
    genomesFile    => $self->genomes_file,
    email          => $self->email,
    descriptionUrl => $self->descriptionUrl,
  );
  my @content_order = qw(
    hub
    shortLabel
    longLabel
    genomesFile
    email
    descriptionUrl
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

  #if (%missing_keys) {
  #  croak "Missing keys: " . join(', ', sort keys %missing_keys);
  #}

  return join( "\n", @lines ) . "\n";
}

# INSTANCE METHOD
# Purpose   : create the genomes.txt file
# Parameters: none
sub make_genomes_file {
  my $self = shift;

  if ( not defined $self->hub_dir ) {
    croak "Can't create genomes file without a directory.";
  }
  elsif ( not keys %{ $self->genomes } ) {
    croak "Can't create genomes files without any genome assemblies";
  }
  my $genomes_path = File::Spec->catfile( $self->hub_dir, $self->genomes_file );

  open my $genomes_fh, '>', $genomes_path;
  print $genomes_fh $self->genomes_file_content;
  close $genomes_fh;
  return 1;
}

# INSTANCE METHOD
# Purpose   : prepare the genomes.txt file content
# Parameters: none
sub genomes_file_content {
  my $self = shift;

  if ( not keys %{ $self->genomes } ) {
    croak "Can't create genomes files without any genome assemblies";
  }
  my @lines;
  for my $genome_id ( keys %{ $self->genomes } ) {
    my $genome = $self->genomes->{$genome_id};
    push @lines, $genome->config_text;
  }
  return join "\n\n", @lines;
}

# INSTANCE METHOD
# Purpose   : Create a subdirectory for each genome
# Parameters: none
sub make_genomes_dirs {
  my $self = shift;

  for my $genome_id ( keys %{ $self->genomes } ) {
    my $genome = $self->genomes->{$genome_id};
    $genome->make_genome_dir;
  }
  return 1;
}

# INSTANCE METHOD
# Purpose   : Create all the trackdb files for all genomes
# Parameters: none
sub make_trackdb_files {
  my $self = shift;

  for my $genome_id ( keys %{ $self->genomes } ) {
    my $genome = $self->genomes->{$genome_id};
    $genome->make_trackdb_file;
  }
  return 1;
}

# INSTANCE METHOD
# Purpose   : Append a Genome object to the list of the hub
# Parameters: A Bio::EnsEMBL::TrackHub::Hub::Genome object
sub add_genome {
  my $self = shift;
  my ($genome) = @_;

  if ( defined $self->genomes->{ $genome->id } ) {
    croak "The trackhub already has a genome named $genome->id";
  }
  my $genomes = $self->genomes->{ $genome->id } = $genome;
  $genomes->hub_dir( $self->hub_dir );
  return 1;
}

# INSTANCE METHOD
# Purpose   : Export a mapping for the assembly id to the INSDC id
#             (to use for the Track Hub Registry submission)
# Parameters: none
sub assembly_map {
  my $self = shift;

  my %map;
  my %genomes = %{ $self->genomes };
  for my $genome_id ( keys %genomes ) {
    $logger->debug("Map assembly for $genome_id");
    $map{$genome_id} = $genomes{$genome_id}->insdc;
  }
  return \%map;
}


__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 DESCRIPTION

Object representing a track hub.

A track hub object consists of a list of required parameters (id, labels) and
a list of Genomes objects.

=head1 ATTRIBUTES

=over

=item I<id> 

A unique string to identify the hub.

=item I<shortLabel>

A small string naming the hub (i.e. a human readable title).

=item I<longLabel>

A long string describing the hub.

=item I<email>

An email address for contact about this hub.

=item I<root_dir>

Root dir where the hub files will be created.

=item I<server>

Root url where the hub should be accessed once registered.

=item I<descriptionUrl>

(Optional) A url where the hub is described in detail.

=back

=head1 METHODS

=head2 new

Only the 3 attributes id, shortLabel and longLabel are mandatory to create an
object. But the root_dir is mandatory to create the files, and the server_dir
to register the track hub.

Usage:

  my $track_hub = Bio::EnsEMBL::TrackHub::Hub->new(
    id          => 'Foo1',
    shortLabel  => "Foobar title",
    longLabel   => "Long decription of Foobar experiment.",
  );
  $track_hub->root_dir('path/to/hub_root');

=head2 create_files

The main method of this object: create all the files defined for this object in
the root_dir. The directory structure is created as follows:

  root_dir/
    id/
      hub.txt
      genomes.txt
      genome1/
      genome2/
      ...

=head2 add_genome

Append a new L<Bio::EnsEMBL::TrackHub::Hub::Genome> object to the hub collection.

Usage:

  $hub->add_genome($genome_object);

=head2 assembly_map

Create a mapping between the genome ids (defined in genomes.txt) and the
corresponding INSDC accession for this assembly. This information needs to be
defined in each Genome object.

This method is used by the L<Bio::EnsEMBL::TrackHub::Registry> object to submit
the hub to the Track Hub Registry.

Usage:

  my $map_href = $hub->assembly_map();

=cut

