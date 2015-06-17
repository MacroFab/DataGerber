#!/usr/bin/env perl

use strict;
use warnings;


package Convert::Test;
use base qw(Parser::Test::Base);

use Test::More;
use Data::Gerber::Writer;

sub convert : Tests()
{

    my $self = shift;
    my $masterFile = './t/files/master.test';
    my $convertFile = './t/files/mm4.convert.test';

    my $masterGerber = $self->{'parser'}->parse($masterFile);
    my $convertGerber = $self->{'parser'}->parse($convertFile);

    $convertGerber->convert($masterGerber);

    my $writer = Data::Gerber::Writer->new();
    $writer->write($convertFile . '.converted', $convertGerber);

}

1;
