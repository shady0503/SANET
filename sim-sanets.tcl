#!/usr/bin/env ns
#----------------------------------------------------------------------
# SANET Architecture Simulation
#
# This simulation deploys a SANET architecture with:
#   • 2 Sources, 3 Gateways, 2 Destinations (7 nodes)
#   • 6 cells (each roughly 200×200, so that adjacent nodes are within a 
#     maximum range of 200)
#   • FTP applications (FTP1 and FTP2) between the sources and destinations
#
# Three simulation scenarios are supported:
#   1. "reno"  – both FTP flows use TCP/Reno
#   2. "vegas" – both FTP flows use TCP/Vegas
#   3. "mixed" – FTP1 uses TCP/Reno and FTP2 uses TCP/Vegas
#
# We choose throughput as the performance parameter for comparing the scenarios.
#
# Folder structure:
#   - This script is saved as sim-sanets.tcl.
#   - Trace and NAM files will be output to subdirectories of "results/" 
#     according to the scenario.
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

# Choose TCP agent types based on the simulation scenario.
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
set val(chan)           Channel/WirelessChannel    ;# Channel type
set val(prop)           Propagation/TwoRayGround   ;# Propagation model
set val(netif)          Phy/WirelessPhy            ;# Network interface type
set val(mac)            Mac/802_11                 ;# MAC type
set val(ifq)            Queue/DropTail/PriQueue    ;# Interface queue type
set val(ll)             LL                         ;# Link layer type
set val(ant)            Antenna/OmniAntenna        ;# Antenna model
set val(ifqlen)         50                         ;# Maximum packet queue length
set val(nn)             7                          ;# Total nodes: 2 sources + 3 gateways + 2 destinations
set val(rp)             DSDV                       ;# Routing protocol

# Simulation area: 600×400 so that we have 3 columns × 2 rows of 200×200 cells.
set val(x)              600
set val(y)              400

#--------------------------
# Set Up Simulator & Tracing
#--------------------------
set ns_   [new Simulator]
$ns_ color 2 Red
$ns_ color 1 Blue

# Set up output files based on scenario
set tracefileName "results/$simType/trace-$simType.tr"
set namfileName   "results/$simType/nam-$simType.nam"

set tracefd   [open $tracefileName w]
$ns_ trace-all $tracefd

set namtrace [open $namfileName w]
$ns_ namtrace-all-wireless $namtrace $val(x) $val(y)

#--------------------------
# Topography & God
#--------------------------
set topo   [new Topography]
$topo load_flatgrid $val(x) $val(y)
create-god $val(nn)

# Create a single channel instance for all nodes.
set chan_1_ [new $val(chan)]

# Configure node defaults
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
# Mapping nodes to cells:
#   node_(0): Source S1 (Cell A: top-left)
#   node_(1): Source S2 (Cell D: bottom-left)
#   node_(2): Gateway G1 (Cell B: top-middle)
#   node_(3): Destination D1 (Cell C: top-right)
#   node_(4): Gateway G3 (Middle column center)
#   node_(5): Gateway G2 (Cell E: bottom-middle)
#   node_(6): Destination D2 (Cell F: bottom-right)
for {set i 0} {$i < $val(nn)} {incr i} {
    set node_($i) [$ns_ node]
    # Disable random motion for a static deployment
    $node_($i) random-motion 0
    # Initialize node position (needed by NS-2)
    $ns_ initial_node_pos $node_($i) 20
}

# Set positions (X, Y, Z coordinates):
# Sources:
$node_(0) set X_ 100.0  
$node_(0) set Y_ 300.0
$node_(0) set Z_ 0.0

$node_(1) set X_ 100.0
$node_(1) set Y_ 100.0
$node_(1) set Z_ 0.0

# Gateways:
$node_(2) set X_ 300.0
$node_(2) set Y_ 300.0
$node_(2) set Z_ 0.0

$node_(4) set X_ 300.0
$node_(4) set Y_ 200.0
$node_(4) set Z_ 0.0

$node_(5) set X_ 300.0
$node_(5) set Y_ 100.0
$node_(5) set Z_ 0.0

# Destinations:
$node_(3) set X_ 500.0
$node_(3) set Y_ 300.0
$node_(3) set Z_ 0.0

$node_(6) set X_ 500.0
$node_(6) set Y_ 100.0
$node_(6) set Z_ 0.0

# Issue setdest commands at time 0 to “fix” the positions.
for {set i 0} {$i < $val(nn)} {incr i} {
    set xpos [$node_($i) set X_]
    set ypos [$node_($i) set Y_]
    $ns_ at 0.0 "$node_($i) setdest $xpos $ypos 0.0"
}

#--------------------------
# Set Up FTP Traffic
#--------------------------
# FTP1: from Source S1 (node_(0)) to Destination D1 (node_(3))
set tcp1 [new Agent/TCP/$tcpType1]
$tcp1 set class_ 2
set sink1 [new Agent/TCPSink]
$ns_ attach-agent $node_(0) $tcp1
$ns_ attach-agent $node_(3) $sink1
$ns_ connect $tcp1 $sink1
set ftp1 [new Application/FTP]
$ftp1 attach-agent $tcp1
$ns_ at 3.0 "$ftp1 start"

# FTP2: from Source S2 (node_(1)) to Destination D2 (node_(6))
set tcp2 [new Agent/TCP/$tcpType2]
$tcp2 set class_ 1
set sink2 [new Agent/TCPSink]
$ns_ attach-agent $node_(1) $tcp2
$ns_ attach-agent $node_(6) $sink2
$ns_ connect $tcp2 $sink2
set ftp2 [new Application/FTP]
$ftp2 attach-agent $tcp2
$ns_ at 3.0 "$ftp2 start"

#--------------------------
# Terminate Simulation
#--------------------------
for {set i 0} {$i < $val(nn)} {incr i} {
    $ns_ at 30.0 "$node_($i) reset"
}
$ns_ at 30.0 "finish"
$ns_ at 30.01 "puts \"NS EXITING...\" ; $ns_ halt"

proc finish {} {
    global ns_ tracefd
    $ns_ flush-trace
    close $tracefd
    puts "Simulation finished. Check trace files for throughput analysis."
}

puts "Starting Simulation for scenario: $simType..."
$ns_ run

