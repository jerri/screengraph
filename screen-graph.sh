#!/bin/sh
# Simple script to output an graph on the console from data output to another
# screen window.
#
# Copyright (C) 2006 Gerhard Siegesmund
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Contact: Gerhard Siegesmund <jerri@jerri.de>
#          Parkstr. 10
#          80339 Munich

function output_help () {
  echo "Usage: $0 STY screentitle [graphtitle] [wanted]"
  echo ""
  echo "STY Name of the screen the data is to be read from."
  echo "screentitle Title of the window of the screen where the data is shown."
  echo "[graphtitle] Title of the graph."
  echo "[wanted]: What value will this graph reach in the end."
  echo "In this case screen_graph also outputs ETA (based on linear interpolation)."
  echo ""
  echo "Use a line like this to create the data-lines for the graph"
  echo "echo -n \$(date +%s); echo -n ' '; echo \$DATAPOINT"
  echo ""
  exit 0
}

# Create a tempfile to use. This should be random enough to provide tempfiles
# for most shell-applications.
# usage: tempfile namebase
function tempfile {
  [ -z "$1" ] && {
    echo "tempfile: Please provide a temp-basename"
    exit 1
  }
  echo $1'-'$$'-'$RANDOM'-'$(date +"%s")'.tmp'
}

trap "rm -f $tempfile $tempfile.tmp $tempfile.graph; exit 0" HUP KILL TERM

if [ -z "$1" -o -z "$2" ]; then
  output_help
else
  sty=$1
  graphdata=$2
fi

if [ -n "$3" ]; then
  title=$3
else
  title=""
fi

if [ -n "$4" ]; then
  total=$4
  minus="-1"
else
  total=""
  minus=""
fi

tempfile=$(tempfile screengraph)

# get the current size of the terminal
rows=$(stty -a | grep 'rows' | sed -e 's/.*rows \([0-9]*\);.*/\1/')
rows=$(( $rows - 1 $minus ))
cols=$(stty -a | grep 'columns' | sed -e 's/.*columns \([0-9]*\);.*/\1/')

screen=/usr/bin/screen

# get the data from the given screen window
$screen -S $sty -p $graphdata -X hardcopy -h $tempfile

# parse the relevant lines
cat $tempfile | egrep '^[0-9]* [0-9.]*$' > $tempfile.tmp
mv $tempfile.tmp $tempfile

# now get the date for the linear interpolation
firstline=$(head -1 $tempfile)
lastline=$(tail -1 $tempfile)
eta=$(echo $firstline $lastline $total | perl -ne 'split (/ +/);$seconds=($_[2]-$_[0])/($_[3]-$_[1])*($_[4] - $_[3]);if ($seconds < 0) { print "Finished" } else { ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=gmtime($seconds);print sprintf ("%d Tag(e) %02d:%02d:%02d", $yday, $hour, $min, $sec); }')
lastvalue=$(echo $lastline | cut -f 2 -d ' ')

# correct the dates and set the change rate
cat $tempfile | perl -ne 'split (/ /); ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($_[0]); chomp ($_[1]); if (defined ($last)) { $diff=($_[1]-$last)/($_[0]-$tlast)*60; } else { $diff=0; }; $tlast=$_[0]; $last=$_[1]; print "".(1900+$year)."-".($mon+1)."-".$mday."_".$hour.":".$min.":".$sec." ".$_[1]." ".$diff."\n";' > $tempfile.tmp
mv $tempfile.tmp $tempfile

# create the graph and safe it to a file.
gnuplot <<EOF
set grid
set nokey
set title "$title"
set output "$tempfile.graph"
set terminal dumb $cols $rows
set timefmt "%Y-%m-%d_%H:%M:%S"
set xdata time
set format x '%H:%M'
set y2tics
plot "$tempfile" using 1:2 with lines, "$tempfile" using 1:3 axes x1y2 with impulses
exit
EOF

# Now output the graph and add some coloring.
cat $tempfile.graph | sed -e 's/\([0-9]\+\)/[1;37m\1[0m/g' -e 's/\(\*\+\)/[31m\1[0m/g' -e 's/\(\#\+\)/[34m\1[0m/g' -e 's/\([.:]\+\)/[1;30m\1[0m/g'

# Now output the ETA if wanted.
if [ -n "$total" ]; then
  echo "Now: "$lastvalue" Wanted: "$total" ETA: "$eta
fi

rm -f $tempfile $tempfile.tmp $tempfile.graph
