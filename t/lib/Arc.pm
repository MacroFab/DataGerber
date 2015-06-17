#!/usr/bin/env perl

use strict;
use warnings;


package Arc::Test;
use base qw(Parser::Test::Base);

use Test::More;
use Data::Gerber::Writer;


sub arc : Tests()
{

    my $self = shift;
    my $testFile = './t/files/arc.gbl.test';

    my $gerber = $self->{'parser'}->parse($testFile);

    ok(defined($gerber), 'Validated Gerber arc file was parsed.');

}

sub g36 : Tests()
{

    my $self = shift;
    my $testFile = './t/files/g37.arc.test';

    my $gerber = $self->{'parser'}->parse($testFile);

    ok(defined($gerber), 'Validated Gerber G37 file was parsed.');

}


1;
