#
# Data::Gerber::Parser
#
# Parse Gerber RS-247X Formatted Lines
#
# (c) 2014 MacroFab, Inc.
# Author: C. A. Church
#================================================

package Data::Gerber::Parser;

use strict;
use warnings;

use Data::Gerber;

our $VERSION = "0.01";

=head1 NAME

Data::Gerber::Parser

=cut

=head1 SYNOPSIS

	my $gbParse = Data::Gerber::Parser->new();
	
	my    $gerb = $gbParse->parse($data);
 	
 	if( ! defined($gerb) ) {
 		die $gbParse->error();
 	}
 	
	
=cut

=head1 DESCRIPTION

 Data::Gerber::Parser parses RS-274X (Gerber) data from a file, or from an array
 of lines read from a file, checks for validity, and constructs an MFGerber
 object from its contents.
 
=cut


=head1 METHODS

=cut


=item new( OPTS )

 Constructor, creates a new instance of the class.
 
 	my $gbParse = Data::Gerber::Parser->new();

 OPTS is a hash with any of the following keys:
 
 	ignoreInvalid => if true value, ignore any invalid or deprecated G-codes, false
 		  	 throws error.  Default = false.
 	
 	ignoreBlank   => if true value, ignore blank drawing in calculating box size
 			 and drawing bounds
 		  
 for example: 
 
 	my $gbParse = Data::Gerber::Parser->new( 'ignoreInvalid' => 1 );
 	
 	
=cut

sub new {
 my $class = shift;
 my $self = bless({}, $class);

 my %opts = @_;
 
 $self->{'error'}       = undef;
 $self->{'gerbObj'}     = undef;
 $self->{'parsestate'}  = {};
 $self->{'line'}        = 0;
 $self->{'ignore'}      = 0;
 $self->{'ignoreBlank'} = 0;
 $self->{'lastDCode'}   = undef;
 
 
 if( exists($opts{'ignoreInvalid'}) && defined($opts{'ignoreInvalid'}) ) {
 	$self->{'ignore'} = $opts{'ignoreInvalid'};
 }

 if( exists($opts{'ignoreBlank'}) && defined($opts{'ignoreBlank'}) ) {
 	$self->{'ignoreBlank'} = $opts{'ignoreBlank'};
 } 
 
 return $self;	
}


=item error

 Returns the last set error, or undef if no error has been set
 
=cut


sub error {
	
 my $self = shift;
 $self->{'error'} = "$_[0] [line $self->{'line'}]" if(defined($_[0]));
 return $self->{'error'};
}


=item parse(DATA)

 Parse an array of lines, or a data file and return a new MFGerber object
 representing the file. 
 
 If DATA is an ARRAYREF it will be treated as an array of file lines.
 If DATA is any other value, it will be treated as the path of a file to open.
 
 If an error occurs, the returned value will be undef and the error value will
 be set.  E.g.:
 
 	my $gerb = $gbParse->parse($data);
 	
 	if( ! defined($gerb) ) {
 		die $gbParse->error();
 	}
 	
=cut

sub parse {
	
 my $self = shift;
 my $data = shift;

 $self->{'error'}     = undef;
 $self->{'line'}      = 0;
 $self->{'lastDCode'} = undef;
 
 if( ! defined($data) ) {
 	 $self->error("[parse] ERROR: No Data Provided");
 	 return undef;
 }

 	# initialize a new object
 $self->{'gerbObj'} = Data::Gerber->new();
 $self->{'gerbObj'}->ignoreInvalid( $self->{'ignore'} );
 $self->{'gerbObj'}->ignoreBlank( $self->{'ignoreBlank'} );
 
 $self->{'parseState'} = {};

 
 if( ref($data) eq 'ARRAY' ) {
 	 if( $#{ $data } < 0 ) {
 	 	# no lines!
 	 	return $self->{'gerbObj'}; 
 	 }
 	 
 	 foreach(@{ $data }) {
 	 	 if( ! $self->_parseLine($_) ) {
 	 	     return undef;
 	 	 }
 	 }
 }
 else {
 	 if( length($data) < 1 ) {
 	 	 # no file name? dang!
 	 	 $self->error("[parse] ERROR: No File Name Provided for File Mode");
 	 	 return undef;
 	 }
 	 
 	 my $rfh;
 	 
 	 if( ! open($rfh, $data) ) {
 	 	 $self->error("[parse] ERROR: Could not open $data -> $!");
 	 	 return undef;
 	 }

     local $/;
     my $data = <$rfh>;

     my @lines = split(/\r[^\n]|\n/, $data);

     close($rfh);

     foreach my $line ( @lines ) {
         $line =~ s/\r//g;
         if ( !$self->_parseLine($line) ) {
             return undef;
         }
     }
 }
 
 return $self->{'gerbObj'};
}



sub _parseLine {
	
 my $self = shift;
 my $line = shift;
 
 $self->{'line'}++;

 chomp($line);
 
 if ( ! defined($line) || ! length($line) || $line =~ /^\s*$/ || $line =~ /^\*$/ || $line =~ /^\s*\*\s*$/) {
     return 1;
 }
 
 	# had we already started a multi-line parameter?
 if( defined( $self->{'parseState'}{'startParam'} ) ) {
 	 if( $line !~ /.*%\s*$/ ) {
 	 	 	# no end of parameter yet?
 	 	 $self->{'parseState'}{'startParam'} .= $line;
 	 	 return 1;
 	 }
 	 else {
 	 	 	# end of parameter found
 	 	 $line =~ s/%//g;
 	 	 $line = $self->{'parseState'}{'startParam'} . $line;
 	 	 $self->{'parseState'}{'startParam'} = undef;
 	 	 return $self->_parseParam($line);
 	 }
 }
 
 
 	 # start of a multi-line parameter	 
 if( $line =~ /^\s*%([^%]+)$/ ) {
 	 $self->{'parseState'}{'startParam'} = $1;
 	 return 1;
 }
 
 if( $line =~ /^\s*%([^%]+)%\s*$/ ) {
 	 
 	 	# single-line parameter
 	$self->{'parseState'}{'startParam'} = undef;
 	
 	return $self->_parseParam($1); 	
 }
 
 	# can have multiple commands on one line
 my @commands = split(/\*/, $line);
 
 foreach my $com (@commands) {
	 # from this point on, eliminate command-ending asterisks
		
	 $com =~ s/\*$//;
	 
	 if( $com =~ /^G\d+/ ) {
		 return undef if(! $self->_parseCommand($com));
	 }
	 elsif( $com =~ /^D0/ || $com =~ /^D\d$/ ) {
		if ($self->{'ignore'}) {
			return undef if(! $self->_parseMove($com));
		}
		else { 
		    $self->error("[parse] Cannot Have OpCode Alone on Line: $com");
			return undef if(! $self->_parseMove($com));
		}
	 }
	 elsif( $com =~ /^D[1-9]\d+$/ ) {
		 return undef if(! $self->_parseAperture($com));
	 }
	 elsif( $com =~ /^M02/ ) {
		 return 1;
	 }
	 else {
		 return undef if(! $self->_parseMove($com) );
	 }
 }
 
 return 1;
 
}


 # parse a command line
sub _parseCommand {
	
 my $self = shift;
 my $line = shift;

 my($com, $coord, $opcode);
 
 	# extract command code
 
 if( $line =~ s/^(G\d+)// ) {
 	 $com = $1;
 }

 	# deal with comments specially
 if( defined($com) && ( $com eq 'G04' || $com eq 'G4' ) ) {
 	 if( ! $self->{'gerbObj'}->function('func' => $com, 'comment' => $line ) ) {
 	 	$self->error( $self->{'gerbObj'}->error() );
 		return undef;
 	 }
	return 1;
 }
 
 	# are there characters in the line after the command code?
 if ( $line =~ /\w+/ ) {
     if ( defined($com) && $line =~ m/^(X[+\-]?\d+)?(Y[+\-]?\d+)?(I[+\-]?\d+)?(J[+\-]?\d+)?(D\d+)?/ ) {
        my $x = $1;
        my $y = $2;
        my $i = $3;
        my $j = $4;
        my $opcode = $5;

        my %opts = (
            'func' => $com,
        );

        my $coord;

        # Circular interpolation doesn't always contain X/Y/I/J.
        if ( defined($x) ) {
            $coord = $x;
        }
        if ( defined($y) ) {
            $coord .= $y;
        }
        if ( defined($i) ) {
            $coord .= $i;
        }
        if ( defined($j) ) {
            $coord .= $j;
        }

        $opts{'coord'} = $coord;

        # Circular interpolation also leaves off D codes; presumably,
        # this implies reusing the previous D code.
        if ( !defined($opcode) ) {
            $opts{'op'} = $self->{'lastDCode'};
        }
        else {
            $opts{'op'} = $opcode;
            $self->{'lastDCode'} = $opcode;
        }

        if ( !$self->{'gerbObj'}->function(%opts) ) {
            $self->error($self->{'gerbObj'}->error());
            return undef;
        }
     }
 	 elsif( defined($com) && $com eq 'G54' && $line =~ /^D[1-9]\d+/) {
 	 	 # tool select command
		 $self->_parseAperture($line);
 	 }
     # 
 	 else {
 	 	 	# otherwise, we don't know what you mean!
 	 	 $self->error("[parse] Invalid instruction following command code $com: $line");
 	 	 return undef;
 	 }
 }
 
 if( ! $self->{'gerbObj'}->function('func' => $com, 'coord' => $coord, 'op' => $opcode) ) {
 	 $self->error( $self->{'gerbObj'}->error() );
 	 return undef;
 }
  
 return 1;
 
}


sub _parseMove {
	
 my $self = shift;
 my $line = shift;

 my ($coord, $opcode); 
 
 if( $line =~ /^(.+)(D\d+)/ ) {
	 $coord = $1;
	 $opcode = $2;
	 $self->{'lastDCode'} = $opcode;
 }
 elsif( $line =~ /^(D0*[1-9]{1})/ ) {
	 $opcode = $1;
	 $self->{'lastDCode'} = $opcode;
 }
 else {
        # can we re-use a previous dcode?  Re-using d-codes is deprecated in the
        # spec, but many tools still write this notation
     if( defined($self->{'lastDCode'}) && length($self->{'lastDCode'}) ) {
         $opcode = $self->{'lastDCode'};
         $coord  = $line;
     }
     else {
            # otherwise, we don't know what you mean!
         $self->error("[parse] Invalid move instruction: $line");
         return undef;
     }
 }

 if( ! $self->{'gerbObj'}->function('coord' => $coord, 'op' => $opcode) ) {
 	 $self->error( $self->{'gerbObj'}->error() );
 	 return undef;
 }
  
 return 1;
  
 
}

 # parse an aperture selection line

sub _parseAperture {
	
 my $self = shift;
 my $aper = shift;
 
 if( ! $self->{'gerbObj'}->function('aperture' => $aper) ) {
 	 $self->error( $self->{'gerbObj'}->error() );
 	 return undef;
 }
  
 return 1;
 
} 	 
 

sub _parseParam {
	
 my $self = shift;
 my $line = shift;
 
 return 1 if( ! defined($line) || ! length($line) );
 
 my $pCode = substr($line, 0, 2, '');


 if    ( $pCode eq 'FS' ) { $self->_paramFS( $line ) }
 elsif ( $pCode eq 'MO' ) { $self->_paramMO( $line ) }
 elsif ( $pCode eq 'AD' ) { $self->_paramAD( $line ) }
 elsif ( $pCode eq 'LP' ) { $self->_paramLP( $line ) }
 elsif ( $pCode eq 'SR' ) { $self->_paramSR( $line ) }
 elsif ( $pCode eq 'AM' ) { $self->_paramAM( $line ) }
 else { $self->error( $self->{'gerbObj'}->error() )};
 
 return 1;
 
}
 	 
 
 # Process format specification parameter
 
sub _paramFS {
	
 my $self = shift;
 my $data = shift;
 
 $data =~ s/\*.*//g; # get rid of anything trailing the format spec
 
 my($zero, $coord, $int, $dec);
 
 if( $data =~ /^([L|T])(A|I)/i ) {
 	 $zero	= $1;
 	 $coord = $2;
 }
 else {
 	 $self->error("[parse] Invalid FS Parameter Value: $data");
 	 return undef;
 }
 
 	# Spec requires X and Y formats to be the same, so only look for X
 
 if( $data =~ /X(\d{2})/ ) {
 	 ($int, $dec) = split(//,$1);
 }
 else {
 	 $self->error("[parse] Invalid FS Parameter Value: $data");
 	 return undef;
 }

 if( ! $self->{'gerbObj'}->format( 'zero' => $zero, 'coordinates' => $coord, 'format' => { 'integer' => $int, 'decimal' => $dec } ) ) {
 	$self->error( $self->{'gerbObj'}->error() );
 	return undef;
 }
 
 return 1;
}
 
 # Process mode parameter
 
sub _paramMO {
	
 my $self = shift;
 my $data = shift;
 
 $data =~ s/\*.*//g;
  
 if( $data !~ /in|mm/i ) {
 	 $self->error("[parse] Invalid MO Parameter Value: $data");
 	 return undef;
 }
 	 
 $self->{'gerbObj'}->mode($data);
 
 return 1;

}


 # Process Aperture Definition Parameter
 
sub _paramAD {
 
 my $self = shift;
 my $data = shift;
 
 $data =~ s/\*.*//g;
 
 if( $data =~ /^D(\d+)([a-z_\$]{1}[a-z0-9_\$]{0,})(.*)$/i ) {
 	my $aper = $1;
 	my $type = $2;
 	my  $mod = $3;
 	
 	if( $aper < 10 ) {
 		$self->error("[parse] Invalid User-Defined Aperture Number: $aper, From: $data");
 		return undef;
 	}
 	
 	if( $mod =~ /,(.*)$/ ) {
 		$mod = $1;
 	}
 	
 	if( ! $self->{'gerbObj'}->aperture( 'code' => "D$aper", 'type' => $type, 'modifiers' => $mod ) ) {
 		$self->error( $self->{'gerbObj'}->error() ); # error bubbles up
 		return undef;
 	}
 }
 else {
 	 $self->error("[parse] Invalid AD Parameter Value: $data");
 	 return undef;
 }
 
 return 1;
 
}

sub _paramAM
{

    my $self = shift;
    my $data = shift;

    my @baseMacroParts = split(/\*/, $data, 3);

    my $macroName = $baseMacroParts[0];

    shift(@baseMacroParts);

    my @allMacroParts;
    my @validMacroParts;

    # Macros can be squished together on one line, e.g:
    # 0 EVEN MORE COMMENTS*0 SO MANY COMMENTS*21,1,0.00984,0.01476,0,0,0*'
    # Thus, we need to split each line, and add it to a master array.
    foreach my $part ( @baseMacroParts ) {
        my @parts = split(/\*/, $part);

        push(@allMacroParts, @parts);
    }

    foreach my $part ( @allMacroParts ) {
        if ( $part =~ m/^0/ ) {
            next;
        }
        push(@validMacroParts, $part);
    }

    my $macroDef = join('*', @validMacroParts);

    $macroDef =~ s/\*//g;
    my @macro = split(/,/, $macroDef);

    my $res = $self->{'gerbObj'}->macro($macroName, \@macro);

    if ( ref($res) eq 'HASH' ) {
        $self->error("[_paramAM] invalid aperture macro definition: $data");
        return undef;
    }

    return 1;

}

sub _paramLP {

 my $self = shift;
 my $data = shift;
 
 $data =~ s/\*.*//g;
 
 if( $data ne 'D' && $data ne 'C' ) {
 	 $self->error("[parse] Invalid LP Parameter Value: $data");
 	 return undef;
 }
 
 	# note we add this as a function, as it can be repeated
 	# often
 if( ! $self->{'gerbObj'}->function( 'param' => "LP$data" ) ) {
 	$self->error( $self->{'gerbObj'}->error() ); # error bubbles up
 	return undef;
 } 	

 return 1;
} 

sub _paramSR {

 my $self = shift;
 my $data = shift;
 
 $data =~ s/\*.*//g;
 
 	# note we add this as a function, as it can be repeated
 	# often
 if( ! $self->{'gerbObj'}->function( 'param' => "SR$data" ) ) {
 	$self->error( $self->{'gerbObj'}->error() ); # error bubbles up
 	return undef;
 } 	

 return 1;
} 

=head1 AUTHOR

 C. A. Church
 MacroFab, Inc.
 
=head1 SEE ALSO

 L<The Gerber File Format Specification|http://www.ucamco.com/files/downloads/file/3/the_gerber_file_format_specification.pdf>
 L<MFGerber>
 
=cut


1;
