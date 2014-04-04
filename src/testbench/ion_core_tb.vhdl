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

-- Project packages.
use work.ION_INTERFACES_PKG.all;
use work.ION_INTERNAL_PKG.all;

-- Tst bench support packages.
use std.textio.all;
use work.txt_util.all;
use work.ION_TB_PKG.all;

-- Simulation parameters defined in the SW makefile (generated package).
use work.SIM_PARAMS_PKG.all;
-- Hardware parameters & memory contents from SW build (generated package).
use work.OBJ_CODE_PKG.all;


entity ION_CORE_TB is
end;


architecture testbench of ION_CORE_TB is

-- Simulation clock rate
constant CLOCK_RATE : integer   := 50e6;
-- Simulation clock period
constant T : time               := (1.0e9/real(CLOCK_RATE)) * 1 ns;


--------------------------------------------------------------------------------
-- Core interface.

signal clk :                std_logic := '0';
signal reset :              std_logic := '1';

signal data_wb_mosi :       t_wishbone_mosi;
signal data_wb_miso :       t_wishbone_miso;

signal data_uc_wb_mosi :    t_cpumem_mosi;
signal data_uc_wb_miso :    t_cpumem_miso;

signal irq :                std_logic_vector(7 downto 0);


--------------------------------------------------------------------------------
-- Memory refill ports.

type t_natural_table is array(natural range <>) of natural;

-- Wait states simulated by data refill port (elements used in succession).
constant DATA_WS : t_natural_table (0 to 3) := (4,1,3,2);


signal data_wait_ctr :      natural;
signal data_cycle_count :   natural := 0;

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
        TCM_CODE_SIZE =>        CODE_MEM_SIZE,
        TCM_CODE_INIT =>        OBJ_CODE,
        TCM_DATA_SIZE =>        DATA_MEM_SIZE,
        
        DATA_CACHE_LINES =>     128
    )
    port map (
        CLK_I               => clk,
        RESET_I             => reset, 

        DATA_WB_MOSI_O      => data_wb_mosi,
        DATA_WB_MISO_I      => data_wb_miso,
        
        DATA_UC_WB_MOSI_O   => data_uc_wb_mosi,
        DATA_UC_WB_MISO_I   => data_uc_wb_miso,

        IRQ_I               => irq
    );

    
    data_uc_wb_miso.mwait <= '0';
    data_uc_wb_miso.rd_data <= (others => '0');

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
        file_close(con_file);
        wait;
        
    end process drive_uut;
    
    
    -- Data refill port interface ----------------------------------------------
    
    -- Crudely simulate a WB interface with a variable number of delay cycles.
    -- The number of wait cycles is taken from a table for variety's sake, this 
    -- model does not approach a real WB slave but should exercise the cache
    -- sufficiently to flush out major bugs.
    -- FIXME read data is a total fake and write cycles are not supported
    
    -- Note that this interface does NOT overlap successive reads nor cycles 
    -- with zero wait states!
    -- TODO optional simulation of overlapped reads & zero waits.
    
    data_refill_port:
    process(clk)
    begin
        if clk'event and clk='1' then
            if reset = '1' then
                data_wait_ctr <= DATA_WS((data_cycle_count) mod DATA_WS'length);
                data_wb_miso.ack <= '0';
                data_wb_miso.dat <= (others => '1');
            elsif data_wb_mosi.stb = '1' then
                if data_wait_ctr > 0 then 
                    data_wait_ctr <= data_wait_ctr - 1;
                    data_wb_miso.ack <= '0';
                else 
                    data_wait_ctr <= DATA_WS((data_cycle_count+1) mod DATA_WS'length);
                    data_wb_miso.ack <= '1';
                    -- Fake data: low 16 bits of address replicated twice.
                    data_wb_miso.dat <= data_wb_mosi.adr(15 downto 0) & 
                                data_wb_mosi.adr(15 downto 0);
                end if;
            else
                data_wait_ctr <= DATA_WS((data_cycle_count) mod DATA_WS'length);
                data_wb_miso.ack <= '0';
            end if;
            
            if data_wb_mosi.stb = '1' and data_wait_ctr = 0 then
                data_cycle_count <= data_cycle_count + 1;
            end if;
            
            
        end if;
    end process data_refill_port;
    
    data_wb_miso.stall <= 
        '1' when data_wb_mosi.stb = '1' and data_wait_ctr > 0 else
        '0';


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
