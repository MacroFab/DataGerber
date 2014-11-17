#
# Data::Gerber::Writer 
# (Derived from Data::Gerber::Parser by C. Church)
#
# Parse Gerber RS-247X Formatted Lines
#
# (c) 2014 MacroFab, Inc.
# Author: Dan Calderon 
#================================================

package Data::Gerber::Writer;

use strict;
use warnings;

use Data::Gerber;
use Data::Dumper;

our $VERSION = "0.01";

=head1 NAME

Data::Gerber::Writer

=cut

=head1 SYNOPSIS

	my $gbParse = Data::Gerber::Writer->new();	
	my    $gerb = $gbWrite->write($data);	
 	if( ! defined($gerb) ) {
 		die $gbParse->error();
 	}
	
=cut

=head1 DESCRIPTION

 Data::Gerber::Writer writes RS-274X (Gerber) data from a MFGerber Object, checks for validity, and writes the contents to a file.
 
=cut

=head1 METHODS

=cuta
=item new( OPTS )

 Constructor, creates a new instance of the class.
 
 	my $gbParse = Data::Gerber::Writer->new();

 OPTS is a hash with any of the following keys:
 
 	ignoreInvalid => if true value, ignore any invalid or deprecated G-codes, false
 		  	 throws error.  Default = false.	
 	ignoreBlank   => if true value, ignore blank drawing in calculating box size
 			 and drawing bounds
 		  
 for example: 
 	my $gbParse = Data::Gerber::Writer->new( 'ignoreInvalid' => 1 );	
=cut

sub new {									# Create New MFWrite Object
 my $class = shift;
 my $self = bless({}, $class);
 my %opts = @_;
 
 $self->{'error'}       = undef;
 $self->{'ignore'}      = 0;
 $self->{'ignoreBlank'} = 0;
 
 if( exists($opts{'ignoreInvalid'}) && defined($opts{'ignoreInvalid'}) ) {
 	$self->{'ignore'} = $opts{'ignore'};
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

=item write(FILE, GERB)

 Write a data FILE from a given MFGerber object GERB
 If an error occurs, the returned value will be undef and the error value will
 be set.  E.g.:
 
 	$gbWrite->write($data);
 	
 	if( ! defined($gerb) ) {
 		die $gbParse->error();
 	}
 	
=cut

sub MFwrite {
 my $self = shift; my $file = shift; my $gerb = shift;

 $self->{'error'} = undef;
 if( ! defined($file) ) {
 	 $self->error("[parse] ERROR: No File Provided");
 	 return undef;
 }
 open (MASTER_FILE, ">", $file) || die ("Error in writing" . $file);			# Open Master File
 
 if( length($file) < 1 ) {						
 	$gerb->error("[parse] ERROR: No File Name Provided for File Mode");		# no file name? dang!
 	return undef;
 }											#####################
 my $FSzero   = $gerb->{'parameters'}{'FS'}{'zero'}; 
 my $FScoord  = $gerb->{'parameters'}{'FS'}{'coordinates'}; 
 my $FSformat = $gerb->{'parameters'}{'FS'}{'format'} ;

 print MASTER_FILE "\%MO" . $gerb->{'parameters'}{'mode'} . "*\%\n"; 			# Print Header Parameters: FS, MO etc.)
 print MASTER_FILE "\%FS".$FSzero.$FScoord."X".$FSformat->{'integer'}. $FSformat->{'decimal'}."Y".$FSformat->{'integer'}.$FSformat->{'decimal'}. "*\%\n";
 foreach my $macrokeys (keys $gerb->{'macros'}) {
	 print MASTER_FILE "\%AM" . $macrokeys ."*". $gerb->{'macros'}{$macrokeys} . "*\%\n"; 			# Print Header Parameters: FS, MO etc.)	
#	 print "\%AM". $macrokeys ."*". $gerb->{'macros'}{$macrokeys} . "*\%\n";	
 }
# print MASTER_FILE "\%AM".$FSzero.$FScoord."X".$FSformat->{'integer'}. $FSformat->{'decimal'}."Y".$FSformat->{'integer'}.$FSformat->{'decimal'}. "*\%\n";
											#####################
 my $master_ap; my $apcount;

 while (($apcount,$master_ap) = each($gerb->{'apertures'})) {				# Print Apertures
 	print MASTER_FILE "\%AD" . $apcount . $master_ap->{'type'} . ',' . $master_ap->{'modifiers'} . "*\%\n";
 }
											#####################
 my $master_func; my $fcount; my $f_func; my $f_coord; my $f_op;

 while (($fcount,$master_func) = each($gerb->{'functions'})) {				# Print Functions
	if (exists($master_func->{'aperture'}) && defined($master_func->{'aperture'})){	# For each function in the hash, if aperture, print.
		print MASTER_FILE $master_func->{'aperture'} . "*\n";
	}
	elsif (exists($master_func->{'param'}) && defined($master_func->{'param'})){	# For each function in the hash, if param, print.
 		print MASTER_FILE "\%" . $master_func->{'param'} . "*\%\n";
	}
	else {										# For each function in the hash, if function, print.
		$f_func = ''; $f_coord = ''; $f_op = '';
		if (exists($master_func->{'func'})  && defined($master_func->{'func'})) {$f_func  = $master_func->{'func'}};
		if (exists($master_func->{'coord'}) && defined($master_func->{'coord'})){$f_coord = $master_func->{'coord'}};
		if (exists($master_func->{'op'})    && defined($master_func->{'op'}))   {$f_op    = $master_func->{'op'}};
		if ($f_func !~ /G54/) {
 			print MASTER_FILE $f_func . $f_coord . $f_op . "*\n";
		}
	}
 }
 print MASTER_FILE "M02*\n";
 close (MASTER_FILE);
}

=head1 AUTHOR

 D. Calderon
 MacroFab, Inc.
 
=head1 SEE ALSO

 L<The Gerber File Format Specification|http://www.ucamco.com/files/downloads/file/3/the_gerber_file_format_specification.pdf>
 L<MFGerber>
 
=cut

1;
