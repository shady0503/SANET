#!/usr/bin/awk -f
# metrics.awk
#
# Usage :
#   awk -v scenario=reno -f metrics.awk results/reno/trace-reno.tr
#   awk -v scenario=vegas -f metrics.awk results/vegas/trace-vegas.tr
#   awk -v scenario=mixed -f metrics.awk results/mixed/trace-mixed.tr
#
# Generates 3 files in graphs/ :
#   throughput-<scenario>.dat
#   latency-<scenario>.dat
#   loss-<scenario>.dat
#

BEGIN {
    # Interval in seconds for computing metrics.
    interval = 1.0
    next_interval = interval

    # Default scenario name if none provided.
    if (scenario == "") {
        scenario = "default"
    }

    # Output paths (unchanged).
    throughput_file = "graphs/throughput-" scenario ".dat"
    latency_file    = "graphs/latency-" scenario ".dat"
    loss_file       = "graphs/loss-" scenario ".dat"

    # Remove old files so we start fresh.
    system("rm -f " throughput_file)
    system("rm -f " latency_file)
    system("rm -f " loss_file)

    # Cumulative variables.
    total_bytes = 0
    total_delay = 0
    count_delay = 0
    sent_packets = 0
    received_packets = 0

    # Array to store send times by packet ID.
    # Key = packet ID (column 12), Value = send time (column 2).
}

{
    # $1 = event (s, r, etc.)
    # $2 = current event time
    # $6 = packet size (bytes)
    # $12 = unique packet ID
    # We store the send time for each packet ID on send,
    # then retrieve it on receive to compute delay.

    t = $2 + 0  # current event time

    if ($1 == "s") {
        # Count a sent packet
        sent_packets++

        # Store the send time in an array, keyed by packet ID.
        send_time[$12] = t

    } else if ($1 == "r") {
        # Count a received packet
        received_packets++

        # Packet size is in column 6
        pkt_size = $6 + 0
        total_bytes += pkt_size

        # If we have a recorded send time, compute latency
        if (($12 in send_time)) {
            delay = t - send_time[$12]
            total_delay += delay
            count_delay++
            delete send_time[$12]  # free memory
        }
    }

    # Check if we've crossed the next interval boundary
    while (t > next_interval) {
        throughput = (total_bytes * 8) / interval  # bits/sec
        avg_delay  = (count_delay > 0) ? (total_delay / count_delay) : 0
        loss_rate  = (sent_packets > 0) \
                     ? (100.0 * (sent_packets - received_packets) / sent_packets) \
                     : 0

        # Prevent negative loss rate if counters got reset weirdly
        if (loss_rate < 0) loss_rate = 0

        # Write metrics to output files
        printf "%.2f %.2f\n", next_interval, throughput >> throughput_file
        printf "%.2f %.4f\n", next_interval, avg_delay    >> latency_file
        printf "%.2f %.2f\n", next_interval, loss_rate    >> loss_file

        # Reset counters for the next interval
        total_bytes = 0
        total_delay = 0
        count_delay = 0
        sent_packets = 0
        received_packets = 0

        next_interval += interval
    }
}

END {
    # Compute metrics for the final (possibly partial) interval
    throughput = (total_bytes * 8) / interval
    avg_delay  = (count_delay > 0) ? (total_delay / count_delay) : 0
    loss_rate  = (sent_packets > 0) \
                 ? (100.0 * (sent_packets - received_packets) / sent_packets) \
                 : 0

    if (loss_rate < 0) loss_rate = 0

    printf "%.2f %.2f\n", next_interval, throughput >> throughput_file
    printf "%.2f %.4f\n", next_interval, avg_delay  >> latency_file
    printf "%.2f %.2f\n", next_interval, loss_rate  >> loss_file
}

