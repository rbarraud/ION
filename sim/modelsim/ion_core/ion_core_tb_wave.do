onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /ion_core_tb/clk
add wave -noupdate /ion_core_tb/reset
add wave -noupdate -divider Fetch
add wave -noupdate -expand -group Code -color {Sky Blue} -radix hexadecimal /ion_core_tb/core/cpu/code_mosi_o.addr
add wave -noupdate -expand -group Code -radix hexadecimal /ion_core_tb/core/cpu/code_miso_i.rd_data
add wave -noupdate -expand -group Code /ion_core_tb/core/cpu/code_mosi_o.rd_en
add wave -noupdate -expand -group Code /ion_core_tb/core/cpu/code_miso_i.mwait
add wave -noupdate -expand -group Code -color Gold -radix hexadecimal /ion_core_tb/core/cpu/p1_ir_reg
add wave -noupdate -color Blue -radix hexadecimal /ion_core_tb/core/cpu/p0_pc_reg
add wave -noupdate /ion_core_tb/code_wait_ctr
add wave -noupdate -divider Memory
add wave -noupdate /ion_core_tb/core/cpu/stall_pipeline
add wave -noupdate /ion_core_tb/core/cpu/pipeline_stalled
add wave -noupdate -childformat {{/ion_cpu_tb/cpu/DATA_MOSI_O.addr -radix hexadecimal} {/ion_cpu_tb/cpu/DATA_MOSI_O.wr_data -radix hexadecimal}} -expand -subitemconfig {/ion_cpu_tb/cpu/DATA_MOSI_O.addr {-color Orchid -height 15 -radix hexadecimal} /ion_core_tb/core/cpu/DATA_MOSI_O.rd_en {-color {Olive Drab} -height 15} /ion_core_tb/core/cpu/DATA_MOSI_O.wr_be {-color {Medium Aquamarine} -height 15} /ion_core_tb/core/cpu/DATA_MOSI_O.wr_data {-color White -height 15 -radix hexadecimal}} /ion_core_tb/core/cpu/DATA_MOSI_O
add wave -noupdate -childformat {{/ion_cpu_tb/cpu/DATA_MISO_I.rd_data -radix hexadecimal}} -expand -subitemconfig {/ion_cpu_tb/cpu/DATA_MISO_I.rd_data {-color {Medium Sea Green} -height 15 -radix hexadecimal}} /ion_core_tb/core/cpu/DATA_MISO_I
add wave -noupdate /ion_core_tb/data_wait_ctr
add wave -noupdate -divider {Debug 2}
add wave -noupdate /ion_core_tb/core/cpu/cop0/privileged
add wave -noupdate -radix hexadecimal -childformat {{/ion_cpu_tb/log_info.pc_m(0) -radix hexadecimal} {/ion_cpu_tb/log_info.pc_m(1) -radix hexadecimal} {/ion_cpu_tb/log_info.pc_m(2) -radix hexadecimal} {/ion_cpu_tb/log_info.pc_m(3) -radix hexadecimal}} -expand -subitemconfig {/ion_cpu_tb/log_info.pc_m(0) {-height 15 -radix hexadecimal} /ion_core_tb/log_info.pc_m(1) {-height 15 -radix hexadecimal} /ion_core_tb/log_info.pc_m(2) {-height 15 -radix hexadecimal} /ion_core_tb/log_info.pc_m(3) {-height 15 -radix hexadecimal}} /ion_core_tb/log_info.pc_m
add wave -noupdate -radix hexadecimal /ion_core_tb/core/cpu/p1_rbank(27)
add wave -noupdate -radix hexadecimal /ion_core_tb/core/cpu/p1_rbank(26)
add wave -noupdate /ion_core_tb/core/cpu/p0_pc_increment
add wave -noupdate -color White /ion_core_tb/core/cpu/p0_pc_load_pending
add wave -noupdate /ion_core_tb/core/cpu/cop0/CPU_O.pc_load_en
add wave -noupdate -radix hexadecimal /ion_core_tb/core/cpu/cop0/CPU_O.pc_load_value
add wave -noupdate /ion_core_tb/core/cpu/p1_exception
add wave -noupdate /ion_core_tb/core/cpu/p2_exception
add wave -noupdate -color Firebrick /ion_core_tb/core/cpu/cop0/CPU_I.exception
add wave -noupdate /ion_core_tb/core/cpu/cop0/CPU_I.missing_cop
add wave -noupdate -radix hexadecimal /ion_core_tb/core/cpu/cop0/CPU_I.pc_restart
add wave -noupdate -radix hexadecimal /ion_core_tb/core/cpu/cop0/epc_reg
add wave -noupdate -color {Indian Red} -radix hexadecimal /ion_core_tb/core/cpu/p0_pc_next
add wave -noupdate -radix hexadecimal /ion_core_tb/core/cpu/p0_pc_next_exceptions
add wave -noupdate -radix hexadecimal /ion_core_tb/core/cpu/p0_pc_target
add wave -noupdate -radix hexadecimal /ion_core_tb/core/cpu/p0_pc_incremented
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2450000 ps} 1} {{Cursor 2} {2410000 ps} 0}
quietly wave cursor active 2
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
WaveRestoreZoom {2200104 ps} {2876185 ps}
