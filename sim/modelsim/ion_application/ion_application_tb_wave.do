onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /ion_application_tb/clk
add wave -noupdate -divider Fetch
add wave -noupdate -color Gold -format Literal -radix hexadecimal /ion_application_tb/mpu/core/cpu/p1_ir_reg
add wave -noupdate -color Blue -format Literal -radix hexadecimal /ion_application_tb/mpu/core/cpu/p0_pc_reg
add wave -noupdate -divider {Interconnect -- Code}
add wave -noupdate -format Literal -radix hexadecimal -expand /ion_application_tb/mpu/core/tcm_code_present/code_arbiter/master_c_mosi_i
add wave -noupdate -format Literal -radix hexadecimal /ion_application_tb/mpu/core/tcm_code_present/code_arbiter/master_d_mosi_i
add wave -noupdate -format Logic /ion_application_tb/mpu/core/tcm_code_present/code_arbiter/data_request
add wave -noupdate -format Logic /ion_application_tb/mpu/core/tcm_code_present/code_arbiter/clash
add wave -noupdate -format Literal -radix hexadecimal -expand /ion_application_tb/mpu/core/tcm_code_present/code_arbiter/master_c_miso_o
add wave -noupdate -expand -group Code
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_application_tb/mpu/core/code_mosi.addr
add wave -noupdate -group Code -format Logic -radix hexadecimal /ion_application_tb/mpu/core/code_mosi.rd_en
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_application_tb/mpu/core/code_mosi.wr_be
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_application_tb/mpu/core/code_mosi.wr_data
add wave -noupdate -group Code -format Literal -radix hexadecimal /ion_application_tb/mpu/core/code_miso.rd_data
add wave -noupdate -group Code -format Logic -radix hexadecimal /ion_application_tb/mpu/core/code_miso.mwait
add wave -noupdate -expand -group Data
add wave -noupdate -group Data -format Literal -radix hexadecimal /ion_application_tb/mpu/core/data_mosi.addr
add wave -noupdate -group Data -format Logic /ion_application_tb/mpu/core/data_mosi.rd_en
add wave -noupdate -group Data -format Literal /ion_application_tb/mpu/core/data_mosi.wr_be
add wave -noupdate -group Data -format Literal -radix hexadecimal /ion_application_tb/mpu/core/data_mosi.wr_data
add wave -noupdate -group Data -format Literal -radix hexadecimal /ion_application_tb/mpu/core/data_miso.rd_data
add wave -noupdate -group Data -format Logic /ion_application_tb/mpu/core/data_miso.mwait
add wave -noupdate -group {Code TCM -- D Bus}
add wave -noupdate -group {Code TCM -- D Bus} -format Literal -radix hexadecimal /ion_application_tb/mpu/core/ctcm_d_miso.rd_data
add wave -noupdate -group {Code TCM -- D Bus} -format Logic /ion_application_tb/mpu/core/ctcm_d_miso.mwait
add wave -noupdate -divider D-Cache
add wave -noupdate -format Logic /ion_application_tb/mpu/core/data_cache_present/data_cache/ce_i
add wave -noupdate -format Logic /ion_application_tb/mpu/core/data_cache_present/data_cache/miss
add wave -noupdate -format Logic /ion_application_tb/mpu/core/data_cache_present/data_cache/lookup
add wave -noupdate -format Literal -radix unsigned /ion_application_tb/mpu/core/data_cache_present/data_cache/refill_ctr
add wave -noupdate -color Pink -format Literal /ion_application_tb/mpu/core/data_cache_present/data_cache/ps
add wave -noupdate -format Literal -radix hexadecimal -expand /ion_application_tb/mpu/data_wb_miso
add wave -noupdate -format Literal -radix hexadecimal -expand /ion_application_tb/mpu/data_wb_mosi
add wave -noupdate -format Logic /ion_application_tb/mpu/core/data_cache_present/data_cache/new_valid_flag
add wave -noupdate -format Logic /ion_application_tb/mpu/core/data_cache_present/data_cache/cached_tag_valid
add wave -noupdate -format Literal -radix hexadecimal /ion_application_tb/mpu/core/data_cache_present/data_cache/cached_tag
add wave -noupdate -divider SRAM
add wave -noupdate -format Literal -radix hexadecimal /ion_application_tb/mpu/sram_port/wb_mosi_i
add wave -noupdate -format Literal -radix hexadecimal /ion_application_tb/mpu/sram_port/wb_miso_o
add wave -noupdate -color Pink -format Literal /ion_application_tb/mpu/sram_port/ps
add wave -noupdate -expand -group SRAM
add wave -noupdate -group SRAM -format Logic /ion_application_tb/sram_cen
add wave -noupdate -group SRAM -format Logic /ion_application_tb/sram_oen
add wave -noupdate -group SRAM -format Literal -expand /ion_application_tb/sram_ben
add wave -noupdate -group SRAM -format Logic /ion_application_tb/sram_wen
add wave -noupdate -group SRAM -format Literal -radix hexadecimal /ion_application_tb/sram_addr
add wave -noupdate -group SRAM -format Literal -radix hexadecimal /ion_application_tb/sram_data
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {32529863 ps} 0}
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
WaveRestoreZoom {32489262 ps} {32818960 ps}
