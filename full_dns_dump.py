import dns.resolver
import dns.exception

# === Full list of DNS record types (modern + deprecated) ===
ALL_DNS_TYPES = [
    "A", "AAAA", "AFSDB", "APL", "CAA", "CDNSKEY", "CDS", "CERT", "CNAME",
    "DHCID", "DLV", "DNAME", "DNSKEY", "DS", "HIP", "IPSECKEY", "KEY", "KX",
    "LOC", "MX", "NAPTR", "NS", "NSEC", "NSEC3", "NSEC3PARAM", "PTR",
    "RRSIG", "RP", "SIG", "SMIMEA", "SOA", "SPF", "SRV", "SSHFP", "SVCB",
    "TA", "TKEY", "TLSA", "TSIG", "TXT", "URI", "MB", "MG", "MR", "MINFO",
    "WKS", "HINFO", "X25", "ISDN", "NSAP", "PX", "RT", "NULL"
]

# === Get user input ===
domain = input("Enter the domain to query: ").strip()
dns_server = input("Enter DNS server (default: 1.1.1.1): ").strip() or "1.1.1.1"

# === Output file ===
output_file = "full_dns_dump.out"

# === Create a resolver and set the DNS server ===
resolver = dns.resolver.Resolver()
resolver.nameservers = [dns_server]

# === Open output file and start querying ===
with open(output_file, "w") as f:
    for record_type in ALL_DNS_TYPES:
        header = f"\n=== {record_type} Records ==="
        print(header)
        f.write(header + "\n")
        try:
            answers = resolver.resolve(domain, record_type, lifetime=5)
            for rdata in answers:
                result_line = rdata.to_text()
                print(result_line)
                f.write(result_line + "\n")
        except (dns.resolver.NoAnswer, dns.resolver.NXDOMAIN,
                dns.resolver.NoNameservers, dns.resolver.Timeout,
                dns.exception.DNSException) as e:
            error_line = f"[!] {record_type} lookup failed: {str(e)}"
            print(error_line)
            f.write(error_line + "\n")
