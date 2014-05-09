onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /wb_bridge_tb/clk
add wave -noupdate -format Logic /wb_bridge_tb/reset
add wave -noupdate -divider {CPU Side}
add wave -noupdate -format Literal -radix hexadecimal /wb_bridge_tb/ion_mosi
add wave -noupdate -format Literal -radix hexadecimal /wb_bridge_tb/ion_miso
add wave -noupdate -divider {Wishbone Side}
add wave -noupdate -format Literal -radix hexadecimal -expand /wb_bridge_tb/wb_mosi
add wave -noupdate -format Literal -radix hexadecimal /wb_bridge_tb/wb_miso
add wave -noupdate -divider {Debug signals}
add wave -noupdate -format Literal /wb_bridge_tb/uwb_cycle_count
add wave -noupdate -format Literal /wb_bridge_tb/uwb_wait_ctr
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1000
configure wave -griddelta 40
configure wave -timeline 0
update
WaveRestoreZoom {0 ps} {2194500 ps}
