#!/usr/local/bin/perl -w

# check_whois2
#
# plugin to check the expiration date of a domain, from local cache.
#
# define host {
#   use dns-zone
#   host_name example.com
# }

use strict;
use warnings;

use Getopt::Std;
use JSON;
use Date::Manip;
use POSIX qw(strftime);

my %opts;
getopts('d', \%opts);

my $name  = shift or die usage();
my $json  = JSON->new;
my $cache = '/var/whois_cache';
my $cache_prog = '/usr/local/bin/whois_cache.sh';
my $orig_prog  = '/usr/lib64/nagios/plugins/check_whois.pl';

# use old lookup if we don't have this zone cached yet
! -s "$cache/$name.json" and original($name);

grok($name);
exit 0;

sub grok {
    my $name = shift || die;
print STDERR "checking $name\n" if $opts{d};

    open (my $in, '<', "$cache/$name.json")
        or unknown("cannot open $cache file: $!");
    my $data;
    $data .= $_ while <$in>;
    close $in;

    my $whois;
    eval { $whois = $json->decode($data) };
    $@ and unknown("JSON decode failed: $@");

    ref $whois->{WhoisRecord}
        and my $reg = $whois->{WhoisRecord}{registryData};
    ! ref $reg and original($name);

    my $expires = $reg->{expiresDateNormalized}
        or warning('No expiry - invalid domain?');
    my $registrar = $reg->{registrarName} || 'UNKNOWN';
    ($expires, undef) = split ' ', $expires;
print STDERR "Expires = $expires\n" if $opts{d};

    my $t;

    if ($expires) {
        $t = UnixDate($expires, "%s");
        critical("Invalid expiration time '$expires'") unless defined $t;
        critical("Invalid expiration time '$expires'") if ($t < 0);
        $expires = strftime("%Y-%m-%d", localtime($t));
    }
    else {
        critical("Didn't find expiration timestamp");
    }

    critical("Expires $expires at $registrar", $name) if ($t - time < (86400*7));   # < 1 week
    warning ("Expires $expires at $registrar", $name) if ($t - time < (86400*28));  # < 4 weeks
    success ("Expires $expires at $registrar");
}

sub success {
    output('OK', shift);
    exit(0);
}

sub warning {
    output('WARNING', shift);
    exit(1);
}

sub critical {
    my ($msg, $name) = @_;
    (`find $cache/$name.json -mtime +2`) and exec "$cache_prog <<< $name";  # re-cache if file older than 2 days
    # run original instead; having issues with valid GoDaddy data
    original($name);
    output('CRITICAL', $msg);
    exit(2);
}       

sub unknown {
    output('UNKNOWN', shift);
    exit(3);
}

sub output {
    my ($state, $msg) = @_;
    printf "WHOIS %s: %s\n", $state, $msg;
}       

sub original {
    my $name = shift;
print STDERR "Using original script\n" if $opts{d};
    open(my $out, "$orig_prog $name|")
        or unknown("failed to create process for $orig_prog: $!");
    print while <$out>;
    close $out;
    exit $? >> 8;
}

sub usage {
    "usage: $0 [-d] domain\n".
    "\t-d\tDebugging\n";
}
