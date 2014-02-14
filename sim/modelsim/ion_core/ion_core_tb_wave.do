onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /ion_core_tb/clk
add wave -noupdate /ion_core_tb/reset
add wave -noupdate -divider Fetch
add wave -noupdate -expand -group Code -color {Sky Blue} -radix hexadecimal /ion_core_tb/core/cpu/CODE_MOSI_O.addr
add wave -noupdate -expand -group Code -radix hexadecimal /ion_core_tb/core/cpu/CODE_MISO_I.rd_data
add wave -noupdate -expand -group Code /ion_core_tb/core/cpu/CODE_MOSI_O.rd_en
add wave -noupdate -expand -group Code /ion_core_tb/core/cpu/CODE_MISO_I.mwait
add wave -noupdate -expand -group Code -color Gold -radix hexadecimal /ion_core_tb/core/cpu/p1_ir_reg
add wave -noupdate -color Blue -radix hexadecimal /ion_core_tb/core/cpu/p0_pc_reg
add wave -noupdate -divider Memory
add wave -noupdate /ion_core_tb/core/cpu/stall_pipeline
add wave -noupdate /ion_core_tb/core/cpu/pipeline_stalled
add wave -noupdate -radix hexadecimal -childformat {{/ion_core_tb/core/cpu/DATA_MOSI_O.addr -radix hexadecimal} {/ion_core_tb/core/cpu/DATA_MOSI_O.wr_data -radix hexadecimal}} -expand -subitemconfig {/ion_core_tb/core/cpu/DATA_MOSI_O.addr {-height 15 -radix hexadecimal} /ion_core_tb/core/cpu/DATA_MOSI_O.rd_en {-color {Olive Drab} -height 15} /ion_core_tb/core/cpu/DATA_MOSI_O.wr_be {-color {Medium Aquamarine} -height 15} /ion_core_tb/core/cpu/DATA_MOSI_O.wr_data {-color White -height 15 -radix hexadecimal}} /ion_core_tb/core/cpu/DATA_MOSI_O
add wave -noupdate -radix hexadecimal -childformat {{/ion_core_tb/core/cpu/DATA_MISO_I.rd_data -radix hexadecimal} {/ion_core_tb/core/cpu/DATA_MISO_I.mwait -radix hexadecimal}} -expand -subitemconfig {/ion_core_tb/core/cpu/DATA_MISO_I.rd_data {-height 15 -radix hexadecimal} /ion_core_tb/core/cpu/DATA_MISO_I.mwait {-radix hexadecimal}} /ion_core_tb/core/cpu/DATA_MISO_I
add wave -noupdate -divider Debug
add wave -noupdate -radix hexadecimal /ion_core_tb/core/data_cpu_mosi
add wave -noupdate -radix hexadecimal /ion_core_tb/core/data_cpu_miso
add wave -noupdate -radix hexadecimal /ion_core_tb/core/data_uncached_mosi
add wave -noupdate -radix hexadecimal /ion_core_tb/core/data_uncached_miso
add wave -noupdate -radix hexadecimal /ion_core_tb/core/data_tcm_mosi
add wave -noupdate -radix hexadecimal /ion_core_tb/core/data_tcm_miso
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {12399405 ps} 0} {{Cursor 2} {12350000 ps} 1}
quietly wave cursor active 1
configure wave -namecolwidth 181
configure wave -valuecolwidth 60
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {12199281 ps} {12557297 ps}
