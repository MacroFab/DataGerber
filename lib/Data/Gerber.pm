#
#
# Basic Gerber Operations
# (c) 2014 MacroFab, Inc.
# Author: C. A. Church
#===========================================================


package Data::Gerber;

use strict;
use warnings;

our $VERSION = "0.01";

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
	'G74'  => 1,
	'G75'  => 1,
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

 $self->{'apertures'}  = {};
 $self->{'macros'}     = {};
 $self->{'boundaries'} = [];
 $self->{'parameters'} = {};
 $self->{'functions'}  = [];
 $self->{'error'}      = undef;
 $self->{'parseState'} = {};
 $self->{'nmc'}	       = 0;
 
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
 	 if( $1 < 10 ) {
 	 	 $self->error("[aperture] Invalid D-Code: $opts{'code'}");
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
	 
		# save
		
	 $self->{'apertures'}{ $opts{'code'} } = {
		 'type'	     => $opts{'type'},
		 'modifiers' => ( exists($opts{'modifiers'}) ) ? $opts{'modifiers'} : ''
	 };
 
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
 	
 B<Note: It is not recommended to use incremental coordinates.  In fact, you
 should always use absolute.>

=item format

 The format of distances and values used in commands.  As the specification
 requires that both X and Y format be the same, this module does not provide
 the ability to distinguish between the two.  
 
 The format of this entry is a hash reference, with the 'integer' and 
 'decimal' keys specifying the precision of integers and decimals in all numbers.
 
 For example:
 
 	'format' => {
 		'integer' => 5,
 		'decimal' => 7
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
 	 if( $opts{'zero'} =~ /^[la]/i ) {
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
 	 	 $self->error("[format] Invalid coordinates value: $opts{'zero'}");
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
 	 if( ! $self->_validateGC($opts{'func'}) ) {
 	 	 $self->error("[function] Invalid Function Code: $opts{'func'}");
 	 	 return undef;
 	 }
 }
 
 if( exists($opts{'op'}) && defined($opts{'op'}) ) {
 	 if( $opts{'op'} !~ /D0?[123]$/ ) {
 	 	 $self->error("[function] Invalid Operation Code: $opts{'op'}");
 	 	 return undef;
 	 }
 }
 
 
 	# if aperture specified, only allow aperture select in the function
 	
 if( exists($opts{'aperture'}) && defined($opts{'aperture'}) ) {
 	 	# verify that aperture has been defined
 	 if( ! exists($self->{'apertures'}{ $opts{'aperture'} }) ) {
 	 	 $self->error("[function] Invalid/Unknown Aperture Referenced: $opts{'aperture'}");
 	 }
 	 
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
 

 if( exists($opts{'coord'}) && ( ! exists($opts{'op'}) || ! defined($opts{'op'}) ) ) {
 	 $self->error("[function] Operation Code must be provided when Coordinate Data is provided");
 	 return undef;
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

 # validate g-codes
 
sub _validateGC {

 my $self = shift;
 my $code = shift;
 
 return 1 if( exists( $gCodes{$code} ) );
 return undef; 	 
	
}

=head1 AUTHOR

 C. A. Church
 MacroFab, Inc.
 
=head1 SEE ALSO

 L<The Gerber File Format Specification|http://www.ucamco.com/files/downloads/file/3/the_gerber_file_format_specification.pdf>
 
=cut

1;


 
 

