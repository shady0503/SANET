#!/usr/bin/env ns
#----------------------------------------------------------------------
# SANET Architecture Simulation with Enhanced Monitoring and
# Scheduled NAM Node Labeling
#----------------------------------------------------------------------
#
# This simulation deploys a SANET architecture with:
#   • 2 Sources, 3 Gateways, 2 Destinations (7 nodes)
#   • FTP applications (FTP1 and FTP2) between the sources and destinations
#
# Three simulation scenarios are supported:
#   1. "reno"  – both FTP flows use TCP/Reno
#   2. "vegas" – both FTP flows use TCP/Vegas
#   3. "mixed" – FTP1 uses TCP/Reno and FTP2 uses TCP/Vegas
#
# The functionality (monitoring, packet counting, termination, etc.)
# is taken from the first code, while the node positioning and NAM
# labeling is taken from the second code.
#
# Usage: ns sim-sanets.tcl <scenario>
# where <scenario> is one of: reno, vegas, or mixed.
#----------------------------------------------------------------------

if {[llength $argv] < 1} {
    puts "Usage: ns sim-sanets.tcl <scenario>"
    puts "  <scenario>: reno, vegas, or mixed"
    exit 1
}
set simType [lindex $argv 0]

# Choose TCP agent types based on the simulation scenario
if {$simType == "reno"} {
    set tcpType1 "Reno"
    set tcpType2 "Reno"
} elseif {$simType == "vegas"} {
    set tcpType1 "Vegas"
    set tcpType2 "Vegas"
} elseif {$simType == "mixed"} {
    set tcpType1 "Reno"
    set tcpType2 "Vegas"
} else {
    puts "Invalid scenario: $simType. Valid options: reno, vegas, mixed."
    exit 1
}

#--------------------------
# Simulation Parameters
#--------------------------
set val(chan)           Channel/WirelessChannel    
set val(prop)           Propagation/TwoRayGround   
set val(netif)          Phy/WirelessPhy            
set val(mac)            Mac/802_11                 
set val(ifq)            Queue/DropTail/PriQueue    
set val(ll)             LL                          
set val(ant)            Antenna/OmniAntenna        
set val(ifqlen)         50                          
set val(nn)             7                           
set val(rp)             DSDV                        
set val(x)              600
set val(y)              400
set val(stop)           100.0                      ;# Extended simulation time
set val(packet_size)    1000                       ;# Packet size in bytes

#--------------------------
# Set Up Simulator & Tracing
#--------------------------
set ns_   [new Simulator]
$ns_ color 2 Red
$ns_ color 1 Blue

set tracefileName "results/$simType/trace-$simType.tr"
set namfileName   "results/$simType/nam-$simType.nam"

set tracefd   [open $tracefileName w]
$ns_ trace-all $tracefd

set namtrace [open $namfileName w]
$ns_ namtrace-all-wireless $namtrace $val(x) $val(y)

# Enable packet tracing for NAM
$ns_ namtrace-all-wireless $namtrace $val(x) $val(y)

#--------------------------
# Topography & God
#--------------------------
set topo   [new Topography]
$topo load_flatgrid $val(x) $val(y)
create-god $val(nn)

set chan_1_ [new $val(chan)]

$ns_ node-config -adhocRouting $val(rp) \
    -llType $val(ll) \
    -macType $val(mac) \
    -ifqType $val(ifq) \
    -ifqLen $val(ifqlen) \
    -antType $val(ant) \
    -propType $val(prop) \
    -phyType $val(netif) \
    -topoInstance $topo \
    -agentTrace ON \
    -routerTrace ON \
    -macTrace ON \
    -movementTrace OFF \
    -channel $chan_1_

#--------------------------
# Node Creation & Positioning
#--------------------------
for {set i 0} {$i < $val(nn)} {incr i} {
    set node_($i) [$ns_ node]
    $node_($i) random-motion 0
    $ns_ initial_node_pos $node_($i) 20
}

# Set node positions
$node_(0) set X_ 100.0  ;# Source S1
$node_(0) set Y_ 300.0
$node_(0) set Z_ 0.0

$node_(1) set X_ 100.0  ;# Source S2
$node_(1) set Y_ 100.0
$node_(1) set Z_ 0.0

$node_(2) set X_ 300.0  ;# Gateway G1
$node_(2) set Y_ 300.0
$node_(2) set Z_ 0.0

$node_(3) set X_ 500.0  ;# Destination D1
$node_(3) set Y_ 300.0
$node_(3) set Z_ 0.0

$node_(4) set X_ 300.0  ;# Gateway G3
$node_(4) set Y_ 200.0
$node_(4) set Z_ 0.0

$node_(5) set X_ 300.0  ;# Gateway G2
$node_(5) set Y_ 100.0
$node_(5) set Z_ 0.0

$node_(6) set X_ 500.0  ;# Destination D2
$node_(6) set Y_ 100.0
$node_(6) set Z_ 0.0

# Fix node positions at time 0.
for {set i 0} {$i < $val(nn)} {incr i} {
    set xpos [$node_($i) set X_]
    set ypos [$node_($i) set Y_]
    $ns_ at 0.0 "$node_($i) setdest $xpos $ypos 0.0"
}

# Schedule Node Labeling for NAM
$ns_ at 0.0 "$node_(0) label \"Source S1\""
$ns_ at 0.0 "$node_(1) label \"Source S2\""
$ns_ at 0.0 "$node_(2) label \"Gateway G1\""
$ns_ at 0.0 "$node_(3) label \"Destination D1\""
$ns_ at 0.0 "$node_(4) label \"Gateway G3\""
$ns_ at 0.0 "$node_(5) label \"Gateway G2\""
$ns_ at 0.0 "$node_(6) label \"Destination D2\""

#--------------------------
# Traffic Configuration
#--------------------------
# TCP1/FTP1 Configuration
set tcp1 [new Agent/TCP/$tcpType1]
$tcp1 set class_ 2
$tcp1 set packetSize_ $val(packet_size)
set sink1 [new Agent/TCPSink]
$ns_ attach-agent $node_(0) $tcp1
$ns_ attach-agent $node_(3) $sink1
$ns_ connect $tcp1 $sink1

# Set up monitoring for TCP1
set f1 [open "results/$simType/tcp1.tr" w]
$tcp1 attach $f1
$tcp1 trace cwnd_

set ftp1 [new Application/FTP]
$ftp1 attach-agent $tcp1
$ns_ at 0.0 "$ftp1 start"

# TCP2/FTP2 Configuration
set tcp2 [new Agent/TCP/$tcpType2]
$tcp2 set class_ 1
$tcp2 set packetSize_ $val(packet_size)
set sink2 [new Agent/TCPSink]
$ns_ attach-agent $node_(1) $tcp2
$ns_ attach-agent $node_(6) $sink2
$ns_ connect $tcp2 $sink2

# Set up monitoring for TCP2
set f2 [open "results/$simType/tcp2.tr" w]
$tcp2 attach $f2
$tcp2 trace cwnd_

set ftp2 [new Application/FTP]
$ftp2 attach-agent $tcp2
$ns_ at 0.0 "$ftp2 start"

#--------------------------
# Packet Counting Procedures
#--------------------------
set stats_recorded 0
set final_tcp1_seqno 0
set final_tcp2_seqno 0

proc record {} {
    global ns_ tcp1 tcp2 f1 f2 val stats_recorded final_tcp1_seqno final_tcp2_seqno
    
    set now [$ns_ now]
    
    if {$now < [expr $val(stop) - 1]} {
        set tcp1_seqno [$tcp1 set ack_]
        set tcp2_seqno [$tcp2 set ack_]
        
        if {[catch {puts $f1 "$now $tcp1_seqno"}]} {
            # Ignore errors silently
        } else {
            flush $f1
        }
        
        if {[catch {puts $f2 "$now $tcp2_seqno"}]} {
            # Ignore errors silently
        } else {
            flush $f2
        }
        
        # Schedule the next recording
        $ns_ at [expr $now + 1.0] "record"
    } elseif {$stats_recorded == 0} {
        # Record the final values only once
        set final_tcp1_seqno [$tcp1 set ack_]
        set final_tcp2_seqno [$tcp2 set ack_]
        set stats_recorded 1
    }
}

proc print_stats {} {
    global tcpType1 tcpType2 final_tcp1_seqno final_tcp2_seqno
    
    puts "\nPacket Statistics:"
    puts "FTP1 (TCP $tcpType1):"
    puts "  Packets successfully transmitted: $final_tcp1_seqno"
    puts "FTP2 (TCP $tcpType2):"
    puts "  Packets successfully transmitted: $final_tcp2_seqno"
    puts "\nTotal packets exchanged: [expr $final_tcp1_seqno + $final_tcp2_seqno]"
}

# Start recording
$ns_ at 0.0 "record"

#--------------------------
# Terminate Simulation
#--------------------------
# Stop the FTP applications first
$ns_ at [expr $val(stop) - 1.0] "$ftp1 stop"
$ns_ at [expr $val(stop) - 1.0] "$ftp2 stop"

# Detach agents and clean up nodes
$ns_ at [expr $val(stop) - 0.5] {
    global ns_ tcp1 tcp2 sink1 sink2 node_
    $ns_ detach-agent $node_(0) $tcp1
    $ns_ detach-agent $node_(3) $sink1
    $ns_ detach-agent $node_(1) $tcp2
    $ns_ detach-agent $node_(6) $sink2
}

# Reset nodes
for {set i 0} {$i < $val(nn)} {incr i} {
    $ns_ at [expr $val(stop) - 0.3] "$node_($i) reset"
}

# Schedule simulation termination
$ns_ at [expr $val(stop) - 0.2] "print_stats"
$ns_ at [expr $val(stop) - 0.1] "finish"
$ns_ at $val(stop) "puts \"NS EXITING...\" ; $ns_ halt"

proc finish {} {
    global ns_ tracefd namtrace f1 f2
    
    # Flush and close files
    catch {$ns_ flush-trace}
    catch {close $tracefd}
    catch {close $namtrace}
    catch {close $f1}
    catch {close $f2}
    
    puts "Simulation finished. Check trace files for analysis."
}

puts "Starting Simulation for scenario: $simType..."
$ns_ run

