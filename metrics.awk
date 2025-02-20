#!/usr/bin/awk -f
# metrics.awk
#
# Usage:
#   awk -v scenario=reno -f metrics.awk results/reno/trace-reno.tr
#   awk -v scenario=vegas -f metrics.awk results/vegas/trace-vegas.tr
#   awk -v scenario=mixed -f metrics.awk results/mixed/trace-mixed.tr
#
# This script generates three files in graphs/:
#   throughput-<scenario>.dat
#   latency-<scenario>.dat
#   loss-<scenario>.dat
#
# Metrics are computed per interval (default = 1 second).

BEGIN {
    # Interval in seconds for computing metrics.
    interval = 1.0
    next_interval = interval

    # Default scenario name if not provided.
    if (scenario == "") {
        scenario = "default"
    }

    # Output file paths.
    throughput_file = "graphs/throughput-" scenario ".dat"
    latency_file    = "graphs/latency-" scenario ".dat"
    loss_file       = "graphs/loss-" scenario ".dat"

    # Remove old files to start fresh.
    system("rm -f " throughput_file)
    system("rm -f " latency_file)
    system("rm -f " loss_file)

    # Initialize cumulative variables for the current interval.
    total_bytes = 0
    total_delay = 0
    count_delay = 0
    sent_packets = 0
    received_packets = 0

    # Array to store send times by packet ID.
}

{
    # Field breakdown:
    # $1 = event type ('s' for send, 'r' for receive, etc.)
    # $2 = event time (seconds)
    # $6 = packet size (bytes)
    # $12 = unique packet ID

    t = $2 + 0  # Current event time as a number

    if ($1 == "s") {
        # Process send events.
        sent_packets++
        send_time[$12] = t
    }
    else if ($1 == "r") {
        # Process receive events.
        received_packets++
        pkt_size = $6 + 0
        total_bytes += pkt_size

        # If we have a recorded send time, compute delay.
        if (($12) in send_time) {
            delay = t - send_time[$12]
            total_delay += delay
            count_delay++
            delete send_time[$12]  # Free memory.
        }
    }

    # Check if we've reached or passed the next interval boundary.
    while (t >= next_interval) {
        throughput = (total_bytes * 8) / interval   # bits per second.
        avg_delay  = (count_delay > 0) ? (total_delay / count_delay) : 0
        loss_rate  = (sent_packets > 0) ? (100.0 * (sent_packets - received_packets) / sent_packets) : 0
        if (loss_rate < 0) loss_rate = 0

        printf "%.2f %.2f\n", next_interval, throughput >> throughput_file
        printf "%.2f %.4f\n", next_interval, avg_delay    >> latency_file
        printf "%.2f %.2f\n", next_interval, loss_rate    >> loss_file

        # Reset counters for the next interval.
        total_bytes = 0
        total_delay = 0
        count_delay = 0
        sent_packets = 0
        received_packets = 0

        next_interval += interval
    }
    # Keep track of the last event time.
    last_event_time = t
}

END {
    # Compute metrics for the final (possibly partial) interval.
    throughput = (total_bytes * 8) / interval
    avg_delay  = (count_delay > 0) ? (total_delay / count_delay) : 0
    loss_rate  = (sent_packets > 0) ? (100.0 * (sent_packets - received_packets) / sent_packets) : 0
    if (loss_rate < 0) loss_rate = 0

    # Label final interval with the later of the next interval or the last event time.
    final_time = (last_event_time > next_interval) ? last_event_time : next_interval

    printf "%.2f %.2f\n", final_time, throughput >> throughput_file
    printf "%.2f %.4f\n", final_time, avg_delay  >> latency_file
    printf "%.2f %.2f\n", final_time, loss_rate  >> loss_file
}

