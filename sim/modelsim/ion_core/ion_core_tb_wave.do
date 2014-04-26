onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /ion_core_tb/clk
add wave -noupdate -format Logic /ion_core_tb/reset
add wave -noupdate -divider Fetch
add wave -noupdate -color Gold -format Literal -radix hexadecimal /ion_core_tb/core/cpu/p1_ir_reg
add wave -noupdate -color Blue -format Literal -radix hexadecimal /ion_core_tb/core/cpu/p0_pc_reg
add wave -noupdate -divider {Interconnect -- Code}
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/core/tcm_code_present/code_arbiter/master_c_mosi_i
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/core/tcm_code_present/code_arbiter/master_d_mosi_i
add wave -noupdate -format Logic /ion_core_tb/core/tcm_code_present/code_arbiter/data_request
add wave -noupdate -format Logic /ion_core_tb/core/tcm_code_present/code_arbiter/clash
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/core/tcm_code_present/code_arbiter/master_c_miso_o
add wave -noupdate -format Literal -expand /ion_core_tb/core/code_ce
add wave -noupdate -expand -group Code
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_core_tb/core/code_mosi.addr
add wave -noupdate -group Code -format Logic -radix hexadecimal /ion_core_tb/core/code_mosi.rd_en
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_core_tb/core/code_mosi.wr_be
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_core_tb/core/code_mosi.wr_data
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_core_tb/core/code_miso.rd_data
add wave -noupdate -group Code -format Logic -radix hexadecimal /ion_core_tb/core/code_miso.mwait
add wave -noupdate -group {Code TCM -- C Bus}
add wave -noupdate -group {Code TCM -- C Bus} -format Literal -radix hexadecimal /ion_core_tb/core/ctcm_c_miso.rd_data
add wave -noupdate -group {Code TCM -- C Bus} -format Logic /ion_core_tb/core/ctcm_c_miso.mwait
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/core/tcm_code_present/code_tcm/tcm_addr
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/core/ctcm_mosi
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/core/ctcm_miso
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
add wave -noupdate -divider D-Cache
add wave -noupdate -format Logic /ion_core_tb/core/data_cache_present/data_cache/ce_i
add wave -noupdate -format Logic /ion_core_tb/core/data_cache_present/data_cache/miss
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/data_address
add wave -noupdate -format Logic /ion_core_tb/core/data_cache_present/data_cache/lookup
add wave -noupdate -format Literal /ion_core_tb/data_wait_ctr
add wave -noupdate -format Literal /ion_core_tb/core/data_cache_present/data_cache/refill_ctr
add wave -noupdate -color Pink -format Literal /ion_core_tb/core/data_cache_present/data_cache/ps
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/data_wb_miso
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/data_wb_mosi
add wave -noupdate -format Logic /ion_core_tb/core/data_cache_present/data_cache/new_valid_flag
add wave -noupdate -format Logic /ion_core_tb/core/data_cache_present/data_cache/cached_tag_valid
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/core/data_cache_present/data_cache/cached_tag
add wave -noupdate -divider {Uncached Port}
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/data_uc_wb_mosi
add wave -noupdate -format Literal -radix hexadecimal /ion_core_tb/data_uc_wb_miso
add wave -noupdate -format Literal /ion_core_tb/uwb_wait_ctr
add wave -noupdate -divider Debug
add wave -noupdate -format Literal /ion_core_tb/core/data_cache_present/data_cache/cache_ctrl_mosi_i
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {63270000 ps} 0}
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
WaveRestoreZoom {63072965 ps} {63467036 ps}
