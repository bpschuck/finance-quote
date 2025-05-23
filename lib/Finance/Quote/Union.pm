#!/usr/bin/perl -w
#
#    Copyright (C) 1998, Dj Padzensky <djpadz@padz.net>
#    Copyright (C) 1998, 1999 Linas Vepstas <linas@linas.org>
#    Copyright (C) 2000, Yannick LE NY <y-le-ny@ifrance.com>
#    Copyright (C) 2000, Paul Fenwick <pjf@cpan.org>
#    Copyright (C) 2000, Brent Neal <brentn@users.sourceforge.net>
#    Copyright (C) 2000, Volker Stuerzl <volker.stuerzl@gmx.de>
#    Copyright (C) 2002, Rainer Dorsch <rainer.dorsch@informatik.uni-stuttgart.de>
#    Copyright (C) 2022, Andre Joost <andrejoost@gmx.de>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301, USA
#
#
# This code derived from Padzensky's work on package Finance::YahooQuote,
# but extends its capabilites to encompas a greater number of data sources.
#
# This code was developed as part of GnuCash <http://www.gnucash.org/>
#
# $Id: Union.pm,v 1.3 2005/03/20 01:44:13 hampton Exp $

package Finance::Quote::Union;

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use POSIX qw(strftime);

# VERSION

our $UNION_URL1 = "https://legacy-apps.union-investment.de/handle?generate=true&action=doDownloadSearch&start_time=";
# Date format 27.07.2022&end_time=01.08.2022
our $UNION_URL2 ="&csvformat=us&choose_indi_fondsnames=";

our $DISPLAY    = 'Union - German Funds';
our @LABELS     = qw/exchange name date isodate price method currency/;
our $METHODHASH = {subroutine => \&unionfunds, 
                   display => $DISPLAY, 
                   labels => \@LABELS};

sub methodinfo {
    return ( 
        unionfunds => $METHODHASH,
    );
}

sub labels { my %m = methodinfo(); return map {$_ => [@{$m{$_}{labels}}] } keys %m; }

sub methods {
  my %m = methodinfo(); return map {$_ => $m{$_}{subroutine} } keys %m;
}

# =======================================================================
# The unionfunds routine gets quotes of UNION funds (Union Invest)
# On their website UNION provides a csv file in the format
#    label1,label2,...
#    name1,symbol1,buy1,bid1,...
#    name2,symbol2,buy2,bid2,...
#    ...
#
# This subroutine was written by Volker Stuerzl <volker.stuerzl@gmx.de>

sub unionfunds
{
  my $quoter = shift;
  my @funds = @_;
  return unless @funds;
  my $ua = $quoter->user_agent;
  my (%fundhash, @q, %info, $tempdate);

  # create hash of all funds requested
  foreach my $fund (@funds)
  {
    $fundhash{$fund} = 0;
	    my $endtime = POSIX::strftime ("%d.%m.%Y" , localtime());
		my $epoc = time();
        $epoc = $epoc - 7 * 24 * 60 * 60;   # one week before of current date.
		my $starttime = POSIX::strftime ("%d.%m.%Y" , localtime($epoc));
		my $url = $UNION_URL1 . $starttime."&end_time=" . $endtime . $UNION_URL2 . $fund;

  # Website not supplying intermediate certificate causing
  # GET to fail
  $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
		
  # get csv data
  my $response = $ua->request(GET $url);
  if ($response->is_success)
  {
    # process csv data
    foreach (split('\015?\012',$response->content))
    {

      @q = split(/,/) or next;
      next unless (defined $q[1]);
      if (exists $fundhash{$q[1]})
      {
        $fundhash{$q[1]} = 1;


        $info{$q[1], "exchange"} = "UNION";
        $info{$q[1], "name"}     = $q[0];
        $info{$q[1], "symbol"}   = $q[1];
        $info{$q[1], "price"}    = $q[4];
        $info{$q[1], "last"}     = $q[4];
	$quoter->store_date(\%info, $q[1], {eurodate => $q[6]});
        $info{$q[1], "method"}   = "unionfunds";
        $info{$q[1], "currency"} = $q[2];
        $info{$q[1], "success"}  = 1;
      }
    }
  }
  }
    # check to make sure a value was returned for every fund requested
    foreach my $fund (keys %fundhash)
    {
      if ($fundhash{$fund} == 0)
      {
        $info{$fund, "success"}  = 0;
        $info{$fund, "errormsg"} = "No data returned";
      }
	}

  return wantarray() ? %info : \%info;

}

1;

# UNION provides a csv file named historische-preise.csv on
# <https://www.union-investment.de/fonds_depot/fonds-finden/preise-berechnen#HistorischeTagespreise>
# containing the prices of a selction of all their funds for a selected period.


__END__

=head1 NAME

Finance::Quote::Union	- Obtain quotes from UNION (Union Investment).

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %stockinfo = $q->fetch("unionfunds","DE0008491002");

=head1 DESCRIPTION

This module obtains information about UNION managed funds.

Information returned by this module is governed by UNION's terms
and conditions.

Note that previous versions of the module required the WKN,
now the ISIN is needed as symbol value.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::UNION:
exchange, name, date, price, last.

=head1 SEE ALSO

UNION (Union Investment), https://www.union-investment.de/

=cut
