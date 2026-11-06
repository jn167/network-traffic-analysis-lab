##! Lab additions appended to /opt/zeek/share/zeek/site/local.zeek
##! by scripts/sensor/configure-zeek.sh

# VirtualBox NICs hand packets up with checksum offloading, so many captured
# packets carry "bad" checksums. Without this Zeek silently drops them and
# logs look half empty.
redef ignore_checksums = T;

# Add a community_id field to conn.log. Suricata writes the same hash into
# eve.json, so one value pivots between a Suricata alert and the Zeek logs.
@load policy/protocols/conn/community-id-logging

# Log the MAC addresses seen on each connection (useful in the public PCAP exercise).
@load policy/protocols/conn/mac-logging
