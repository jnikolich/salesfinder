#! /usr/bin/env perl
#################################################################################
#     File Name           :     cfggenerator.pl
#     Created By          :     jnikolich
#     Creation Date       :     [2020-01-24 23:25]
#     Last Modified       :     [2020-02-08 23:55]
#     Description         :     Takes a perl-data structure and does a JSON conversion
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


#################################################################################
# This program takes a perl data structure (simple or complex), and encodes it 
# into JSON form.  
#
# The resulting JSON encodings are output to STDOUT, for easy redirection into
# a file, or for easy copy-pasting.
#
# The author finds it easier to create data-structures this way that are both
# perl and JSON-compliant, since the perl interpreter will do syntax-checking.
#################################################################################


### Define some environmental characteristics
use strict;
use warnings;
use 5.010;

use Data::Dumper;

use Pod::Usage;
use JSON::MaybeXS qw( encode_json decode_json );

sub main
{
    my $dataPerl =
    {

	### GLOBAL OPTIONS - Affect the operation of the program in-general
	##
	'configfile'	=> '/etc/salesfinder.json',
	'dbfile'	=> '~/.salesfinder/salesfinder.db',
	'silent'	=> '',
	'notify'	=> '',
	'email'		=> '',
	'mailserver'	=> '',
	'debug'		=> '',


	### MERCHANTS - Defines config specific to each merchant
	'merchants' =>
	{
	    'BestBuy' =>
	    {
		'base_url'		=> 'https://www.bestbuy.ca/en-ca/product/',
		'price_delim_start'	=> 'priceWithoutEhf\":',
		'price_delim_end'	=> '\,',
	    },

	    'CanadaComputers' =>
	    {
		'base_url'		=> 'https://www.canadacomputers.com/product_info.php?',
		'price_delim_start'	=> 'newtotal -= ',
		'price_delim_end'	=> ' ',
	    },

	    'NewEgg' =>
	    {
		'base_url'		=> 'https://www.newegg.ca/p/',
		'price_delim_start'	=> 'product_sale_price:\[\'',
		'price_delim_end'	=> '\'\]',
	    },
	},


	### PRODUCTS - Defines config specific to each product
	'products' =>
	{
	    'ex2780q' =>
	    {
		'desc'		    => 'Benq EX2780Q 1440p 27-inch IPS monitor',
		'alert_price'	    => '499.99',
		'sold_by' =>
		{
		    'BestBuy' =>
		    {
			'prod_link' => 'benq-27-1440p-wqhd-144hz-5ms-gtg-ips-lcd-freesync-gaming-monitor-ex2780q-black/13893428',
			'reg_price' => '599.99',
		    },

		    'CanadaComputers' =>
		    {
			'prod_link' => 'cPath=22_700_1104&item_id=140272',
			'reg_price' => '599.99',
		    },

		    'NewEgg' =>
		    {
			'prod_link' => 'N82E16824014661',
			'reg_price' => '799.99',
		    },
		}
	    },

	    'c27hg70' =>
	    {
		'desc'		    => 'Samsung CHG70 Series 1440p 27-inch VA monitor',
		'alert_price'	    => '499.99',
		'sold_by' =>
		{
		    'CanadaComputers' =>
		    {
			'prod_link' => 'cPath=22_700_1104&item_id=112035',
			'reg_price' => '749.99',
		    },
		    'NewEgg'	    =>
		    {
			'prod_link' => 'N82E16824022583',
			'reg_price' => '730.33',
		    },
		},
	    },
	}
    };

    my $json = JSON::MaybeXS->new(utf8 => 1, pretty => 1, sort_by => 1 );
    my $dataJSON = $json->encode( $dataPerl );
#    say STDERR "--- START Configuration Data converted to a JSON data-structure -------";
    print  $dataJSON;
#    say STDERR "--- END ---------------------------------------------------------------";
#    say STDERR "";

#    my $dataConvertedPerl = decode_json $dataJSON;
#    say STDERR "--- START Data converted back to a PERL data-structure for validation -";
#    print Dumper $dataConvertedPerl;
#    say STDERR "--- END ---------------------------------------------------------------";
}

main( @ARGV );

# vim: autoindent tabstop=8 softtabstop=4 shiftwidth=4 noexpandtab
