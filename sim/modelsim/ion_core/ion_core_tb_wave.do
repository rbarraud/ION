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
add wave -noupdate -radix hexadecimal -childformat {{/ion_core_tb/core/cpu/DATA_MOSI_O.addr -radix hexadecimal} {/ion_core_tb/core/cpu/DATA_MOSI_O.wr_data -radix hexadecimal}} -expand -subitemconfig {/ion_core_tb/core/cpu/DATA_MOSI_O.addr {-height 15 -radix hexadecimal} /ion_core_tb/core/cpu/DATA_MOSI_O.rd_en {-color Thistle -height 15} /ion_core_tb/core/cpu/DATA_MOSI_O.wr_be {-color {Medium Aquamarine} -height 15} /ion_core_tb/core/cpu/DATA_MOSI_O.wr_data {-color White -height 15 -radix hexadecimal}} /ion_core_tb/core/cpu/DATA_MOSI_O
add wave -noupdate -radix hexadecimal -childformat {{/ion_core_tb/core/cpu/DATA_MISO_I.rd_data -radix hexadecimal} {/ion_core_tb/core/cpu/DATA_MISO_I.mwait -radix hexadecimal}} -expand -subitemconfig {/ion_core_tb/core/cpu/DATA_MISO_I.rd_data {-height 15 -radix hexadecimal} /ion_core_tb/core/cpu/DATA_MISO_I.mwait {-height 15 -radix hexadecimal}} /ion_core_tb/core/cpu/DATA_MISO_I
add wave -noupdate -divider Debug
add wave -noupdate /ion_core_tb/core/cpu/load_interlock
add wave -noupdate -radix hexadecimal /ion_core_tb/core/cpu/p1_rbank_wr_data
add wave -noupdate /ion_core_tb/core/cpu/p2_do_load
add wave -noupdate -radix hexadecimal /ion_core_tb/core/tcm_code_present/code_tcm/tcm_addr
add wave -noupdate /ion_core_tb/core/tcm_code_present/code_arbiter/master0_ce
add wave -noupdate -color {Orange Red} /ion_core_tb/core/tcm_code_present/code_arbiter/master0_ce_reg
add wave -noupdate /ion_core_tb/core/tcm_code_present/code_arbiter/master0_request
add wave -noupdate /ion_core_tb/core/tcm_code_present/code_arbiter/master0_selected
add wave -noupdate /ion_core_tb/core/tcm_code_present/code_arbiter/master1_request
add wave -noupdate /ion_core_tb/core/tcm_code_present/code_arbiter/master1_selected
add wave -noupdate -radix hexadecimal -childformat {{/ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MOSI_O.addr -radix hexadecimal} {/ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MOSI_O.rd_en -radix hexadecimal} {/ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MOSI_O.wr_be -radix hexadecimal} {/ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MOSI_O.wr_data -radix hexadecimal}} -expand -subitemconfig {/ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MOSI_O.addr {-height 15 -radix hexadecimal} /ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MOSI_O.rd_en {-height 15 -radix hexadecimal} /ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MOSI_O.wr_be {-height 15 -radix hexadecimal} /ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MOSI_O.wr_data {-height 15 -radix hexadecimal}} /ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MOSI_O
add wave -noupdate -radix hexadecimal -childformat {{/ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MISO_I.rd_data -radix hexadecimal} {/ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MISO_I.mwait -radix hexadecimal}} -expand -subitemconfig {/ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MISO_I.rd_data {-height 15 -radix hexadecimal} /ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MISO_I.mwait {-height 15 -radix hexadecimal}} /ion_core_tb/core/tcm_code_present/code_arbiter/SLAVE_MISO_I
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {930000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 206
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
WaveRestoreZoom {835647 ps} {1024353 ps}
