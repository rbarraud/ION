--##############################################################################
-- ion_core_tb.vhdl -- Test bench for full ION core.
--
-- Simulates the full ION core, which includes TCM and caches.
-- FIXME no simulated external memory yet.
-- The size and contents of the simulated memory are defined in package 
-- sim_params_pkg.
--------------------------------------------------------------------------------
-- FIXME no support for simulating external IRQs.
--------------------------------------------------------------------------------
-- SIMULATED IO DEVICES:
-- Apart from the fake UART implemented in package ion_tb_pkg, this test bench 
-- simulates the following ports:
--
-- 20010020: Debug register 0 (R/W).    -- FIXME unimplemented
-- 20010024: Debug register 1 (R/W).    -- FIXME unimplemented
-- 20010028: Debug register 2 (R/W).    -- FIXME unimplemented
-- 2001002c: Debug register 3 (R/W).    -- FIXME unimplemented
--
-- NOTE: these addresses are for write accesses only. for read accesses, the 
-- debug registers 0..3 are mirrored over all the io address range 2001xxxxh.
--
-- The debug registers 0 to 3 can only be used to test 32-bit i/o.
-- All of these registers can only be addressed as 32-bit words. Any other type
-- of access will yield undefined results.
--------------------------------------------------------------------------------
-- Console logging:
--
-- Console output (at address 0x20000000) is logged to text file
-- "hw_sim_console_log.txt".
--
-- IMPORTANT: The code that echoes UART TX data to the simulation console does
-- line buffering; it will not print anything until it gets a CR (0x0d), and
-- will ifnore LFs (0x0a). Bear this in mind if you see no output when you 
-- expect it.
--
-- Console logging is done by monitoring CPU writes to the UART, NOT by looking
-- at the TxD pin. It will NOT catch baud-related problems, etc.
--------------------------------------------------------------------------------
-- WARNING: Will only work on Modelsim; uses custom library SignalSpy.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;

use work.txt_util.all;
use work.ION_MAIN_PKG.all;

use work.ION_TB_PKG.all;
use work.sim_params_pkg.all;


entity ION_CORE_TB is
end;


architecture testbench of ION_CORE_TB is

--------------------------------------------------------------------------------
-- Core interface.

signal clk :                std_logic := '0';
signal reset :              std_logic := '1';

signal data_uc_wb_mosi :    t_wishbone_mosi;
signal data_uc_wb_miso :    t_wishbone_miso;

signal irq :                std_logic_vector(7 downto 0);


--------------------------------------------------------------------------------
-- Logging signals & simulation control.

signal done :               std_logic := '0';

-- Log file
file log_file: TEXT open write_mode is "hw_sim_log.txt";

-- Console output log file
file con_file: TEXT open write_mode is "hw_sim_console_log.txt";

-- All the info needed by the logger is here
signal log_info :           t_log_info;


--------------------------------------------------------------------------------

begin

    core: entity work.ION_CORE
    generic map (
        TCM_CODE_SIZE => 8192,
        TCM_CODE_INIT => OBJ_CODE,
        TCM_DATA_SIZE => BRAM_SIZE
    )
    port map (
        CLK_I               => clk,
        RESET_I             => reset, 

        DATA_UC_WB_MOSI_O   => data_uc_wb_mosi,
        DATA_UC_WB_MISO_I   => data_uc_wb_miso,

        IRQ_I               => irq
    );


    -- Master clock: free running clock used as main module clock --------------
    run_master_clock:
    process(done, clk)
    begin
        if done = '0' then
            clk <= not clk after T/2;
        end if;
    end process run_master_clock;

    -- Main simulation process: reset MCU and wait for fixed period ------------
    drive_uut:
    process
    variable l : line;
    begin
        wait for T*4;
        reset <= '0';
        
        wait for T*SIMULATION_LENGTH;

        -- Flush console output to log console file (in case the end of the
        -- simulation caught an unterminated line in the buffer)
        if log_info.con_line_ix > 1 then
            write(l, log_info.con_line_buf(1 to log_info.con_line_ix));
            writeline(con_file, l);
        end if;

        print("TB finished");
        done <= '1';
        wait;
        
    end process drive_uut;
    
    -- Logging process: launch logger function ---------------------------------
    log_execution:
    process
    begin
        log_cpu_activity(clk, reset, done, 
                         "ION_CORE_TB", "core/cpu",
                         log_info, "log_info",
                         LOG_TRIGGER_ADDRESS, log_file, con_file);
        wait;
    end process log_execution;
    
end architecture testbench;
