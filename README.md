# SalesFinder

SalesFinder is a Perl script that allows you to take a set of products you are interested in, and check the websites of supported merchants for their current prices.  You can set alert prices for each product, as well as regular prices on a per-product/per-merchant basis.  When any of the listings drops down to (or below) that product's alert price, SalesFinder can send you notifications
(currently via email).

Everything is data-driven via a JSON-encoded configuration file.  A small utility is included that can take a perl nested data structure and output JSON, which can then be redirected (or copy-and-pasted) into a config file.

SalesFinder can run silently (suitable for automatic scheduling via cron or equivalent), or produce output suitable for manual command-line invocations.

## Prerequisites

The main prerequisites are a perl-enabled environment that the script can run in. In addition, the following perl-modules need to be installed:

* [Cpanel::JSON::XS](https://metacpan.org/pod/Cpanel::JSON::XS) - Correct & fast JSON encoding/decoding
* [DBI](https://metacpan.org/pod/DBI) - Database independent interface for Perl
* [Email::Stuffer](https://metacpan.org/pod/Email::Stuffer)- (Casual module for sending simple emails)
* [File::Basename](https://perldoc.perl.org/File/Basename.html)] - Parse file paths into directory, filename and suffix
* [File::Path](https://perldoc.perl.org/File/Path.html) - Create or remove directory trees
* [GetOpt::Long](https://perldoc.perl.org/Getopt/Long.html) - Extended processing of command-line options
* [JSON::MaybeXS](https://metacpan.org/pod/JSON::MaybeXS) - JSON wrapper with multiple fallbacks
* [WWW::Curl](https://metacpan.org/pod/WWW::Curl) - (Perl interface to libcurl)

In turn, WWW::Curl requires the presence of ```libcurl``` on your machine, which is probably already the case if you have the ```curl``` tool installed.

## Installation

### Installing SalesFinder
(**Note**: *These instructions are for Linux, MacOS or BSD based systems, and will require a bit of adaption for use on* Windows *systems.*) 

1. Grab the [latest release from GitHub](https://github.com/jnikolich/salesfinder/releases), save it on the machine you will be running SalesFinder on, and extract the release file.

2. Take the ```salesfinder.pl``` file and move it to wherever on your filesystem you want it to be run from.  To make it reachable without specifying a full path, put it within your **```$PATH```** (on Linux/Mac systems) or **```%PATH%```** (Windows systems).  For example:
```bash
   mv ./salesfinder.pl /usr/local/bin/salesfinder.pl
```
3. If you want to start with an example JSON configuration in the default location, then take the ```salesfinder.json``` file and move it to **```/etc/salesfinder.json```** directory.
```bash
   mv ./salesfinder.json /etc/salesfinderjson
```
### Installing Perl Modules
Use your system's particular package manager to install the perl modules listed above in **"Prerequisites"**.  For example, on a modern Fedora system:
```bash
sudo dnf install \
perl-Cpanel-JSON-XS \
perl-DBI \
perl-DBD-sqlite\
perl-Email-Stuffer \
perl-JSON-MaybeXS \
perl-WWW-Curl \
perl-Getopt-Long
```
### Installing libcurl
Your system might already have libcurl installed.  If not then install it with your system's package manager.  For example, on Fedora:
```bash
sudo dnf install libcurl
```
## Configuration
Once you have finished installing SalesFinder, it is time to set up all the configuration that will drive its operation, through the following steps:
1. Configure all the merchants you want to monitor, including the base URL for their online store.
2. Configure all the products you are interested in, including a name, description, and alert-price (more on this later).
3. Configure all the listings you want to.  Listings represent which merchant(s) have each product you're interested in, their regular price for that product, and the product link.  In other words, *"who sells what"*.  

There are two ways to accomplish this.  
  - You can edit a JSON configuration file by hand.  If you choose this approach, it is recommended to take the ```salesfinder.json``` sample file included in the release as a starting-point.
  - (Recommended) You can edit  the  perl script ```cfggenerator.pl``` to contain your desired configuration, and then run the script to output  the actual JSON configuration to STDOUT (which can then be redirected into a JSON file.  This has the benefit of leveraging Perl's built-in syntax checker (JSON, while human-readable, can be finicky to edit without errors).
Once your JSON configuration is finished, save it and place it in a directory that is accessible by whatever user will be running SalesFinder.

(***Note**: By-default SalesFinder will look for its configuration at ```/etc/salesfinder.json``` unless otherwise specified on the command line.*)

## Operation

### Synopsis

SalesFinder works by visitng various product listings you're interested in, at merchants you would like to purchase from.  For every listing you configure, It then finds the current price from that listing (using start and end delimiters), and (unless running silently) reports on it.

When SalesFinder finds that a merchant's price for a given product has dropped down to (or below) the **alert-price** you've set for that product, SalesFinder will notify you, telling  you the product, it's price, which merchant(s) have it for that price, and the date/time the price was retrieved.  Notifications are currently via email; additional methods are envisioned down the road.

SalesFinder will also log all discovered current prices for each product at each merchant into a sqlite3 database, for later use.  This happens whether or not notifications are active.  The database location is configurable, and by default is: ```~/.salesfinder/salesfinder.db```.

When you invoke SalesFinder, it takes as its first command-line argument a command, followed by various optional arguments.  At present the command may be **list** or **run**.

### Modes of Operation
SalesFinder has a couple of modes of operation, which you specify as its first argument when invoking it.  At present these modes are **'list'** and **'run'**.

#### SalesFinder 'list' Mode
This command doesn't check any prices, but instead causes SalesFinder to output a report broken down into 3 sections:  1) All configured products you're interested in, 2) the merchant(s) you're looking at, and  3) who sells what.  The example below shows SalesFinder listing the default configuration, with 3 merchants, 2 products, and a total of 5 listings collectively:
```bash
[dev@localhost:~] $ salesfinder.pl list

Merchant         Price Start Delimiter      Price End Delimiter        Base URL
---------------  -------------------------  -------------------------  ------------------------
NewEgg           product_sale_price:\['     '\]                        https://www.newegg.ca/p/
BestBuy          priceWithoutEhf\":         \,                         https://www.bestbuy.ca/en-ca/product/
CanadaComputers  newtotal -=                                           https://www.canadacomputers.com/product_info.php?


Product          Description                               Alert @
---------------  ----------------------------------------  --------
ex2780q          Benq EX2780Q 1440p 27-inch IPS monitor    $ 499.99
c27hg70          Samsung CHG70 Series 1440p 27-inch VA mo  $ 499.99


Merchant         Product          Regular   Product Link
---------------  ---------------  --------  ------------
NewEgg           ex2780q          $ 799.99  N82E16824014661
                 c27hg70          $ 730.33  N82E16824022583
BestBuy          ex2780q          $ 599.99  benq-27-1440p-wqhd-144hz-5ms-gtg-ips-lcd-freesync-gaming-monitor-ex2780q-black/13893428
CanadaComputers  ex2780q          $ 599.99  cPath=22_700_1104&item_id=140272
                 c27hg70          $ 749.99  cPath=22_700_1104&item_id=112035

[dev@devhost:~] $
```

#### SalesFinder 'run' Mode
This command performs the actual price-checks, and notify and/or display any listings for products that are at or lower than the alert price you've specified for that product.

By default, results are output to STDOUT, however this can be silenced with the ```--silent``` option.  Email notifications are off by-default, but can be enabled with the ```--notify``` option.  The mailserver to use as well as the recipient to send notifications to can be configured via the ```--mailserver``` and ```--email``` options respectively.  All of these options can also be placed in SalesFinder's JSON configuration file to make invocations simpler.

The following are examples of what SalesFinder will output to STDOUT and include in an email notification:
```bash
[dev@devhost:~] $ salesfinder.pl run --notify --email=test@example.com --mailserver=mail.example.com
Price for ex2780q    at NewEgg         : $  599.99 on Wed Jan 29 00:05:14 2020  <-- GOOD DEAL (Alert Price = $600.99)
Price for ex2780q    at CanadaComputers: $  799.99 on Wed Jan 29 00:05:14 2020
Price for ex2780q    at BestBuy        : $  599.99 on Wed Jan 29 00:05:15 2020  <-- GOOD DEAL (Alert Price = $600.99)
Price for c27hg70    at NewEgg         : $  734.34 on Wed Jan 29 00:05:15 2020
Price for c27hg70    at CanadaComputers: $  649.99 on Wed Jan 29 00:05:16 2020
[dev@localhost:~] $
```
*(screen output)*

```
'ex2780q' (Benq EX2780Q 1440p 27-inch IPS monitor) was found at or below your alert price of $600.99.

BestBuy currently lists 'ex2780q' for $599.99 as-of Wed Jan 29 00:05:15 2020, which is 0% off their regular price of 599.99.

https://www.bestbuy.ca/en-ca/product/benq-27-1440p-wqhd-144hz-5ms-gtg-ips-lcd-freesync-gaming-monitor-ex2780q-black/13893428

```
*(email content)*

### Command-Line Arguments / Options

Run **```salesfinder.pl --help```** for some help and a complete list of command-line arguments/options.

## Authors

* **James Nikolich** [(GitHub profile)](https://github.com/jnikolich/)

## License

This project is licensed under GPL 3.0.  See the LICENSE file for details.

## Disclaimer of Warranty
THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

## Limitation of Liability
IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
