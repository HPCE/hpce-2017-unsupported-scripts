#!/usr/bin/perl

use strict;
use warnings;

my $inside=0;

my $enter=$ARGV[0];

print($enter);

while( my $line = <STDIN> ){
	if($line =~ /# [0-9]+ "$enter"/){
		$inside=1;
	}elsif($line =~ /# [0-9]+ ".+"/){
		$inside=0;
	}
	if($inside){
		print($line);
	}
}
