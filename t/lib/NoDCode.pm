#!/usr/bin/env perl

use strict;
use warnings;


package DCode::Test;
use base qw(Parser::Test::Base);

use Test::More;


sub noDcode : Tests()
{

    my $self = shift;
    my $testFile = './t/files/no_dcode.test';

    my $gerber = $self->{'parser'}->parse($testFile);

    ok(!defined($gerber), 'Validated Gerber parsing fails with invalid D code.');

}

1;
