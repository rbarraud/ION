--##############################################################################
-- Simulation test bench -- not synthesizable.
--
--------------------------------------------------------------------------------
-- Console logging:
--
-- Console output (at addresses compatible to Plasma's) is logged to text file
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
        TCM_CODE_SIZE => BRAM_SIZE,
        TCM_CODE_INIT => obj_code,
        TCM_DATA_SIZE => 2048
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
