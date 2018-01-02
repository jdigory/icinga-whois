#!/bin/bash

# This reads a list of domains, which we have to create manually.
# Or can read from stdin
# See the Ansible playbook, "apache_domain_expiry.yml"

whois=https://www.whoisxmlapi.com/whoisserver/WhoisService
key=

while read d || [[ -n $d ]]; do
    curl -s "$whois?apiKey=$key&domainName=$d&outputFormat=JSON" > /var/whois_cache/$d.json 
done < "${1:-/dev/stdin}"
