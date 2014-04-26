--##############################################################################
-- ion_application_tb.vhdl -- Test bench for ION core sample application module.
--
-- Simulates the sample ION application module, which includes the full core 
-- with TCM and caches, plus the memory controllers and some amount of 
-- external SRAM.
-- 
--------------------------------------------------------------------------------
-- 
--------------------------------------------------------------------------------
-- SIMULATED IO DEVICES:
--
-- Those included in th sampl application module.
--
--------------------------------------------------------------------------------
-- SIMULATED MEMORY:
--
-- FIXME explain!
--
--------------------------------------------------------------------------------
-- Console logging:
--
-- Console output (at address 0xffff0000) is logged to text file
-- "hw_sim_console_log.txt".
--
-- IMPORTANT: The code that echoes UART TX data to the simulation console does
-- line buffering; it will not print anything until it gets a CR (0x0d), and
-- will ignore LFs (0x0a). Bear this in mind if you see no output when you 
-- expect it.
--
-- Console logging is done by monitoring CPU writes to the UART, NOT by looking
-- at the TxD pin. It will NOT catch baud-related problems, etc.
--------------------------------------------------------------------------------
-- WARNING: Will only work on Modelsim 6.3+; uses proprietary library SignalSpy.
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


entity ION_APPLICATION_TB is
end;


architecture testbench of ION_APPLICATION_TB is

-- Simulation clock rate
constant CLOCK_RATE : integer   := 50e6;
-- Simulation clock period
constant T : time               := (1.0e9/real(CLOCK_RATE)) * 1 ns;


--------------------------------------------------------------------------------
-- Core interface.

signal clk :                std_logic := '0';
signal reset :              std_logic := '1';

--------------------------------------------------------------------------------
-- Simulated external 16-bit SRAM.

constant SRAM_SIZE : integer := 64 * 1024;

constant SRAM_ADDR_SIZE : integer := log2(SRAM_SIZE);

signal mpu_sram_addr :      std_logic_vector(SRAM_ADDR_SIZE downto 1);
signal sram_addr :          std_logic_vector(SRAM_ADDR_SIZE downto 1);
signal sram_data :          std_logic_vector(15 downto 0);
signal sram_output :        std_logic_vector(15 downto 0);
signal sram_wen :           std_logic;
signal sram_ben :           std_logic_vector(1 downto 0);
signal sram_oen :           std_logic;
signal sram_cen :           std_logic;

-- Static 16-bit wide RAM.
-- Using shared variables for big memory arrays speeds up simulation a lot;
-- see Modelsim 6.3 User Manual, section on 'Modelling Memory'.
-- WARNING: I have only tested this construct with Modelsim SE 6.3.
shared variable sram : t_hword_table(0 to SRAM_SIZE-1);



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

    mpu: entity work.ION_APPLICATION
    generic map (
        TCM_CODE_SIZE =>        CODE_MEM_SIZE,
        TCM_CODE_INIT =>        OBJ_CODE,
        TCM_DATA_SIZE =>        DATA_MEM_SIZE,
        
        SRAM_SIZE =>            SRAM_SIZE,
        
        DATA_CACHE_LINES =>     128,
        CODE_CACHE_LINES =>     128
    )
    port map (
        CLK_I               => clk,
        RESET_I             => reset, 

        SRAM_ADDR_O         => mpu_sram_addr,
        SRAM_DATA_IO        => sram_data, 
        SRAM_WEn_O          => sram_wen, 
        SRAM_OEn_O          => sram_oen, 
        SRAM_UBn_O          => sram_ben(1), 
        SRAM_LBn_O          => sram_ben(0), 
        SRAM_CEn_O          => sram_cen
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
        file_close(con_file);
        wait;
        
    end process drive_uut;
    

    -- Do a very basic simulation of an external SRAM --------------------------

    sram_addr <= mpu_sram_addr(SRAM_ADDR_SIZE downto 1);

    -- Simulated SRAM read.
    -- FIXME byte enables missing in read
    sram_output <=
        sram(conv_integer(unsigned(sram_addr))) when sram_cen='0'
        else (others => 'Z');
    
    sram_data <= sram_output when sram_oen='0' else (others => 'Z');
        
    simulated_sram_write:
    process(sram_wen, sram_addr, sram_oen, sram_cen, sram_ben)
    begin
        -- Write cycle
        -- FIXME should add OE\ to write control logic
        if sram_wen'event or sram_addr'event or sram_cen'event or sram_ben'event then
            if sram_ben(1)='0' and sram_cen='0' and sram_wen='0'  then
                sram(conv_integer(unsigned(sram_addr)))(15 downto 8) := sram_data(15 downto  8);
            end if;
            if sram_ben(0)='0' and sram_cen='0'  and sram_wen='0' then
                sram(conv_integer(unsigned(sram_addr)))( 7 downto 0) := sram_data( 7 downto  0);
            end if;            
        end if;
    end process simulated_sram_write;    
    
        
    -- Logging process: launch logger function ---------------------------------
    log_execution:
    process
    begin
        log_cpu_activity(clk, reset, done, 
                         "ION_APPLICATION_TB", "mpu/core/cpu",
                         log_info, "log_info",
                         LOG_TRIGGER_ADDRESS, log_file, con_file);
        wait;
    end process log_execution;
    
end architecture testbench;
