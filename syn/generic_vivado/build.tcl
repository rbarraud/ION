# STEP#0: project configuration.
set PROJECT_NAME    "zynq_demo"
set RTL_DIR         "../../src/rtl"
set BOARD_DIR       "../../boards/zybo"
set TOP_MODULE      "zybo_top"
set VERILOG_FILES [list \
    "$RTL_DIR/cpu.v" \
    "$RTL_DIR/mcu.v" \
    "$BOARD_DIR/zybo_top.v" \
]
set XDC_FILES [list \
    "$BOARD_DIR/constraints/vivado-zybo.xdc" \
]
# The code ROM init data will be included off this directory.
# (So the SW in question needs to be built ahead of this synthesis.)
set OBJ_CODE_DIR    "../../sw/cputest"
# From this point onwards the script is mostly generic.

# STEP#1: define the output directory area.
#
set outputDir ./$PROJECT_NAME
file mkdir $outputDir
#
# STEP#2: setup design sources and constraints
#
read_verilog    $VERILOG_FILES
read_xdc        $XDC_FILES
#
# STEP#3: run synthesis, write design checkpoint, report timing,
# and utilization estimates
#
synth_design -top $TOP_MODULE -part "xc7z010clg400-1" -include_dirs $OBJ_CODE_DIR
write_checkpoint -force $outputDir/post_synth.dcp
report_timing_summary -file $outputDir/post_synth_timing_summary.rpt
report_utilization -hierarchical -file $outputDir/post_synth_util.rpt
#
# Run custom script to report critical timing paths
# FIXME TBD
#reportCriticalPaths $outputDir/post_synth_critpath_report.csv
#
# STEP#4: run logic optimization, placement and physical logic optimization,
# write design checkpoint, report utilization and timing estimates
#
opt_design
#FIXME TBD
#reportCriticalPaths $outputDir/post_opt_critpath_report.csv
place_design
report_clock_utilization -file $outputDir/clock_util.rpt
#
# Optionally run optimization if there are timing violations after placement
if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
puts "Found setup timing violations => running physical optimization"
phys_opt_design
}
write_checkpoint -force $outputDir/post_place.dcp
report_utilization -file $outputDir/post_place_util.rpt
report_utilization -file $outputDir/post_place_util.hier.rpt -hierarchical
report_timing_summary -file $outputDir/post_place_timing_summary.rpt
#
# STEP#5: run the router, write the post-route design checkpoint, report the routing
# status, report timing, power, and DRC, and finally save the Verilog netlist.
#
route_design
write_checkpoint -force $outputDir/post_route.dcp
report_route_status -file $outputDir/post_route_status.rpt
report_timing_summary -file $outputDir/post_route_timing_summary.rpt
report_power -file $outputDir/post_route_power.rpt
report_drc -file $outputDir/post_imp_drc.rpt
# TODO WE don't need the Verilog netlist, make this optional.
#write_verilog -force $outputDir/cpu_impl_netlist.v -mode timesim -sdf_anno true
#
# STEP#6: generate a bitstream
#
write_bitstream -force $outputDir/$PROJECT_NAME.bit
