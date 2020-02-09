#! /usr/bin/env perl
#################################################################################
#     File Name           :     lib/Debug.pm
#     Created By          :     jnikolich
#     Creation Date       :     [2015-04-23 11:35]
#     Last Modified       :     [2020-02-08 23:50]
#     Description         :     Simple class implementing indented debug output
#################################################################################
# Copyright (C) 2020 James D. Nikolich
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#################################################################################

package SalesFinder::Debug;

use strict;
use warnings;

use Data::Dumper;
use parent 'Exporter';	# Imports and subclasses Exporter

our $debug = SalesFinder::Debug->new();

our @EXPORT = qw( $debug );

sub new
{
	my $proto	= shift;
	my $class	= ref($proto) || $proto;
	my $self	= {};
	$self->{_ACTIVE}	= 0;
	$self->{_INDENT}	= -1;
	$self->{_SIZE}		= 4;

	bless( $self, $class );
	return( $self );
}

sub activate
{
	my $self = shift;
	$self->{_ACTIVE} = 1;
	return $self->{_ACTIVE};
}

sub deactivate
{
	my $self = shift;
	$self->{_ACTIVE} = 0;
	return $self->{_ACTIVE};
}

sub isactive
{
	my $self = shift;
	return $self->{_ACTIVE};
}

sub size
{
	my $self	= shift;
	my $newsize	= shift;

	if( defined $newsize ) { $self->{_SIZE} = $newsize >= 0 ? $newsize : $self->{_SIZE} }

	return $self->{_SIZE};
}

sub indent
{
	my $self = shift;
	my $numindents = shift;

	# Increment the indent level by the number specified, or 1 if unspecified.
	$self->{_INDENT} += $numindents ? $numindents : 1;

	return $self->{_INDENT};
}

sub outdent
{
    my $self = shift;
	my $numindents = shift;

	# Decrement the indent level by the number specified, or 1 if unspecified.
	# If the result is less than 0 indents, then keep at 0.
    $self->{_INDENT} -= $numindents ? $numindents : 1;
	$self->{_INDENT} = $self->{_INDENT} >= 0 ? $self->{_INDENT} : 0;

    return $self->{_INDENT};
}

sub say
{
    my $self = shift;
	my $output = "";

    if( $self->{_ACTIVE} )
    {
		# Prepend indentsize * indentcount spaces to the output string
		$output .= " " x ( $self->{_SIZE} * $self->{_INDENT } );
        $output .= "@_";

        say STDERR $output;
    }
    return $output;
}

sub dumper
{
	my $self = shift;
	my $output = "";

    if( $self->{_ACTIVE} )
    {
		$output = Dumper @_;

        say STDERR $output;
    }
    return $output;
}

sub subenter
{
	my $self = shift;

	package DB;

	$self->indent( );
	my $output = sprintf( ">%2.2d> Entered ", $self->{_INDENT} );
	$output = $output . (caller(1))[3] . "( " . join( ", ", @DB::args ) . " )";
	$self->say( $output );
	
	return;
}

sub subexit
{
	my $self = shift;

	my $retcode = shift;
	$retcode="none" unless defined $retcode;

	package DB;

	my $output = sprintf( ">%2.2d> Exiting ", $self->{_INDENT} );
	$output = $output . (caller(1))[3] . "( ) [return=$retcode]";
	$self->say( $output );
	$self->outdent( );

	return;
}

1;
