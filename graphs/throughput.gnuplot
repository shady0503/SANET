# throughput.gnuplot
set terminal png size 800,600
set output 'throughput_comparison.png'
set title "Throughput Comparison: TCP Reno vs. TCP Vegas vs. Mixed"
set xlabel "Time (s)"
set ylabel "Throughput (bps)"
set grid
set key left top

plot "throughput-reno.dat" with lines lw 2 title "TCP Reno", \
     "throughput-vegas.dat" with lines lw 2 title "TCP Vegas", \
     "throughput-mixed.dat" with lines lw 2 title "Mixed (Reno/Vegas)"

