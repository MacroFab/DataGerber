#!/usr/bin/env perl

use strict;
use warnings;


package DCode::Test;
use base qw(Parser::Test::Base);

use Test::More;


sub dcode : Tests()
{

    my $self = shift;
    my $testFile = './t/files/dcode.test';

    my $gerber = $self->{'parser'}->parse($testFile);

    ok(defined($gerber), 'Validated Gerber object contained continuing D code.');

}

1;
