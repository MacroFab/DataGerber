#
#
# Basic Gerber Operations
# (c) 2014 MacroFab, Inc.
# Author: C. A. Church
# Version 0.02 Contributor: 
# D. Calderon
#===========================================================


package Data::Gerber;

use strict;
use warnings;
use Data::Dumper;
use Math::Round;

our $VERSION = "0.02";

=head1 NAME

 Data::Gerber

=cut

=head1 SYNOPSIS

	my $gerb = Data::Gerber->new();
	
	$gerb->format( 'zero' => 'L', 'coordinates' => 'A', 
		       'format'	=> { 'integer'	=> 2, 'decimal'	=> 4 } );
 	
	$gerb->mode('IN');
	
	$gerb->aperture( 'code' => 'D11', 'type' => 'C', 'modifiers' => '0.0100' );
	
	my $aper = $gerb->aperture( 'code' => 'D11' );
	
	$gerb->function( 'aperture' => 'D11' );
	$gerb->function( 'func' => 'G01', 'coord' => 'X010000Y010000', 'op' => 'D01' )
	$gerb->function( 'func' => 'M02' );
	
=cut

=head1 DESCRIPTION

 Data::Gerber provides the capabilities to represent a series of RS-274X (commonly
 referred to as Gerber data) instructions in an object-oriented way, with
 methods and sub-classes for performing common activities such as:
 
=over 1

=item Parsing Data from Files via L<Gerber::Parser>
=item Writing Data to Files via L<Gerber::Writer>
=item Determining Boundaries of Drawn Data
=item Basic Translations and Conversions of Data

=back

=cut



my %gCodes = (
	'G01' => 1,
	'G1'  => 1,
	'G02' => 1,
	'G2'  => 1,
	'G03' => 1,
	'G3'  => 1,
	'G04' => 1,
	'G4'  => 1,
	'G36'  => 1,
	'G37'  => 1,
	'G54'  => 1,
	'G55'  => 1,
	'G70'  => 1,
    'G71'  => 1,
	'G74'  => 1,
	'G75'  => 1,
	'G90'  => 1,
	'G91'  => 1,
	'M00'  => 1,
	'M01'  => 1,
	'M02'  => 1
);
	
=head1 METHODS

=cut



=item new

 Constructor, creates a new instance of the class.
 
 	my $gerb = Gerber->new();

=cut

sub new {
 my $class = shift;
 my $self = bless({}, $class);

 $self->{'ignore'}      = 0;
 $self->{'ignoreBlank'} = 0;
 $self->{'apertures'}   = {};
 $self->{'macros'}      = {};
 $self->{'boundaries'}  = [];
 $self->{'parameters'}  = {};
 $self->{'functions'}   = [];
 $self->{'error'}       = undef;
 $self->{'parseState'}  = {};
 $self->{'nmc'}	        = 0;
 $self->{'boundaries'}  = { 
 	'LX' => undef,
 	'RX' => undef,
 	'TY' => undef,
 	'BY' => undef
 };
 
 $self->{'lastcoord'} = {
 	 'X' => 0,
 	 'Y' => 0
 };
 
 $self->{'curAperture'} = undef;
 $self->{'lastMove'}    = 0;
 
 	# default to inch mode if not specified
 
 $self->{'parameters'}{'mode'} = 'IN';
 
 	# default format specification
 	
 $self->{'parameters'}{'FS'}   = {
 	 'zero' => 'Leading',
 	 'coordinates' => 'Absolute',
 	 'format' => {
 	 	 'integer' => 5,
 	 	 'decimal' => 5
 	 }
 };
 
 return $self;	
}


=item error

 Returns the last set error, or undef if no error has been set
 
=cut

sub error {
	
 my $self = shift;
 $self->{'error'} = $_[0] if(defined($_[0]));
 return $self->{'error'};
}


=item ignoreInvalid( FLAG )

 Set or read the IgnoreInvalid flag.
 
 When the IgnoreInvalid flag is set to any true value, any invalid or deprecated
 G-Codes or parameters will be ignored. When this flag is set to any false value
 an error will be generated.
 
 The default flag value is 0, or false.
 
 This method sets the flag if a flag argument is provided, or just reads the
 flag if the flag argument is not provided.  This method always returns the
 current flag value, after any set operation.
 
=cut


sub ignoreInvalid {

 my $self = shift;
 my  $opt = shift;
 
 if( defined($opt) ) {
 	 $self->{'ignore'} = $opt;
 }
 
 return $self->{'ignore'};
 
}


=item ignoreBlank( FLAG )

 Set or read the IgnoreBlank flag.
 
 When the IgnoreBlank flag is set to any true value any drawing by a completely
 closed aperture (commonly used for comments, borders, etc.), after setting the
 flag, will be ignored when calculating the bounding box and size of the 
 drawing area.
 
 The default flag value is 0, or false.
 
 This method sets the flag if a flag argument is provided, or just reads the
 flag if the flag argument is not provided.  This method always returns the
 current flag value, after any set operation.
 
=cut

sub ignoreBlank {
	
 my $self = shift;
 my  $opt = shift;

  if( defined($opt) ) {
 	 $self->{'ignoreBlank'} = $opt;
 }
 
 return $self->{'ignoreBlank'};
 
}


=item aperture( OPTS )

 Add or Get a custom aperture, defined by OPTS.
 
=over 1

=item Getting an Aperture that Has Been Defined

 To get an aperture that has already been defined, provide only the 'code' 
 key in OPTS, specifying the D-Code to retrieve, e.g.:
 
 	my $apt = $gerb->aperture( 'code' => 'D11' );
 	
 If the specified D-Code is found, a hashref will be returned with the following
 format:
 
 	{
 	
 	  'code'      => D-code for aperture,
 	  'type'      => Aperture type (built-in or macro name)
 	  'modifiers' => String containing list of modifiers (if set)
 	  'diameter'    => diameter in format units (circle type only)
 	  
 	}

 If the specified D-Code is not found, an empty hash ref will be returned.
 
 If an invalid D-Code is specified, undef will be returned and the error will
 be set.
 
=item Creating an Aperture Definition

 To create an aperture definition, you must provide at a minimum the following 
 keys:
 
 	code	=> the D-code to use for this aperture
 	type	=> the type of aperture (C, R, O, P or aperture macro name)
 	
 Additionally, you may optionally supply a 'modifiers' key which provides
 any required modifiers.
 
 Returns true (1) on success, or undef and sets the error on error.
 
 For example:
 
 	if( ! $gerb->aperture( 'code' => 'D11', 'type' => 'C', 'modifiers' => 0.0100 ) ) {
 		die $gerb->error();
 	}

=back

=cut

sub aperture {

 my $self = shift;
 my %opts = @_;
 
 if( ! exists( $opts{'code'} ) ) {
 	 $self->error("[aperture] CODE Required");
 	 return undef;
 }
 
 	# check code
 	
 if( $opts{'code'} =~ /D(\d+)/ ) {
 	 if( ($1 + 0) < 10 ) {
 	 	 $self->error("[aperture] Invalid D-Code: '$opts{'code'}'");
 	 	 return undef;
 	 }
 }
 else {
 	 $self->error("[aperture] Invalid D-Code: $opts{'code'}");
 	 return undef;
 }
 
 if( exists( $opts{'type'} ) ) {
		# Creating an aperture, check type
		
	 if( $opts{'type'} !~ /^[a-z_\$]{1}[a-z0-9_\$]{0,}$/i ) {
		 $self->error("[aperture] Invalid Type: $opts{'type'}");
		 return undef;
	 }
	 
	 
	 $self->{'apertures'}{ $opts{'code'} } = {
		 'type'	     => $opts{'type'},
		 'modifiers' => ( exists($opts{'modifiers'}) ) ? $opts{'modifiers'} : ''
	 };
	 
	 	# circle aperture
	 if( $opts{'type'} eq 'C' ) {
	 	if( $opts{'modifiers'} =~ /^([0-9\.]+)/ ) {
	 		$self->{'apertures'}{ $opts{'code'} }{'diameter'} = $1;
	 	}
	 	else {
	 		$self->error("[aperture] Modifier does not appear to include diameter for circle: $opts{'modifiers'}");
	 	}
	 }
	 	 
		# save
		

 
	 return 1;
 }
 else {
 	 # reading an aperture
 	 
 	 return $self->{'apertures'}{ $opts{'code'} } if( exists($self->{'apertures'}{ $opts{'code'} }) );
 	 return {};
 }
 	 
}


=item mode( MODE )

 Set or get the mode (units) for commands.  The default mode is inches (IN).
 
 If MODE is not specified, returns the current mode for the document without
 making any changes.  
 
 MODE can be one of:
 
  IN (inches) or MM (millimeters)
  
 Returns true (1) if successful, or undef and sets the error if an error
 occurs.
 
 		# set mode
 	if( ! $gerb->mode('MM') ) {
 		die $gerb->error();
 	}
 	
 		# get mode
 	my $mode = $gerb->mode();
 	
 	
=cut

sub mode {

 my $self = shift;
 my $mode = shift;
 
 if( defined($mode) ) {
	 if( $mode ne 'IN' && $mode ne 'MM' ) {
		 $self->error("[mode] Invalid Mode: $mode");
		 return undef;
	 }
	 
	 $self->{'parameters'}{'mode'} = $mode;
 }
 
 return $self->{'parameters'}{'mode'};
}

=item mode( MODE )

 Set or get the mode (units) for commands.  The default mode is inches (IN).
 
 If MODE is not specified, returns the current mode for the document without
 making any changes.  
 
 MODE can be one of:
 
  IN (inches) or MM (millimeters)
  
 Returns true (1) if successful, or undef and sets the error if an error
 occurs.
 
 		# set mode
 	if( ! $gerb->mode('MM') ) {
 		die $gerb->error();
 	}
 	
 		# get mode
 	my $mode = $gerb->mode();
 	
 	
=cut

sub macro {

 my $self = shift;
 my $macro = shift;

 my @macrolist = split('\*',$macro);

 my $macroname = $macrolist[0];
# print $macroname."\n";
 my $macromod = $macrolist[1];
# print $macromod."\n";
 if( defined($macro) ) {

	 $self->{'macros'}{$macroname} = $macromod;
 }
 
 return $self->{'macros'}{$macroname};
}


=item format( OPTS )

 Set or retrieve the Format Specification for this object.
 
 B<It is highly recommended to set the Format Specification first, before
 attempting to add commands, as the format has an impact on how certain
 area operations are performed> 
 
=over 1

=item Retrieve Format Specification

 To retrieve the format specification for this Gerber object, call the format
 method with no arguments, which will return the following hash reference:
 
 	{
 		'zero'		=> zero truncating setting
 		'coordinates' 	=> coordinate mode
 		'format'	=> {
 			'integer'	=> # of integer places
 			'decimal'	=> # of decimal places
 		}
 	}
 	
 
 
=item Set Format Specification

 To set the format specification, pass a set of hash keys and values as the 
 argument to the method. 
 
 The following hash keys are supported:
 
=over 1

=item zero

 The zero omission setting, must be one of either L or T. (Representative of
 'leading' and 'trailing' zero omission.) Any word that begins
 with L or T will function, which can be useful to write more readable code. The
 following are all equivalent:  
 
 	'zero' => 'L'
 	'zero' => 'Lead'
 	'zero' => 'Leading'
 	
=item coordinates

 Which coordinate system to use, must be one of either A or I. (Representative
 of 'absolute' or 'incremental' coordinates.)  Any word that begins with either 
 A or I will function, which can be useful to write more readable code.  The 
 following at all equivalent:
 
 	'coordinates' => 'A'
 	'coordinates' => 'Abs'
 	'coordinates' => 'Absolute'
 
B<DO NOT USE INCREMENTAL COORDINATES>

 The use of incremental coordinates is strongly discouraged in the spec, and this
 module does not fully support them. Many features will not work properly with
 incremental coordinates.  Simply put: do not use incremental coordinates.
 
 Incremental coordinates are not to be confused with modality of coordinates.
 Full coordinate modality, as compliant with the spec, is supported.


=item format

 The format of distances and values used in commands.  As the specification
 requires that both X and Y format be the same, this module does not provide
 the ability to distinguish between the two.  
 
 The format of this entry is a hash reference, with the 'integer' and 
 'decimal' keys specifying the precision of integers and decimals in all numbers.
 
 For example:
 
 	'format' => {
 		'integer' => 5,
 		'decimal' => 6
 	}
 	
 Note that 7 is the maximum format value.
 
=back

 Setting the format returns true (1) if successful, or returns undef and sets
 the error message in case of failure.
 
 Example of setting the format specification:
 
	 if( ! $gerb->format( 'zero' => 'L', 'coordinates' => 'A', 'format' =>
	     { 'integer' => 5, 'decimal' => 5 } ) ) {
    
	     die $gerb->error();
	 }

 You may specify any combination of specification values per call.
 
=back


=cut


sub format {

 my $self = shift;
 my %opts = @_;
 
 return $self->{'parameters'}{'FS'} if( keys(%opts) < 1 );
 
 if( exists( $opts{'zero'} ) ) {
 	 if( $opts{'zero'} =~ /^[lt]/i ) {
 	 	 $self->{'parameters'}{'FS'}{'zero'} = $opts{'zero'};
 	 }
 	 else {
 	 	 $self->error("[format] Invalid zero value: $opts{'zero'}");
 	 	 return undef;
 	 }
 }
 
 if( exists( $opts{'coordinates'} ) ) {
 	 if( $opts{'coordinates'} =~ /^[ai]/i ) {
 	 	 $self->{'parameters'}{'FS'}{'coordinates'} = $opts{'coordinates'};
 	 }
 	 else {
 	 	 $self->error("[format] Invalid coordinates value: $opts{'coordinates'}");
 	 	 return undef;
 	 }
 } 	 	 
 
 if( exists( $opts{'format'} ) ) {
 	 foreach('integer', 'decimal') {
 	 	 if( exists($opts{'format'}{$_}) ) {
 	 	 	 if( $opts{'format'}{$_} > 7 || $opts{'format'}{$_} < 0 ) {
 	 	 	 	 $self->error("[format] Invalid format spec for $_ : $opts{'format'}{$_}");
 	 	 	 	 return undef;
 	 	 	 }
 	 	 	 $self->{'parameters'}{'FS'}{'format'}{$_} = $opts{'format'}{$_};
 	 	 }
 	 }
 }
 
 return 1;
 
}


=item function( OPTS )

 Add a function to the document.
 
 Standard functions supported:
=over 1
=item Aperture Select
=item G-Codes
=item Moves
=item Repeatable Parameter Calls
=back

 OPTS is a hash that provides one or more of the following keys, which define
 the function:
 
=over 1
=item aperture
 Select the aperture to use for following functions
 
=item func
 Function Code (i.e. G-Codes)
 
=item coord
 Coordinate Data
 
=item op
 Operation Code (i.e. D-Code)

=item param
 Special parameter which can be repeated multiple times (e.g. LP, SR)
 
=item comment
 A comment (used only with G04/G4, if you specify a comment for a non-G04
 command, it may be useful in certain file writers that would automatically
 generate a new comment for you)

=back

 You can specify any combination which represents a valid function in Gerber
 notation, e.g.: func, coord, and op; coord and op, func; aperture; param
 
 Note that if you specify an aperture or param key, all other keys are ignored.
 
 The following are all valid function calls (presuming that you have already
 defined the apertures indicated, etc.):
 
 	$gerb->function( 'func' => 'G01', 'coord' => 'X001000Y001000', 'op' => 'D01' );
 	$gerb->function( 'func' => 'G01' );
 	$gerb->function( 'aperture' => 'D13' );
 	$gerb->function( 'coord' => 'Y-300', 'op' => 'D03' );
 	$gerb->function( 'func' => 'G04', 'comment' => 'My Comment' );
 	
 This method returns true (1) upon success, and undef and sets the error message 
 on error.
 
 B<Notes on Sequence>
=over 1

 This library handles gerber data in a streaming fashion - that is, function
 sequences must be issued in the same order they would be issued in a file, as
 previous functions impact the interpretation of current functions. 
 
 All of your aperture, macro, and format specification activities should be
 done before creating functions.

=back

=cut

sub function {
	
 my $self = shift;
 my %opts = @_;
 
 return 1 if( keys(%opts) < 1 );
 
 if( exists($opts{'func'}) && defined($opts{'func'}) ) {
 	 if( ! $self->{'ignore'} && ! $self->_validateGC($opts{'func'}) ) {
 	 	 $self->error("[function] Invalid Function Code: $opts{'func'}");
 	 	 return undef;
 	 }
 }
 
 if( exists($opts{'op'}) && defined($opts{'op'}) ) {
 	 if( $opts{'op'} !~ /D0?[123]$/ ) {
		 if ($opts{'func'} !~/G54/){
 	 	 	$self->error("[function] Invalid Operation Code: $opts{'op'}");
 	 	 	return undef;
		}
 	 }
 }
 
 
 	# if aperture specified, only allow aperture select in the function
 	
 if( exists($opts{'aperture'}) && defined($opts{'aperture'}) ) {
 	 	# verify that aperture has been defined
 	 if( ! exists($self->{'apertures'}{ $opts{'aperture'} }) ) {
 	 	 $self->error("[function] Invalid/Unknown Aperture Referenced: $opts{'aperture'}");
 	 }
 	 
 	 $self->{'curAperture'} = $opts{'aperture'};
 	 
 	 push(@{ $self->{'functions'} }, { 'aperture' => $opts{'aperture'} });
 	 
 	 return 1;
 }
 	
 	# if param specified, only allow parameter call in the function
 
 if( exists($opts{'param'}) && defined($opts{'param'}) ) {
 	 push(@{ $self->{'functions'} }, { 'param' => $opts{'param'} });
 	 return 1;
 }
 
 my %func;

 foreach('func', 'coord', 'op', 'comment') {
 	 if( exists( $opts{$_} ) && defined( $opts{$_} ) ) {
 	 	 $func{$_} = $opts{$_};
 	 }
 }

 if( exists($opts{'coord'}) && defined($opts{'coord'}) ) {
 	 
 	 if( ! exists($opts{'op'}) || ! defined($opts{'op'}) ) {
 	 	 $self->error("[function] Operation Code must be provided when Coordinate Data is provided");
 	 	 return undef;
 	 }
 	
 	 $func{'xy_coords'} = $self->_processCoords($opts{'coord'}, $opts{'op'});
 }

 push(@{ $self->{'functions'} }, \%func);
 
 return 1;
 
}


=item functions( OPTS )

 Count number of functions, or retrieve one or more functions.
 
 When called with no arguments, this method returns all functions that have
 been added the document.
 
 OPTS is a hash with any of the following keys:
=over 1

=item count

 Count number of functions in the document

=item num

 Retrieve one function, the numth in the document (zero-indexed)
=back

 Examples:
 
 	my  $fCount = $gerb->functions( 'count' => 1 );
 	my $3rdFunc = $gerb->functions( 'num' => 2 );
 	my   @funcs = $gerb->functions();
 	
 This method returns undef, and sets the error message if an error occurs.
 

=cut

sub functions {
	
 my $self = shift;
 my %opts = @_;
 
 if( ! exists($opts{'count'}) && ! exists($opts{'num'}) ) {
 	 return @{ $self->{'functions'} };
 }
 
 if( exists($opts{'num'}) ) {
 	 if( $opts{'num'} > $#{ $self->{'functions'} } ) {
 	 	 $self->error("[functions] Invalid function number $opts{'num'}");
 	 	 return undef;
 	 }
 	 
 	 return $self->{'functions'}[$opts{'num'}];
 }
 
 if( exists($opts{'count'}) ) {
 	 return $#{ $self->{'functions'} } + 1;
 }
 
 
}


=item boundingBox

 Returns the coordinates of a box which exactly holds the entire contents.
 
 The result is an array with four elements, representing the Left-most X, Bottom-most
 Y, Right-most X, and Top-Most Y.
 
 When considered as tuples of X, Y and corners, the first tuple would represent
 the bottom-left corner, and the second the top-right.
 
 e.g.:
 
 	my ($lx, $by, $rx, $ty) = $gerb->boundingBox();
 	
 		# ex: 0, 0, 53.7, 123.0056
 	
 All values are floats, in the units specified by the format spec.
 	
=cut

sub boundingBox {
	
 my $self = shift;
 
 my @box = ( 
 	$self->{'boundaries'}{'LX'}, $self->{'boundaries'}{'BY'},
 	$self->{'boundaries'}{'RX'}, $self->{'boundaries'}{'TY'}
 );

 return @box;
}


=item width 

 Returns the width of the bounding box, in native units as a decimal.
 
 	my $width = $gerb->width();

=cut

sub width {
 
 my $self = shift;
 
 return $self->{'boundaries'}{'RX'} - $self->{'boundaries'}{'LX'};
 	
}

=item height 

 Returns the height of the bounding box, in native units as a decimal.
 
 	my $height = $gerb->height();

=cut

sub height {

 my $self = shift;
 
 return $self->{'boundaries'}{'TY'} - $self->{'boundaries'}{'BY'};
 
}

 # validate g-codes
 
sub _validateGC {

 my $self = shift;
 my $code = shift;
 
 return 1 if( exists( $gCodes{$code} ) );
 return undef; 	 
	
}



sub _parseSize {

 my     $self = shift;
 my $sizeCode = shift;
 
 my %pos = ();
 my %off = ();
 
 while( $sizeCode =~ s/([XY]{1})([\-0-9]+)// ) {
 	my $axis = $1;
 	my  $loc = $2;

	$pos{$axis} = $loc;
 }
 
 while( $sizeCode =~ s/([IJ]{1})([\-0-9]+)// ) {
 	 my  $oaxis = $1;
 	 my $offset = $2;
 	 
 	 $off{$oaxis} = $offset;
 }
 
 	# correct lengths and convert values to native floats
  
 my $fLen = $self->{'parameters'}{'FS'}{'format'}{'integer'} + $self->{'parameters'}{'FS'}{'format'}{'decimal'};
 my $fDiv = 10 ** $self->{'parameters'}{'FS'}{'format'}{'decimal'};
 my  $pad = $self->{'parameters'}{'FS'}{'zero'} =~ /^L/i ? 1 : 0;
 
 foreach(\%pos, \%off) {
 	foreach my $key (keys(%{$_})) {
 		my $thisLen = length($_->{$key});
 		if( $thisLen < $fLen ) {
 				# length is shorter than target length
 			if( $pad ) {
 					# we are padding the whole numbers
 					# hold any +/- pre-modifiers off
 				my $pre = '';
 				   $pre = $1 if($_->{$key} =~ s/^([+\-])//);
 				   
 				$_->{$key} = $pre . "0" x ($fLen - $thisLen) . $_->{$key};
 			}
 			else {
 					# we are padding the decimals
 				$_->{$key} .= "0" x ($fLen - $thisLen);
 			}
 		}
 		
 			# convert to decimal
 		$_->{$key} /= $fDiv;
 	}			
 }
 
 return [\%pos, \%off];
 
}




sub _processCoords {

 my  $self = shift;
 my $coord = shift;
 my  $code = shift;
 
 my $sizeRet = $self->_parseSize($coord);
 
 my %pos = %{ $sizeRet->[0] };
 my %off = %{ $sizeRet->[1] };

 	# default to last coordinate value for axis
 	# if not supplied (coordinates are modal)
 foreach('X', 'Y') {
 	 if( ! exists($pos{$_}) ) {
 	 	 if( defined($self->{'lastcoord'}{$_}) ) {
 	 	 	 $pos{$_} = $self->{'lastcoord'}{$_};
 	 	 }
 	 	 else {
 	 	 	 $pos{$_} = 0;
 	 	 }
 	 }
 }
 
 	# process offsets
 	
 if( exists($off{'I'}) && defined($off{'I'}) ) {
 	 $pos{'X'} += $off{'I'};
 }
 
 if( exists($off{'J'}) && defined($off{'J'}) ) {
 	 $pos{'Y'} += $off{'J'};
 }

 
 
 # TODO: Consider size of aperture or image when calculating the data
 # below.
 
 	# if a move-only (no-expose) code, we record that our last command
 	# was a move, and do not update coordinates.  This allows us to move
 	# as much as we like without impacting the bounding box.
 	
 if( $code eq 'D02' ) {
 	 $self->{'lastMove'} = 1;
 }
 elsif( $code eq 'D01' ) {
 	 	# this is a draw code
 	 	
 	 if( $self->{'lastMove'} ) {
 	 	 	# if our last code was a move code, let's go ahead and
 	 	 	# record that our drawing starts at the destination of
 	 	 	# the last move
 	 	 $self->_updateCoords($self->{'lastcoord'});
 	 	 $self->{'lastMove'} = 0;
 	 }
 	 
 	 	# ensure that we don't count blank drawing if ignoreBlank is on
 	 if( ! $self->{'ignoreBlank'} || 
 	     ( exists($self->{'aperture'}{ $self->{'curAperture'} }{'diameter'} ) &&
 	       $self->{'aperture'}{ $self->{'curAperture'} }{'diameter'} > 0.0 ) ) {
 	
 	 			# update bounding box coordinates if move with aperture open, or flash
 	 		$self->_updateCoords(\%pos);
 	 }
 }
 else {
 	 	# this is a flash code, we only update at the position of the
 	 	# flash... 
 	 $self->_updateCoords(\%pos);
 }
 
 	# record last coordinate positions
 $self->{'lastcoord'}{'X'} = $pos{'X'};
 $self->{'lastcoord'}{'Y'} = $pos{'Y'};
 

 
 return [ $pos{'X'}, $pos{'Y'} ];
 
}

sub _updateCoords {

 my $self = shift;
 my  $pos = shift; # hashref, X,Y coords
 
 return if( ! ref($pos) eq 'HASH' || ! exists($pos->{'X'}) || ! exists($pos->{'Y'}) );
 
 if( ! defined($self->{'boundaries'}{'LX'}) ) {
 	 $self->{'boundaries'}{'LX'} = $pos->{'X'};
 }
 elsif( $pos->{'X'} < $self->{'boundaries'}{'LX'} ) {
 	 $self->{'boundaries'}{'LX'} = $pos->{'X'};
 }
 
 if( ! defined($self->{'boundaries'}{'RX'}) ) {
 	 $self->{'boundaries'}{'RX'} = $pos->{'X'};
 }
 elsif( $pos->{'X'} > $self->{'boundaries'}{'RX'} ) {
 	 $self->{'boundaries'}{'RX'} = $pos->{'X'};
 }
 
 if( ! defined($self->{'boundaries'}{'BY'}) ) {
 	 $self->{'boundaries'}{'BY'} = $pos->{'Y'};
 }
 elsif( $pos->{'Y'} < $self->{'boundaries'}{'BY'} ) {
 	 $self->{'boundaries'}{'BY'} = $pos->{'Y'};
 }
 
 if( ! defined($self->{'boundaries'}{'TY'}) ) {
 	 $self->{'boundaries'}{'TY'} = $pos->{'Y'};
 }
 elsif( $pos->{'Y'} > $self->{'boundaries'}{'TY'} ) {
 	 $self->{'boundaries'}{'TY'} = $pos->{'Y'};
 }
 
}


#############################################
# New Classes in Version 0.02

####### Aperture Conversion: Step 1 subclasses

sub _aperturemodconvert {		#Checks
 my $self = shift;
 my $apt = shift;
 my $master = shift;

 my $mod;
 my $modifier;
 my @modarray;
 my $master_mode= $master->{'parameters'}{'mode'};

 if ($self->{'apertures'}{$apt}{'type'} eq "C") {
	$mod = 'diameter';
 	if (lc $self->{'parameters'}{'mode'} ne lc $master_mode){
		$self->{'apertures'}{$apt}{'diameter'} = $self->{'apertures'}{$apt}{'diameter'} /25.4;   #Unique to Circle
	}
 }
 if (lc $self->{'parameters'}{'mode'} ne lc $master_mode){
				############ Perform Unit Conversions if MO units don't agree
					## If Circle, 1 submodifier, 1 optional
					## If Rectangle or Obround, 2 submodifiers, 1 optional
					## If Polygon, Dealt with uniquely above
	$modifier = $self->{'apertures'}{$apt}{'modifiers'};
	@modarray = split(/X/,$modifier);
	foreach my $submodifier (@modarray) {
		$modarray[$submodifier] = $modarray[$submodifier] / 25.4;
	}

	$self->{'apertures'}{$apt}{'modifiers'} = join('X',@modarray);

	$mod = 'modifiers';
 }
 else {				# Do nothing if MO units DO agree
	$mod = 'modifiers';
 }
 if (! exists($self->{'apertures'}{$apt}{'modifiers'})) {
				 ######### If it's in the master file, and doesn't need modifiers, : TODO 
				 ############ Find new D-Code, and add to conversion list TODO	
				 ############ break out of logic
 }
 return $mod;
}
###### Function Conversion: Step 2A subclasses
sub _FSdecconvert{

 my $self = shift;
 my $Var = shift;
 my $Char = shift;
 my $subintlength = shift;			#The original int length
 my $subdeclength = shift;			#The original decimal length
 my $coord;

 my $newzero;
 my $decjoiner;

 $decjoiner = '12'- (length($Var));
 $newzero = "0"x$decjoiner;
 $coord = $Char . $Var . $newzero;
 return $coord;

}
###### Function Conversion: Step 2B subclasses
sub _moCoordconvert{
 my $self = shift;
 my $maxLen = shift;
 my $Varstring = shift;
 my $coordcheck = shift;
 my $Var;

 my $coord;
 my $Char = substr($Varstring,0,1);
 $Var = substr($Varstring,1);

 $Var = round($Var / (25.4));
 my $Varlength = length($Var);
 if ($Varlength > 2*$maxLen){
	$self->error("Coordinate too large to format using Gerber");
 }
 my $pre = '';
 $pre = $1 if ($Var =~ s/^([+\-])//);
 $Var = $pre . "0" x (2*$maxLen - $Varlength) . $Var;
 $coord = $Char . $Var;
 return $coord;
}


sub _leadingzeroExtend {
 my $coordvalue = shift;
 my $joiner = shift;
 my $isdec = shift;

 my $newzero = "0"x$joiner;
 my $pre = '';
 if ($coordvalue=~/(\-)/){
 	$pre = $1;
	$coordvalue =~ tr/-//d;
 }
 if ($isdec == '1') {
	$coordvalue = $pre.$coordvalue.$newzero;
 }
 elsif ($isdec == '0') {
	$coordvalue = $pre.$newzero.$coordvalue
 }
# print $coordvalue."\n";
 return $coordvalue;


}



=item convert( MASTER)

 Convert a function of an Object to a master set of parameters, and add to specified object.
 
 Standard functions supported:
=over 1
=item Aperture Select
=item G-Codes
=item Moves
=item Repeatable Parameter Calls
=back
 Warning: No Support for Aperture Macros!

 MASTER consists of a Gerber object with 'master parameters' pre-specified

=back

=cut
sub convert {	
 my $self = shift;
 my $master = shift;
########## Parse each Gerber Function: If header conversion applies, apply it.

### Variable Initialization
 my $apt; my $Dcount;						#Used for listing Aperture codes D10 - D999; spec supports greater
 my $masterapt; my $master_equivalence_check;
 my $master_mode= $master->{'parameters'}{'mode'};
 my $master_int = $master->{'parameters'}{'FS'}{'format'}{'integer'};  #Should be set to 6
 my $master_dec = $master->{'parameters'}{'FS'}{'format'}{'decimal'};  #Should be set to 6
 my $s_func;
 my $mod; my $intjoiner; my $decjoiner; my $newzero;
 my $coord; my $xcoord; my $ycoord; my $icoord; my $jcoord;
 my $maxLen = '6';
 my $conversionlist;
 my $SR; my @SRarray;
 
 if (exists( $master->{'conversionlist'})) { $conversionlist = $master->{'conversionlist'};}
 else {
	$master->{'conversionlist'} = {};
	$conversionlist = {};
 }
###TODO: Insert check to make sure input is correctly formatted gerber object

### Step 1A: Edit Modifiers in the Apertures for each individual Gerber File

#For every aperture,
 foreach $apt (keys %{$self->{'apertures'}}){
	if (exists($master->{'apertures'}{$apt}) && defined($master->{'apertures'}{$apt})){
							####### If the aperture code exists in the master file:
		if ($self->{'apertures'}{$apt}->{'type'} eq $master->{'apertures'}{$apt}{'type'}) {
							######### and If the aperture type is the same:
			$mod = $self->_aperturemodconvert($apt,$master);
							########### Define the $mod: Circle, Modifier, or doesn't need $mod
			$master_equivalence_check = '0';	#reset master_equivalence before entering foreach loop
			foreach $masterapt (keys %{$master->{'apertures'}}) {
				if ($self->{'apertures'}{$apt}{'type'} eq $master->{'apertures'}{$masterapt}{'type'}) {
					if ($self->{'apertures'}{$apt}{$mod} eq $master->{'apertures'}{$masterapt}{$mod}) {
						########### If it's in the master file, is a $mod, and the $mod is EQUAL 
						########### to ANY master aperture already defined:
						$self->{'apertures'}{$apt} = $master->{'apertures'}{$masterapt};
						$conversionlist->{$apt} = $masterapt;
						$master_equivalence_check = '1';
						last;############# Exit for loop
					}
				}
			}
			if ($master_equivalence_check == 0) {
				foreach $Dcount (10..1000) {
					if ((! exists($master->{'apertures'}{"D".$Dcount})) && (! exists($self->{'apertures'}{"D".$Dcount}))) {
						########### If it's in the master file, is a $mod, and the $mod is 
						########### NOT EQUAL to ANY master aperture already defined:
						$master->{'apertures'}{'D'.$Dcount} = $self->{'apertures'}{$apt};
						$conversionlist->{$apt} = 'D'.$Dcount;
						last;
						############ Find new D-Code, convert, and add to conversion list		
					}
				}
			}
		}
		else {				######### If the aperture type is NOT the same:

			foreach $Dcount (10..1000) {
				if (! exists($master->{'apertures'}{"D".$Dcount}) && ! exists($self->{'apertures'}{"D".$Dcount})) {
					$master->{'apertures'}{'D'.$Dcount} = $self->{'apertures'}{$apt};
					$conversionlist->{$apt} = "D".$Dcount;
					last;
						############ Find new D-Code, convert TODO, and add to conversion list		
				}
			}
		}
	}
	else {					########### Define the $mod: Circle, Modifier, or doesn't need $mod
		$mod = $self->_aperturemodconvert($apt,$master);
		foreach $masterapt (keys %{$master->{'apertures'}}) {
			if ($self->{'apertures'}{$apt}{'type'} eq $master->{'apertures'}{$masterapt}{'type'}) {
				if ($self->{'apertures'}{$apt}{$mod} eq $master->{'apertures'}{$masterapt}{$mod}) {
						######### If it's NOT in the master file, is a $type, and the $type's $mod is 
						######### EQUAL to ANY master aperture already defined:
					$self->{'apertures'}{$apt} = $master->{'apertures'}{$masterapt};
					$conversionlist->{$apt} = $masterapt;
						###########Force the current aperture to be equal to the master, and add to conversionlist
				}
			}
		}				
		if (! exists($conversionlist->{$apt})) {
					######### If none of the aperture values in the master equal the current apertures, add to master
			$master->{'apertures'}{$apt} = $self->{'apertures'}{$apt};
		}			
	}

 } 
# For every Function
 foreach $s_func (keys $self->{'functions'}) {
 	if (exists( $self->{'functions'}[$s_func]{'coord'}) && defined( $self->{'functions'}[$s_func]{'coord'})) {
							### Step 2A: Add back dropped zeroes from original Gerb, if needed
		my $coord = $self->{'functions'}[$s_func]{'coord'} ;
		my $formatlength = $self->{'parameters'}{'FS'}{'format'}{'integer'}+$self->{'parameters'}{'FS'}{'format'}{'decimal'};
		my $testvalue;
 		my $joiner; 
		my @coordsplit = split(/([X|Y|I|J])/,$coord);
		shift(@coordsplit);		#Since the coordinates start with a delimiter, remove first empty string.
		my $currentChar;
		foreach my $coordvalue (@coordsplit) {
			$testvalue = $coordvalue;
			$testvalue =~ tr/[+\-]//d;
			if ($coordvalue =~ m/([XYIJ])/i) {
				$currentChar = $1;
			}
			elsif ((length($testvalue)<$formatlength) && ! ($coordvalue =~ /X|Y|I|J/i)) {
 				$joiner = $formatlength - length($testvalue);
				if ($self->{'parameters'}{'FS'}{'zero'} =~/^L/i){
					$coordvalue = _leadingzeroExtend($coordvalue,$joiner,'0');
				}
			}
		}
		my $tempcoord = join('',@coordsplit);
		@coordsplit = split(/([X|Y|I|J])/,$tempcoord);
		shift(@coordsplit);		#Since the coordinates start with a delimiter, remove first empty string.
							### Step 2B: Add back Leading Zeros
		if ($self->{'parameters'}{'FS'}{'format'}{'integer'} ne $maxLen) {
			if ($self->{'parameters'}{'FS'}{'format'}{'integer'} < $maxLen) {
#TODO
				$intjoiner = $maxLen+$self->{'parameters'}{'FS'}{'format'}{'decimal'};

				if ($self->{'parameters'}{'FS'}{'zero'} =~/^L/i){
					foreach my $intvalue (@coordsplit) {
						$testvalue = $intvalue;
						$testvalue =~ tr/[+\-]//d;
						if ($intvalue =~ m/([XYIJ])/i) {
							$currentChar = $1;
						}
						elsif ((length($testvalue)<$intjoiner) && ! ($intvalue =~ /X|Y|I|J/i)) {
 							$joiner = $intjoiner- length($testvalue);
							$intvalue = _leadingzeroExtend($intvalue,$joiner,'0');
						}
					}

				}
#				print "Integer Format Converted" . "\n";
			}
		}
		$tempcoord = join('',@coordsplit);
		@coordsplit = split(/([X|Y|I|J])/,$tempcoord);
		shift(@coordsplit);		#Since the coordinates start with a delimiter, remove first empty string.
							### Step 2C: Add back Trailing Zeros
		if ($self->{'parameters'}{'FS'}{'format'}{'decimal'} ne $maxLen) {
			if ($self->{'parameters'}{'FS'}{'format'}{'decimal'} < $maxLen) {
				$xcoord = ''; $ycoord = ''; $icoord = ''; $jcoord = '';
				$decjoiner = 2*$maxLen;
				if ($self->{'parameters'}{'FS'}{'zero'} =~/^L/i){
					foreach my $decvalue (@coordsplit) {
						$testvalue = $decvalue;
						$testvalue =~ tr/[+\-]//d;
						if ($decvalue =~ m/([XYIJ])/i) {
							$currentChar = $1;
						}
						elsif ((length($testvalue)<$decjoiner) && !($decvalue =~ /X|Y|I|J/i)) {
 							$joiner = $decjoiner- length($testvalue);
							$decvalue = _leadingzeroExtend($decvalue,$joiner,'1');
						}
					}
				}
				else {
	#				if ($coord =~ s/.*X([0-9]+)/$1/){ $xcoord = $self->_FSdecconvert($1,"X",$self->{'parameters'}{'FS'}{'format'}{'integer'},$self->{'parameters'}{'FS'}{'format'}{'decimal'} )};
	#				if ($coord =~ s/.*Y([0-9]+)/$1/){ $ycoord = $self->_FSdecconvert($1,"Y",$self->{'parameters'}{'FS'}{'format'}{'integer'},$self->{'parameters'}{'FS'}{'format'}{'decimal'} )};
	#				if ($coord =~ s/.*I([0-9]+)/$1/){ $icoord = $self->_FSdecconvert($1,"I",$self->{'parameters'}{'FS'}{'format'}{'integer'},$self->{'parameters'}{'FS'}{'format'}{'decimal'} )};
	#				if ($coord =~ s/.*J([0-9]+)/$1/){ $jcoord = $self->_FSdecconvert($1,"J",$self->{'parameters'}{'FS'}{'format'}{'integer'},$self->{'parameters'}{'FS'}{'format'}{'decimal'} )};
					$coord = $xcoord . $ycoord . $icoord . $jcoord;
				}
#				print "Decimal Format Converted" . "\n";
			}
		}
		$coord = join('',@coordsplit);
		$self->{'functions'}[$s_func]{'coord'} = $coord ;
	}
 }
 foreach $s_func (keys $self->{'functions'}) {		### Step 2B: Convert MM to IN (if needed)
 	if (exists( $self->{'functions'}[$s_func]{'coord'}) && defined( $self->{'functions'}[$s_func]{'coord'})) {
		if (lc $self->{'parameters'}{'mode'} ne lc $master_mode){
			$coord = $self->{'functions'}[$s_func]{'coord'};

			$xcoord = ''; $ycoord = ''; $icoord = ''; $jcoord = '';

			if ($coord =~ m/X[0-9]+/){ $xcoord = $self->_moCoordconvert($maxLen,$&)};
			if ($coord =~ m/Y[0-9]+/){ $ycoord = $self->_moCoordconvert($maxLen,$&)};
			if ($coord =~ m/I[0-9]+/){ $icoord = $self->_moCoordconvert($maxLen,$&)};
			if ($coord =~ m/J[0-9]+/){ $jcoord = $self->_moCoordconvert($maxLen,$&)};
			$self->{'functions'}[$s_func]{'coord'} = $xcoord . $ycoord . $icoord . $jcoord;
		}
 	}
 }
 foreach $s_func (keys $self->{'functions'}) {		### Step 2C: Edit Function Codes for each individual Gerber File from conversionlist
							#	For each function in the hash, if the function contains coordinates, 
							#process those coordinates in order to update the MO values. Otherwise, ignore it.
	if (exists($self->{'functions'}[$s_func]{'xy_coords'}) && defined($self->{'functions'}[$s_func]{'xy_coords'})){
 		$self->{'functions'}[$s_func]{'xy_coords'} = $self->_processCoords($self->{'functions'}[$s_func]{'coord'}, $self->{'functions'}[$s_func]{'op'});
	}
							#	For each function in the hash, if the function is an aperture 
							# listed in the conversionlist, convert it. Otherwise, ignore it.
	if (exists($self->{'functions'}[$s_func]{'aperture'}) && defined($self->{'functions'}[$s_func]{'aperture'})){
		if (exists($conversionlist->{$self->{'functions'}[$s_func]{'aperture'}}) && defined($conversionlist->{$self->{'functions'}[$s_func]{'aperture'}} )) {
			$self->{'functions'}[$s_func]{'aperture'} = $conversionlist->{$self->{'functions'}[$s_func]{'aperture'}};
		}
	}
							#      For each function in the hash, if the function is an SR parameter call, 
							# and the units of MO don't agree with master, Convert. Otherwise, ignore it.
	if (exists($self->{'functions'}[$s_func]{'param'}) && defined($self->{'functions'}[$s_func]{'param'})){
		if ($self->{'functions'}[$s_func]{'param'} =~ m/^SR.*/) {
			if (lc $self->{'parameters'}{'mode'} ne lc $master_mode){
				@SRarray = split(/(I|J)/,$self->{'functions'}[$s_func]{'param'});
				splice @SRarray, 0, 1;
				foreach my $submodifier (@SRarray) {
					if ($SRarray[$submodifier] ne 'I' && $SRarray[$submodifier] ne 'J') {
						$SRarray[$submodifier] = $SRarray[$submodifier] / 25.4;
					}
				}
				$self->{'functions'}[$s_func]{'param'} = join('',@SRarray);
			}
		}
	}
 }
### Step 3: Make final Format changes, and Append Entire Functions Object to Master
 $master->{'conversionlist'} = $conversionlist;
 $self->{'parameters'}{'FS'}{'format'}{'integer'} = $master_int;
 $self->{'parameters'}{'FS'}{'format'}{'decimal'} = $master_dec;
 $self->{'parameters'}{'mode'} = $master_mode;
}

###################################################

sub translate {

 my $self = shift;
 my @TransCoord;

 $TransCoord[0] = shift;
 $TransCoord[1] = shift;

 my $fDiv = 10 ** 3;		#In what units are the bounding boxes? I specified units in Thou, so this should be 


# $TransCoord[0] = sprintf("%f", $TransCoord[0]);

 $TransCoord[0] *= $fDiv;

# $TransCoord[1] = sprintf("%f", $TransCoord[1]);
 $TransCoord[1] *= $fDiv;

# print "Translate".Dumper(@TransCoord)."\n";

 my @XYCoord;
 my %XYCoord;

 my $s_func;
 my $submodifier;

### Step 2D: Add Offsets to Coordinates,
	### Make this its own Sub-routine called right at this moment
	### First, need to fix Algorithm. If the Algorithm outputs the right format, then this part is trivial using split and splice to isolate and add
 foreach $s_func (keys $self->{'functions'}) {
 	if (exists( $self->{'functions'}[$s_func]{'coord'}) && defined( $self->{'functions'}[$s_func]{'coord'})) {
		
		@XYCoord = split(/(X|Y|I|J)/,$self->{'functions'}[$s_func]{'coord'});
		splice @XYCoord, 0, 1;
		%XYCoord = @XYCoord;						#Array to Hash

		foreach $submodifier (keys %XYCoord) {
			if ($submodifier eq 'X') {
				$XYCoord{$submodifier} = $XYCoord{$submodifier} + $TransCoord[0];
			}
			elsif ($submodifier eq 'Y') {
				$XYCoord{$submodifier} = $XYCoord{$submodifier} + $TransCoord[1];
			}		
		}
		@XYCoord = %XYCoord;						#Hash to Array

			
		if (($XYCoord[0] eq 'Y') && scalar(@XYCoord)>2 ) {
			($XYCoord[0], $XYCoord[1],$XYCoord[2], $XYCoord[3]) = ($XYCoord[2], $XYCoord[3],$XYCoord[0], $XYCoord[1]);
		}
		
		$self->{'functions'}[$s_func]{'coord'} = join('', @XYCoord);
		if (exists($self->{'functions'}[$s_func]{'xy_coords'}) && defined($self->{'functions'}[$s_func]{'xy_coords'})){
			if (exists($self->{'functions'}[$s_func]{'op'}) && defined($self->{'functions'}[$s_func]{'op'})){
				$self->{'functions'}[$s_func]{'xy_coords'} = $self->_processCoords($self->{'functions'}[$s_func]{'coord'}, $self->{'functions'}[$s_func]{'op'});
#			my $pos = {'X'=>$self->{'functions'}[$s_func]{'xy_coords'}[0], 
#				   'Y'=>$self->{'functions'}[$s_func]{'xy_coords'}[1]};
#			$self->_updateCoords($pos);
			}
		}
	}
 }
 my $xoffset = $TransCoord[0] / (10**3);
 my $yoffset = $TransCoord[1] / (10**3);
 if (defined($self->{'boundaries'}{'LX'})) {
 	$self->{'boundaries'}{'LX'} = $self->{'boundaries'}{'LX'}+$xoffset;
 }
 if (defined($self->{'boundaries'}{'BY'})) {
        $self->{'boundaries'}{'BY'} = $self->{'boundaries'}{'BY'}+$xoffset;
 }
 if (defined($self->{'boundaries'}{'RX'})) {
        $self->{'boundaries'}{'RX'} = $self->{'boundaries'}{'RX'}+$xoffset;
 }
 if (defined($self->{'boundaries'}{'TY'})) {
        $self->{'boundaries'}{'TY'} = $self->{'boundaries'}{'TY'}+$xoffset;
 }


}


sub rotate {

 my $self = shift;


 my $RotationBit = shift;


 my $fDiv = 10 ** 3;		#In what units are the bounding boxes? I specified units in Thou, so this should be 


 my @XYCoord;
 my %XYCoord;

 my $s_func;
 my $submodifier;
 my $modifier;
 my $apt;
 my @modarray;


 if ($RotationBit == '1') {

	#Rotate functions with coordinates
 	foreach $s_func ($self->{'functions'}) {
 		if (exists( $self->{'functions'}[$s_func]{'coord'}) && defined( $self->{'functions'}[$s_func]{'coord'})) {
		
			@XYCoord = split(/(X|Y)/,$self->{'functions'}[$s_func]{'coord'});
			splice @XYCoord, 0, 1;

			
			if (scalar(@XYCoord)>2 ) {
				($XYCoord[1], $XYCoord[3]) = ($XYCoord[3],$XYCoord[1]);
			}
			elsif (($XYCoord[0] eq 'X') && scalar(@XYCoord)<=2 ) {
				$XYCoord[0]= 'Y';
			}
			elsif (($XYCoord[0] eq 'Y') && scalar(@XYCoord)<=2 ) {
				$XYCoord[0]= 'X';
			}


			$self->{'functions'}[$s_func]{'coord'} = join('', @XYCoord);
			if (exists($self->{'functions'}[$s_func]{'xy_coords'}) && defined($self->{'functions'}[$s_func]{'xy_coords'})){
				$self->{'functions'}[$s_func]{'xy_coords'} = $self->_processCoords($self->{'functions'}[$s_func]{'coord'}, $self->{'functions'}[$s_func]{'op'});
			}
		}
	}

	#Rotate Apertures with more than one modifier		#TODO: Handle Polygons
 	foreach $apt (keys %{$self->{'apertures'}}){

 		if ($self->{'apertures'}{$apt}{'type'} eq "O") {

			$modifier = $self->{'apertures'}{$apt}{'modifiers'};
			@modarray = split(/X/,$modifier);

			($modarray[0],$modarray[1]) = ($modarray[1],$modarray[0]);

			if (scalar(@modarray) == 4) {	#Specifies rotation of hole
				($modarray[2],$modarray[3]) = ($modarray[3],$modarray[2]);
			}

			$self->{'apertures'}{$apt}{'modifiers'} = join('X',@modarray);

		}
 		if ($self->{'apertures'}{$apt}{'type'} eq "R") {

			$modifier = $self->{'apertures'}{$apt}{'modifiers'};

			@modarray = split(/X/,$modifier);

			($modarray[0],$modarray[1]) = ($modarray[1],$modarray[0]);

			if (scalar(@modarray) == 4) {	#Specifies rotation of hole
				($modarray[2],$modarray[3]) = ($modarray[3],$modarray[2]);
			}

			$self->{'apertures'}{$apt}{'modifiers'} = join('X',@modarray);


		}


 		if ($self->{'apertures'}{$apt}{'type'} eq "P") {	#Only matters for corner-case of regular polygon w/ rectangular hole

			$modifier = $self->{'apertures'}{$apt}{'modifiers'};
			@modarray = split(/X/,$modifier);

			if (scalar(@modarray) == 5) {	#Specifies rotation of hole
				($modarray[3],$modarray[4]) = ($modarray[4],$modarray[3]);
			}

			$self->{'apertures'}{$apt}{'modifiers'} = join('X',@modarray);

		}
	}
 }

}

=head1 AUTHOR

 C. A. Church
 MacroFab, Inc.
 
=head1 SEE ALSO

 L<The Gerber File Format Specification|http://www.ucamco.com/files/downloads/file/3/the_gerber_file_format_specification.pdf>
 
=cut

1;


 
 

