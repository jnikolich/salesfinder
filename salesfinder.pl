#! /usr/bin/env perl
#################################################################################
#     File Name           :     salesfinder.pl
#     Created By          :     jnikolich
#     Creation Date       :     [2020-01-24 09:43]
#     Last Modified       :     [2020-01-29 00:05]
#     Description         :     Scrapes webstores for preconfigured sales
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


### Define some environmental characteristics
use strict;
use warnings;
use 5.010;

use Getopt::Long qw( GetOptions );
Getopt::Long::Configure qw( gnu_getopt );
use Pod::Usage;
use JSON::MaybeXS qw( decode_json );
use Data::Dumper;
use WWW::Curl::Easy;

use Email::Stuffer;
use Email::Sender::Transport::SMTP( );


### Global configuration parameters
###
### Defaults are specified here, subject to being overwritten as follows:
###		Command-line args	- overwrite everything
###		Configuration file	- overwrites these defaults
my %CFG = (
    'configfile'    => '/etc/salesfinder.json',
    'notify'	    => '',
    'email'	    => '',
    'mailserver'    => '',
    'silent'	    => '',
    'cmd'	    => '',
    'debug'	    => '',
    'help'	    => '',
);


### main()
###
### Start-of-execution for this program.  The only global code is the invocation
### of this main function (located near the end of this file before the POD),
### and a global config hash.
###
### Args:	@_		= All arguments passed to this program
###
### Return:	true	= Completed OK
###
### Exits:	TBD
###
sub main
{
    SetupConfig( \%CFG );

DebugSay( <<"ENDhere" );
configfile  = $CFG{ 'configfile' }
notify	    = $CFG{ 'notify' }
email	    = $CFG{ 'email' }
silent	    = $CFG{ 'silent' }
cmd         = $CFG{ 'cmd' }
debug       = $CFG{ 'debug' }
help        = $CFG{ 'help' }
products:
ENDhere
DebugDumper( $CFG{ 'merchants' } );
DebugDumper( $CFG{ 'products' } );

    if( $CFG{'cmd'} eq "run" )
    {
	DoScrapes( );
    }
    elsif( $CFG{'cmd'} eq "list" )
    {
	ListMerchants( );
	ListProducts( );
	ListWhatEachMerchSells( );
    }
}


sub ListMerchants
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    print( "\n" );
    say( "Merchant         Price Start Delimiter      Price End Delimiter        Base URL");
    say( "---------------  -------------------------  -------------------------  ------------------------");
    while( my( $merchant, $merch_data ) = each( %{ $CFG { 'merchants' } } ) )
    {
	my $base_url = GetMerchantBaseURL( $merchant );
	my $price_delim_start = GetMerchantPriceDelimStart( $merchant );
	my $price_delim_end = GetMerchantPriceDelimEnd( $merchant );
	printf( "%-15.15s  %-25.25s  %-25.25s  %s\n", $merchant, $price_delim_start, $price_delim_end, $base_url );
    }
    print( "\n" );
}


sub ListProducts
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    print( "\n" );
    say( "Product          Description                               Alert @");
    say( "---------------  ----------------------------------------  --------");
    while( my( $product, $prod_data ) = each( %{ $CFG { 'products' } } ) )
    {
	my $prod_desc	= GetProductDesc( $product );
	my $alert_price	= GetProductAlertPrice( $product );
	printf("%-15.15s  %-40.40s  \$%7.7s\n", $product, $prod_desc, $alert_price );
    }
    print( "\n" );
}

sub ListWhatEachMerchSells
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    print( "\n" );
    say( "Merchant         Product          Regular   Product Link" );
    say( "---------------  ---------------  --------  ------------" );
    while( my( $merchant, $merch_data ) = each( %{ $CFG { 'merchants' } } ) )
    {
	my @prod_list = GetMerchantProductList( $merchant );
	my $first_prod = 'true';
	foreach( @prod_list )
	{
	    if( $first_prod )
	    {
		printf( "%-15.15s  ", $merchant );
		$first_prod = undef;
	    }
	    else
	    {
		printf( "                 " );
	    }
	    printf( "%-15.15s  \$%7.7s  %s\n", $_, GetProductRegPriceByMerchant( $_, $merchant ), GetProductLinkByMerchant( $_, $merchant ) );
	}
    }
    print( "\n" );
}


### GetProductDesc
###
### Given a valid product, returns that product's description
###
### Args:   $_[0]   = Product to operate on
###
### Return: The description string of that product
###
### Exits:  none
###
sub GetProductDesc
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    my $product = $_[0];
    return $CFG { 'products' } { $product } { 'desc' };
}


### GetProductAlertPrice
###
### Given a valid product, returns that product's alert-price
###
### Args:   $_[0]   = Product to operate on
###
### Return: The alert-price string of that product
###
### Exits:  none
###
sub GetProductAlertPrice
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    my $product = $_[0];
    return $CFG { 'products' } { $product } { 'alert_price' };
}


### GetProductLinkByMerchant
###
### Given a valid product and merchant, returns the link to that merchant's
### product listing
###
### Args:   $_[0]   = Product to operate on
###	    $_[1]   = Merchant to operate on
###
### Return: The Link to that merchant's product listing
###
### Exits:  none
###
sub GetProductLinkByMerchant
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    my $product = $_[0];
    my $merchant = $_[1];

    return $CFG { 'products' } { $product } { 'sold_by' } { $merchant } { 'prod_link' };
}


### GetProductRegPriceByMerchant
###
### Given a valid product and merchant, returns the merchant's regular price
### for that product
###
### Args:   $_[0]   = Product to operate on
###	    $_[1]   = Merchant to operate on
###
### Return: The merchant's regular price for that product
###
### Exits:  none
###
sub GetProductRegPriceByMerchant
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    my $product = $_[0];
    my $merchant = $_[1];

    return $CFG { 'products' } { $product } { 'sold_by' } { $merchant } { 'reg_price' };
}


sub GetMerchantProductList
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    my $merchant = $_[0];

    my @prod_list;

    while( my( $product, $prod_data ) = each( %{ $CFG { 'products' } } ) )
    {
	push( @prod_list, $product ) if( DoesMerchantSellProduct( $merchant, $product ) );
    }
    return @prod_list;
}


### GetMerchantBaseURL
###
### Given a valid merchant, returns that merchant's base URL
###
### Args:   $_[0]   = Merchant to operate on
###
### Return: The base URL of that merchant
###
### Exits:  none
###
sub GetMerchantBaseURL
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    my $merchant = $_[0];
    return $CFG { 'merchants' } { $merchant } { 'base_url' };
}


### GetMerchantPriceDelimStart
###
### Given a valid merchant, returns the start-delimiter for that merchant
###
### Args:   $_[0]   = Merchant to operate on
###
### Return: the start-delimiter string for that merchant
###
### Exits:  none
###
sub GetMerchantPriceDelimStart
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    my $merchant = $_[0];
    return $CFG { 'merchants' } { $merchant } { 'price_delim_start' };
}


### GetMerchantPriceDelimEnd
###
### Given a valid merchant, returns the end-delimiter for that merchant
###
### Args:   $_[0]   = Merchant to operate on
###
### Return: the end-delimiter string for that merchant
###
### Exits:  none
###
sub GetMerchantPriceDelimEnd
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    my $merchant = $_[0];
    return $CFG { 'merchants' } { $merchant } { 'price_delim_end' };
}


### DoesMerchantSellProduct
###
### Given a valid merchant and product, indicates whether or not the merchant
### sells the product.
###
### Args:   $_[0]   = Merchant to operate on
### 	    $_[1]   = Product to operate on
###
### Return: true    = Merchant sells the product
###	    false   = Merchant does not sell the product
###
### Exits:  none
###
sub DoesMerchantSellProduct
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    my $merchant = $_[0];
    my $product  = $_[1];

    return $CFG { 'products' } { $product } { 'sold_by' } { $merchant };
}


sub DoScrapes
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    my $curl = WWW::Curl::Easy->new;
    $curl->setopt( CURLOPT_HEADER, 1 );
    $curl->setopt( CURLOPT_FOLLOWLOCATION, 1 );
    while( my( $product, $prod_data ) = each( %{ $CFG { 'products' } } ) )
    {
	DebugSay( "Working on product [$product]." );
	my $prod_desc	= GetProductDesc( $product );
	my $alert_price	= GetProductAlertPrice( $product );
	while( my( $merchant, $merch_data ) = each( %{ %$prod_data { 'sold_by' } } ) )
	{
	    DebugSay( "Checking at merchant [$merchant]." );
	    my $prod_link = GetProductLinkByMerchant( $product, $merchant );
	    my $reg_price = GetProductRegPriceByMerchant( $product, $merchant );

	    my $url = GetMerchantBaseURL( $merchant ) . $prod_link;
	    $curl->setopt( CURLOPT_URL, $url );

	    my $response_body;
	    $curl->setopt( CURLOPT_WRITEDATA, \$response_body );

	    my $current_datetime = localtime();

	    printf_IfNotSilent( "Price for %-10.10s at %-15.15s: ", $product, $merchant );
	    my $retcode = $curl->perform;
	    DebugSay( "\$curl->perform returned $retcode" );
	    if( $retcode == 0 )
	    {
		my $response_code = $curl->getinfo( CURLINFO_HTTP_CODE );
		my $match_pattern = GetMerchantPriceDelimStart( $merchant ) . "([.\\d]+)" . GetMerchantPriceDelimEnd( $merchant );
		$response_body =~ m/$match_pattern/;
		if( defined $1 )
		{
		    my $current_price = $1;
		    printf_IfNotSilent( "\$%8.8s on %s", $current_price, $current_datetime );
		    
		    if( IsGoodDeal( $product, $current_price ) )
		    {
			Notify( $product, $merchant, $current_price, $current_datetime );
			printf_IfNotSilent( "  <-- GOOD DEAL (Alert Price = \$%s)", $alert_price );
		    }
		}
		else
		{
		    printf_IfNotSilent("%-9.9s", "not found" );
		}
		printf_IfNotSilent("\n" );
	    }
	    else
	    {
		say( "Scrape failed - $retcode " . $curl->strerror( $retcode ) . " " . $curl->errbuf . "\n" );
	    }
	}
    }
}


### IsGoodDeal()
###
### Determines if a given price for a product qualifies as "a good deal".  At
### present this means, if the given price is AT OR BELOW the product's
### configured regular-price.
###
### Args:   $_[0]   = Product to operate on
###	    $_[1]   = Price to evaluate
###
### Return: 0	    = Not a good deal
###	    1	    = A good deal
###
### Exits:  none
###
sub IsGoodDeal
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    my $product       = $_[0];
    my $current_price = $_[1];

    if( ( $current_price cmp GetProductAlertPrice( $product ) ) < 1 )
    {
	DebugSay( "$current_price is a good deal on $product" );
	return 1
    }
    else
    {
	DebugSay( "$current_price not a good deal on $product" );
	return 0
    }
}


### Notify()
###
### If notifications are active, then issue a notification to the configured
### recipient that the specified product, at the specified merchant, is
### currently priced at or below its alert-price.
###
### Args:   $_[0]   = Product to operate on
###	    $_[1]   = Merchant to operate on
###	    $_[2]   = Merchant's current price for the specified product
###	    $_[3]   = localtime() formated datestring of the current price
###	    
### Return: 1	    = Completed OK
###
sub Notify
{
    DebugSay( "Entered " . (caller(0))[3] . " [ @_ ]" );

    if( $CFG { 'notify' } )
    {
	my $product          = $_[0];
	my $merchant         = $_[1];
	my $current_price    = $_[2];
	my $price_datestring = $_[3];

	my $regular_price	= GetProductRegPriceByMerchant( $product, $merchant );
	my $alert_price		= GetProductAlertPrice( $product );
	my $product_desc	= GetProductDesc( $product );
	my $product_full_url	= GetMerchantBaseURL( $merchant ) . GetProductLinkByMerchant( $product, $merchant );

	### Calculate reduction %age and remove decimal component
	my $reduction = 100 * ( 1 - ( $current_price / $regular_price) );
	$reduction =~ s/\..*//;

	my $body = <<"ENDOFBODY";
'$product' ($product_desc) was found at or below your alert price of \$$alert_price.

$merchant currently lists '$product' for \$$current_price as-of $price_datestring,
which is $reduction% off their regular price of $regular_price.

$product_full_url

ENDOFBODY

	Email::Stuffer->from	    ( "salesfinder\@localhost"		    )
		      ->to	    ( $CFG { "email" }			    )
		      ->subject	    ( "SalesFinder deal ($product)"	    )
		      ->text_body   ( $body				    )
		      ->transport   ( Email::Sender::Transport::SMTP->new( {
				      host => $CFG { "mailserver" }, } )    )
		      ->send;
    }

    return 1;
}


### print_IfNotSilent()
###
### Wrapper around the standard print() routine that only emits output if
### the program is configured to not be silent.
###
### Args:   @_	= ALL parameters to be passed to print().
###
### Return: Result of the print() call, or a true value if silent
###
### Exits:  none
###
sub print_IfNotSilent
{
    my $retval='1';
    $retval = print @_ if ! $CFG{'silent'};
    return $retval;
}


### printf_IfNotSilent()
###
### Wrapper around the standard printf() routine that only emits output if
### the program is configured to not be silent.
###
### Args:   @_	= ALL parameters to be passed to printf().
###
### Return: Result of the printf() call, or a true value if silent
###
### Exits:  none
###
sub printf_IfNotSilent
{
    my $retval='1';
    $retval = printf @_ if ! $CFG{'silent'};
    return $retval;
}


### say_IfNotSilent()
###
### Wrapper around the standard say() routine that only emits output if
### the program is configured to not be silent.
###
### Args:   @_	= ALL parameters to be passed to say().
###
### Return: Result of the say() call, or a true value if silent
###
### Exits:  none
###
sub say_IfNotSilent
{
    my $retval='1';
    $retval = say @_ if ! $CFG{'silent'};
    return $retval;
}


### DebugSay()
###
### Outputs all passed parameters to stderr if debugging-output is active via
### the $CFG{'debug'} configuration setting.
###
### Args:   @_  = All parameters are to be output to stderr.
###
### Return: Result of the say() call, or a true value if silent
###
### Exits:  none
###
sub DebugSay
{
    my $retval='1';
    $retval = say STDERR @_ if $CFG{'debug'};
    return $retval;
}


### DebugDumper()
###
### Runs args through Data::Dumper and outputs the results to stderr if
### debugging-output is active via the $CFG{'debug'} configuration setting.
###
### Args:   @_  = All parameters are to be output to stderr.
###
### Return: Result of the say() call, or a true value if silent
###
### Exits:  none
###
sub DebugDumper
{
    my $retval='1';
    $retval = say STDERR Dumper @_ if $CFG{'debug'};
    return $retval;
}


### SetupConfig()
###
### Sets up the configuration that will control execution of this program.
### A reference to a config hash should be provided as the only argument, and
### may contain any defaults that are desired.  All command-line parameters are
### parsed, and integrated into the config hash overriding defaults if any
### exist.
###
### The first command-line parameter must be the 'cmd' to execute, i.e. one of:
###     compare  view  get  set
###
### The remaining command-line parameters are processed as regular short or
### long options.
###
### Args:   $_[0]   = Reference to configuration hash, possibly containing any
###                   default values that may be desired.
###
### Return: 1       = Completed OK.
###
### Exits:  Will terminate processing with pod2usage() on any error parsing
###         the command-line parameters.
###
sub SetupConfig
{
    # Reference to global Config hash - will be populated/overwritten by values
    # obtained from the config file and command-line.
    my $REALCFG = $_[0];

    # Temporary config hash - used to stage values obtained from the config
    # file and/or command-line before being copied into the global config hash.
    my %TMPCFG;

    # First argument must the the command to be performed.  If recognized then
    # save it to the temporary config hash.  Otherwise its absence will be
    # handled momentarily.
    if( @ARGV )
    {
        my $cmd = $ARGV[0];
        if(     $cmd eq "run"
            or  $cmd eq "list" )
        {
            $TMPCFG{'cmd'} = $cmd;
            shift @ARGV;
        }
        else
        {
            $TMPCFG{'cmd'} = "invalid";
        }
    }

    # Read command-line options into temporary config hash.
    GetOptions(
        'config|c=s'        => \$TMPCFG{ 'configfile' },
	'notify|n'	    => \$TMPCFG{ 'notify' },
	'email|e=s'	    => \$TMPCFG{ 'email' },
	'mailserver|m=s'    => \$TMPCFG{ 'mailserver' },
	'silent|s'	    => \$TMPCFG{ 'silent' },
        'debug|d'           => \$TMPCFG{ 'debug' },
        'help|h'            => \$TMPCFG{ 'help' },
    ) or pod2usage( "$0: Error processing options.\n" );

    # Exit with help if requested
    pod2usage( -verbose => 3 ) if $TMPCFG{'help'};

    # If config-file specified on cmd-line, then use it. Otherwise if a default
    # config-file is specified, then use it.  Only use each setting from a
    # config-file when no corresponding setting was provided on the cmd-line.
    my $cfgfilename;
    if( defined $TMPCFG{'configfile'} )                                         { $cfgfilename = $TMPCFG{'configfile'};    }
    elsif( defined  $REALCFG->{'configfile'} and -f $REALCFG->{'configfile'} )  { $cfgfilename = $REALCFG->{'configfile'}; }
    if( defined $cfgfilename )
    {
        my $json_data = do{
            open( my $CFGFILE, '<:encoding(UTF-8)', $cfgfilename )
                or die "could not open config-file '$cfgfilename' $!";
            local $/;
            <$CFGFILE>
        };

        my $hashref_decoded = decode_json $json_data;
        while( my( $key, $value ) = each( %$hashref_decoded ) )
        {
            next if defined $TMPCFG{$key};  # skip if cmd-line equivalent provided
            next if $key eq 'help';         # skip if setting requests help
            next if $key eq 'configfile';   # skip if setting redundantly specifies a config file
            $TMPCFG{$key} = $value;
        }
    }

    # Exit if command or any mandatory arguments were omitted
    pod2usage( "$0: Must specify a valid command as 1st option.\n" ) unless defined $TMPCFG{'cmd'};
    pod2usage( "$0: Must specify a valid command as 1st option.\n" ) if( $TMPCFG{'cmd'} eq "invalid" );

    # Copy any options from temporary config hash in to global config hash.
    # Skip over any zero-length options - for some reason GetOptions() appears
    # to auto-vivify all potential options whether or not they are actually
    # encountered on the command-line.
    while ( my ( $key, $value ) = each ( %TMPCFG ) )
    {
        length $value or next;
        DebugSay( "Copying \$TMPCFG\{\'$key\'\} into \$REALCFG\{\'$key\'\} - value [$value]" );
        $REALCFG->{$key} = $value;
    }

    # Exit if notifications active but invalid email configured/provided
    pod2usage( "$0: Invalid email address provided.\n" )
	if( $REALCFG->{'notify'} and $REALCFG->{'email'} !~ /@/ );

    # Exit if notifications active but invalid mailserver configured/provided
    pod2usage( "$0: Invalid mailserver provided.\n" )
	if( $REALCFG->{'notify'} and
	    ( $REALCFG->{'mailserver'} eq "" or ! defined $REALCFG->{'mailserver'} ) );

    return 1;
}


main( @ARGV );

__END__



=head1 NAME

salesfinder.pl - Scrapes webstores for preconfigured sales

=head1 SYNOPSIS

salesfinder.pl <CMD> [option...]

    where <CMD> is one of:  run, list

salesfinder.pl --help or -h for help

=head1 DESCRIPTION

SalesFinder scrapes the prices off product pages from supported websites,
and fires off notifications if prices fall below configurable threshholds.
Both program configuration and merchant/product configuration is stored in
a JSON-formatted input file, which by default is located at
'/etc/salesfinder.json'.

In the future, SalesFinder will offer a variety of notification methods.  At
present, notifications are done via email.

When running a scraper session, SalesFinder by default outputs its findings
to STDOUT.  It can optionally run silently, supporting scheduled operation
via a a scheduler such as cron.

A report can also be generated that lists various information related to all
configured merchants and products.

=head1 OPTIONS

=head2 Command

The first argument must be (only) one of the following commands to perform:

    run		Perform a full scraping run
    list	List all configured products and their price threshholds

=head2 Mandatory Arguments

    (none)

=head2 Optional Arguments

    --config=<filename>  or  -c <filename>
        Specifies a configuration file to load options from (overrides
	defaults but is overwritten by explicit command-line options).

    --notify  or  -n
        Send notifications to the configured recipient.
	NOTE: if --notify is off but --silent is on, then there will be no
	      way to determine the execution outcome.

    --email=<recipient@example.com>  or  -e <recipient@example.com>
        Specify the email address of the recipient to be sent notifications.

    --mailserver=<mail@example.com> or -m <mail@example.com>
	Specify the SMTP mail server to use.

    --silent  or  -s
	Generate no output to STDOUT (only valid for command 'run').
	Notifications will still be sent if configured to be active.
	NOTE: if --silent is on but --notify is off, then there will be no
	      way to determine the execution outcome.

    --debug  or  -x
        Enable debugging output to standard-error.

    --help  or  -h
        Displays the help page for this script.

=head2 Configuration File

SalesFinder can load some or all of its settings from a JSON-encoded
configuration file, which by-default resides at '/etc/salesfinder.json'.
At a minimum, product and merchant definitions must be present in the
configuration file, since they cannot be specified on the command-line.

Everything listed under 'Optional Arguments' except '--help' may be
specified in this configuration file, using their long-form argument names
(e.g. 'email' refers to the --email=<recipient@example.com> argument).

=head1 WARNINGS

Required perl modules:

	JSON::MaybeXS	    (JSON wrapper with multiple fallbacks)
	Cpanel::JSON::XS    (Correct & fast JSON encoding/decoding)
	GetOpt::Long	    (Extended processing of command-line options)
	Email::Stuffer	    (Casual module for sending simple emails)
	WWW::Curl	    (Perl interface to libcurl)

=cut

# vim: autoindent tabstop=8 softtabstop=4 shiftwidth=4 noexpandtab
