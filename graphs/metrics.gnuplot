# metrics.gnuplot
reset

#-----------------------------
# 1) Throughput Comparison
#-----------------------------
set terminal png size 800,600
set output 'graphs/throughput_comparison.png'
set title "Throughput Comparison: Reno vs. Vegas vs. Mixed"
set xlabel "Time (s)"
set ylabel "Throughput (bps)"
set grid
set key left top
plot "graphs/throughput-reno.dat"   with lines lw 2 title "Reno", \
     "graphs/throughput-vegas.dat"  with lines lw 2 title "Vegas", \
     "graphs/throughput-mixed.dat"  with lines lw 2 title "Mixed"

#-----------------------------
# 2) Latency Comparison
#-----------------------------
reset
set terminal png size 800,600
set output 'graphs/latency_comparison.png'
set title "Latency Comparison: Reno vs. Vegas vs. Mixed"
set xlabel "Time (s)"
set ylabel "Latency (s)"
set grid
set key left top
plot "graphs/latency-reno.dat"   with lines lw 2 title "Reno", \
     "graphs/latency-vegas.dat"  with lines lw 2 title "Vegas", \
     "graphs/latency-mixed.dat"  with lines lw 2 title "Mixed"

#-----------------------------
# 3) Packet Loss Comparison
#-----------------------------
reset
set terminal png size 800,600
set output 'graphs/loss_comparison.png'
set title "Packet Loss Rate Comparison: Reno vs. Vegas vs. Mixed"
set xlabel "Time (s)"
set ylabel "Loss Rate (%)"
set grid
set key left top
plot "graphs/loss-reno.dat"   with lines lw 2 title "Reno", \
     "graphs/loss-vegas.dat"  with lines lw 2 title "Vegas", \
     "graphs/loss-mixed.dat"  with lines lw 2 title "Mixed"

