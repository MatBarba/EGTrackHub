package Bio::EnsEMBL::TrackHub::Hub::Track;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;
use Readonly;

use Moose;
use namespace::autoclean;

###############################################################################
# ATTRIBUTES
# As defined in https://genome.ucsc.edu/goldenPath/help/hgTrackHubHelp.html and
# https://genome.ucsc.edu/goldenPath/help/trackDb/trackDbHub.html
has [
  qw(
    track
    shortLabel
    longLabel
    bigDataUrl
    )
  ] => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  );
  
has type => (
  is       => 'rw',
  isa      => 'Str',
  required => 1
);

has [
  qw(
    html
    )
  ] => (
  is  => 'rw',
  isa => 'Str',
  );

has visibility => (
  is      => 'rw',
  isa     => 'Str|Undef',
  default => 'hide',
);

# Keep the order of parameters as a private attribute
my @order = qw(
  track
  type
  shortLabel
  longLabel
  bigDataUrl
  html
  visibility
);

has _order => (
  is      => 'rw',
  isa     => 'ArrayRef',
  default => sub { [@order] },
);

use overload '""' => 'to_string';

sub _prepare_data {
  my $self = shift;
  
  # Because crams are interpreted like bam, they use the same type...
  # http://genome.ucsc.edu/goldenPath/help/cram.html
  my $type = $self->type;
  if ($type and $type eq 'cram') {
    $type = 'bam';
  }

  my %data = (
    track      => $self->track,
    type       => $type,
    shortLabel => $self->shortLabel,
    longLabel  => $self->longLabel,
    bigDataUrl => $self->bigDataUrl,
    html       => $self->html,
    visibility => $self->visibility,
  );

  return %data;
}


###############################################################################
# INSTANCE METHODS

# INSTANCE METHOD
# Purpose   : returns the track text (for the file trackdb.txt) as a string
# Parameters: none
sub to_string {
  my $self = shift;
  my @lines;

  my %data = $self->_prepare_data;

  for my $item ( @{ $self->_order } ) {
    if ( defined $data{$item} ) {
      push @lines, $item . ' ' . $data{$item};
    }
  }

  return join( "\n", @lines ) . "\n";
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 DESCRIPTION

Object representing a track hub Track.

A Track object consists of a list of attributes (id, url, type...).

A track can also be a L<SuperTrack> or a L<SubTrack> (both inherit from this
object). In the second case, a "normal" Track is converted to a SubTrack when
it is added under a SuperTrack. So, in practice, there is no need to create a
SubTrack manually.

=head1 ATTRIBUTES

=over

=item I<track> 

A unique string identifying the track.

=item I<shortLabel>

A short string naming the track (i.e. a title).

=item I<longLabel>

A long string describing the track.

=item I<bigDataUrl>

URL string to the track file.

=item I<type>

The type of track. I.e. bigWig, bam, etc. NB: cram files are of type bam. See
all allowed types in
L<https://genome.ucsc.edu/goldenPath/help/trackDb/trackDbHub.html#commonSettings>.

=item I<html>

Path to a file describing the track in detail (optional).

=item I<visibility>

String value for setting whether the track is shown or hidden (default = 'hide').
Other possible values: dense, squish, pack, full.

=back

=head1 METHODS

=head2 new
 
To create a track object, all attributes (except html and visibility) need to be
set as parameters.

Usage:

  my $track = Bio::EnsEMBL::TrackHub::Hub::Track->new(
    track       => 'TrackName1',
    shortLabel  => 'Track 1',
    longLabel   => 'Description of track 1',
    bigDataUrl  => 'http://.../track1.bw',
    type        => 'bigWig',
    visibility  => 'full',
  );

=head2 to_string

Get the string of the track which can be used in the trackdb.txt file. This
file is created by the Genome object.

Usage:
  my $text = $track->to_string();

NB: Using the object in a string context will use this subroutine (overload).
  my $text = "$track";

=cut


