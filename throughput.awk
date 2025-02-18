#!/usr/bin/awk -f
# throughput.awk
# This script reads an NS-2 trace file and calculates throughput (bps)
# over 1-second intervals.
# Adjust the field numbers if your trace format is different.

BEGIN {
    interval = 1.0         # Time interval (in seconds) over which throughput is computed
    next_interval = interval;
    total_bytes = 0;
}

# Process only receive events (line beginning with "r")
$1 == "r" {
    t = $2 + 0;            # Simulation time (convert to number)
    pkt_size = $6 + 0;     # Packet size in bytes (convert to number)

    # If current time exceeds the current interval, output throughput for that interval
    while (t > next_interval) {
        throughput = (total_bytes * 8) / interval;  # bits per second
        printf "%.2f %.2f\n", next_interval, throughput;
        total_bytes = 0;
        next_interval += interval;
    }
    total_bytes += pkt_size;
}

END {
    throughput = (total_bytes * 8) / interval;
    printf "%.2f %.2f\n", next_interval, throughput;
}

