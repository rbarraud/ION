onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider Fetch
add wave -noupdate -expand -group Code
add wave -noupdate -group Code -color {Sky Blue} -format Literal -radix hexadecimal /ion_cpu_tb/code_mosi.addr
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_cpu_tb/code_miso.rd_data
add wave -noupdate -group Code -format Logic /ion_cpu_tb/code_mosi.rd_en
add wave -noupdate -group Code -format Logic /ion_cpu_tb/code_miso.mwait
add wave -noupdate -group Code -color Gold -format Literal -radix hexadecimal /ion_cpu_tb/cpu/p1_ir_reg
add wave -noupdate -color Blue -format Literal -radix hexadecimal /ion_cpu_tb/cpu/p0_pc_reg
add wave -noupdate -format Literal /ion_cpu_tb/code_wait_ctr
add wave -noupdate -divider Memory
add wave -noupdate -format Literal /ion_cpu_tb/data_wait_ctr
add wave -noupdate -format Literal /ion_cpu_tb/wait_states_data
add wave -noupdate -format Literal -expand /ion_cpu_tb/cpu/data_mosi_o
add wave -noupdate -format Literal -radix hexadecimal -expand /ion_cpu_tb/cpu/data_miso_i
add wave -noupdate -divider {Debug 2}
add wave -noupdate -format Literal -radix unsigned /ion_cpu_tb/cpu/p0_rt_num
add wave -noupdate -format Literal -radix unsigned /ion_cpu_tb/cpu/p0_rs_num
add wave -noupdate -color {Light Blue} -format Literal -radix unsigned /ion_cpu_tb/cpu/p1_rd_num
add wave -noupdate -color Aquamarine -format Literal -radix unsigned /ion_cpu_tb/cpu/p2_load_target
add wave -noupdate -color {Cornflower Blue} -format Logic /ion_cpu_tb/cpu/p2_do_load
add wave -noupdate -format Literal -radix hexadecimal /ion_cpu_tb/cpu/p1_rbank_forward
add wave -noupdate -format Logic /ion_cpu_tb/cpu/p0_rbank_rt_hazard
add wave -noupdate -format Logic /ion_cpu_tb/cpu/p0_rbank_rs_hazard
add wave -noupdate -format Literal -radix hexadecimal /ion_cpu_tb/cpu/p1_rt
add wave -noupdate -format Literal -radix hexadecimal /ion_cpu_tb/cpu/p1_rs
add wave -noupdate -color Orange -format Literal -radix hexadecimal /ion_cpu_tb/cpu/p1_rbank(2)
add wave -noupdate -format Literal -radix hexadecimal /ion_cpu_tb/cpu/p1_rbank
add wave -noupdate -format Logic /ion_cpu_tb/data_dtcm_ce
add wave -noupdate -format Logic /ion_cpu_tb/data_ctcm_ce
add wave -noupdate -color White -format Logic /ion_cpu_tb/clk
add wave -noupdate -format Logic /ion_cpu_tb/cpu/p1_do_load
add wave -noupdate -format Logic /ion_cpu_tb/cpu/load_interlock
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {290000 ps} 0}
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
update
WaveRestoreZoom {0 ps} {21875 ns}
