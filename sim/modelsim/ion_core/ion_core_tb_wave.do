onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /ion_core_tb/clk
add wave -noupdate -format Logic /ion_core_tb/reset
add wave -noupdate -divider Fetch
add wave -noupdate -color Gold -format Literal -radix hexadecimal /ion_core_tb/core/cpu/p1_ir_reg
add wave -noupdate -color Blue -format Literal -radix hexadecimal /ion_core_tb/core/cpu/p0_pc_reg
add wave -noupdate -divider {Interconnect -- Code}
add wave -noupdate -format Literal -radix hexadecimal -expand /ion_core_tb/core/tcm_code_present/code_arbiter/master_c_mosi_i
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/core/tcm_code_present/code_arbiter/master_d_mosi_i
add wave -noupdate -format Logic /ion_core_tb/core/tcm_code_present/code_arbiter/data_request
add wave -noupdate -format Logic /ion_core_tb/core/tcm_code_present/code_arbiter/clash
add wave -noupdate -format Literal -radix hexadecimal -expand /ion_core_tb/core/tcm_code_present/code_arbiter/master_c_miso_o
add wave -noupdate -expand -group Code
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_core_tb/core/code_mosi.addr
add wave -noupdate -group Code -format Logic -radix hexadecimal /ion_core_tb/core/code_mosi.rd_en
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_core_tb/core/code_mosi.wr_be
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_core_tb/core/code_mosi.wr_data
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_core_tb/core/code_miso.rd_data
add wave -noupdate -group Code -format Logic -radix hexadecimal /ion_core_tb/core/code_miso.mwait
add wave -noupdate -expand -group {Code TCM -- C Bus}
add wave -noupdate -group {Code TCM -- C Bus} -format Literal -radix hexadecimal /ion_core_tb/core/ctcm_c_miso.rd_data
add wave -noupdate -group {Code TCM -- C Bus} -format Logic /ion_core_tb/core/ctcm_c_miso.mwait
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/core/tcm_code_present/code_tcm/tcm_addr
add wave -noupdate -format Literal -radix hexadecimal -expand /ion_core_tb/core/ctcm_mosi
add wave -noupdate -format Literal -radix hexadecimal -expand /ion_core_tb/core/ctcm_miso
add wave -noupdate -divider {Interconnect -- Data}
add wave -noupdate -expand -group Data
add wave -noupdate -group Data -format Literal -radix hexadecimal /ion_core_tb/core/data_mosi.addr
add wave -noupdate -group Data -format Logic /ion_core_tb/core/data_mosi.rd_en
add wave -noupdate -group Data -format Literal /ion_core_tb/core/data_mosi.wr_be
add wave -noupdate -group Data -format Literal -radix hexadecimal /ion_core_tb/core/data_mosi.wr_data
add wave -noupdate -group Data -format Literal -radix hexadecimal /ion_core_tb/core/data_miso.rd_data
add wave -noupdate -group Data -format Logic /ion_core_tb/core/data_miso.mwait
add wave -noupdate -group {Code TCM -- D Bus}
add wave -noupdate -group {Code TCM -- D Bus} -format Literal -radix hexadecimal /ion_core_tb/core/ctcm_d_miso.rd_data
add wave -noupdate -group {Code TCM -- D Bus} -format Logic /ion_core_tb/core/ctcm_d_miso.mwait
add wave -noupdate -divider Debug
add wave -noupdate -format Literal -expand /ion_core_tb/core/data_ce
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/core/tcm_code_present/code_tcm/tcm_addr
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {329945 ps} 1} {{Cursor 2} {23730000 ps} 0}
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
update
WaveRestoreZoom {23581988 ps} {23885413 ps}
