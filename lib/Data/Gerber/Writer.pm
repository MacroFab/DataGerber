#
# Data::Gerber::Writer 
#
# Parse Gerber RS-247X Formatted Lines
#
# (c) 2015 MacroFab, Inc.
# Author: Dan Calderon (0.01),
#         Chris Church (0.2 re-write)
#================================================

package Data::Gerber::Writer;

use strict;
use warnings;

use Data::Gerber;
use Data::Dumper;

our $VERSION = "0.2";

=head1 NAME

Data::Gerber::Writer

=head1 SYNOPSIS

    my $gerb = Data::Gerber->new();
    
        # create some gerber information in $gerb...
        
	my $gbWrite = Data::Gerber::Writer->new();	
	
	if( ! $gbWrite->write('/tmp/new.grb', $gerb ) {
 		die $gbWrite->error();
 	}
	

=head1 DESCRIPTION

 Data::Gerber::Writer generates a new RS-274X (Gerber) output file from a Data::Gerber Object.
 
 

=head1 METHODS

=head2 new( OPTS )

Constructor, creates a new instance of the class.
 
 	my $gbWrite = Data::Gerber::Writer->new();

OPTS is a hash with any of the following keys:
 
 	ignoreInvalid => if true value, ignore any invalid or deprecated G-codes, false
 		  	 throws error.  Default = false.	
 	ignoreBlank   => if true value, ignore blank drawing in calculating box size
 			 and drawing bounds
 		  
for example: 
 	my $gbWrite = Data::Gerber::Writer->new( 'ignoreInvalid' => 1 );	
 	
=cut

sub new {									
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


=head2 error

Returns the last set error, or undef if no error has been set
 
=cut

sub error {
	
 my $self = shift;
 $self->{'error'} = "$_[0] [line $self->{'line'}]" if(defined($_[0]));
 return $self->{'error'};
}

=head2 write(PATH, GERB)

Create a new Gerber file at location PATH, generating contents from the
Data::Gerber object GERB.

if PATH is a string, a file is created using that string as the full path to the
file.  However, if PATH is a file handle, the data is written to that file handle
instead, and no new file is created. 

Returns true (1) on success, undef and sets the error on error.
 
        # create a new file
        
 	if( ! $gbWrite->write('/tmp/foo.grb', $gerb) ) {
 		die $gbWrite->error();
 	}
 	
 	
 	    # write to in-memory file handle (e.g. make a scalar from it)
 	
 	my($contents, $fh);
 	
 	open( $fh, '>', \$contents);
 	
 	if( ! $gbWrite($fh, $gerb) ) { ... }
 	
 	
 	
 	    # write to an already opened filehandle
 	    
 	my $file;
 	
 	open($file, '>', '/tmp/blah.grb');
 	
 	if( ! $gbWrite($file, $gerb) ) { ... }
 	
 	
=cut

sub write {
    
 my $self = shift; 
 my $file = shift; 
 my $gerb = shift;

 if( ! defined($file) ) {
 	 $self->error("[write] ERROR: No File path or handle Provided");
 	 return undef;
 }
 
 if( ! defined($gerb) || ! $gerb->isa('Data::Gerber') ) {
     $self->error("[write] ERROR: No Data::Gerber object provided");
     return undef;
 }
 
  
 my $wfh;
 my $isFh = 0;
 
 eval { $file->can('write') };

 if( ref($file) eq 'GLOB' && !$@ ) {
      print STDERR "DBG: Got file handle\n";

     # this is a file handle of some sort?
     $wfh  = $file;
     $isFh = 1;

 }
 else {
    print STDERR "DBG: Got file path\n";

     # this is a scalar, let's open a file at that path
     if( ! open($wfh, '>', $file) ) {
         $self->error("[write] Cannot open $file for writing -> $!");
         return undef;
     }

 }
 
 my   $mode = $gerb->mode();
 my $format = $gerb->format();
  	
    # print format header
    
 print $wfh '%FS' . $format->{'zero'} . $format->{'coordinates'};
 print $wfh 'X' . $format->{'format'}{'integer'} . $format->{'format'}{'decimal'};
 print $wfh 'Y' . $format->{'format'}{'integer'} . $format->{'format'}{'decimal'};
 print $wfh "*%\n";

     # print mode header
 print $wfh '%MO' . $gerb->mode() . "*%\n";

    # write macros
    
 my $macros = $gerb->macros();
 
 foreach my $key ( keys(%{ $macros }) ) {
     my $strings = join("*\n", @{ $macros->{$key} });
     print $wfh '%AM' . $key . "*\n" . $strings . "*%\n";
 }
 
    # write apertures
    
 my $apertures = $gerb->apertures();
 
 foreach my $key ( keys(%{ $apertures }) ) {
     print $wfh '%AD' . $key . $apertures->{$key}{'type'} . ',' . $apertures->{$key}{'modifiers'} . "*%\n";
 }
 
    # write functions
    
 my @functions = $gerb->functions();
 
 foreach (@functions) {
     if( exists($_->{'aperture'}) && defined($_->{'aperture'}) ) {
         print $wfh $_->{'aperture'} . "*\n";
     }
     elsif( exists($_->{'param'}) && defined($_->{'param'}) ) {
         print $wfh '%' . $_->{'param'} . "*%\n";
     }
     else {
         my  $func = ( exists($_->{'func'})  && defined($_->{'func'}) )  ? $_->{'func'}  : '';         
         my $coord = ( exists($_->{'coord'}) && defined($_->{'coord'}) ) ? $_->{'coord'} : '';
         my    $op = ( exists($_->{'op'})    && defined($_->{'op'}) )    ? $_->{'op'}    : '';
     
         print $wfh "${func}${coord}${op}*\n";
     }
 }
 
 print $wfh "M02*\n";
 
 if( ! $isFh ) {
     close ($wfh);
 }
 
 return 1;
 
}

=head1 AUTHOR

 D. Calderon
 MacroFab, Inc.
 
=head1 SEE ALSO

 L<The Gerber File Format Specification|http://www.ucamco.com/files/downloads/file/3/the_gerber_file_format_specification.pdf>
 L<MFGerber>
 
=cut

1;
