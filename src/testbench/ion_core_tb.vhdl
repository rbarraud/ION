--##############################################################################
-- ion_core_tb.vhdl -- Test bench for full ION core.
--
-- Simulates the full ION core, which includes TCM and caches.
-- 
--------------------------------------------------------------------------------
-- FIXME no support for simulating external IRQs.
--------------------------------------------------------------------------------
-- SIMULATED IO DEVICES:
--
-- This TB simulates the following IO devices as support for the test SW:
--
-- Address   Name         Size    Access  Purpose
---------------------------------------------------------------------------
-- ffff0000: DbgTxD     : 8     : b     : Debug UART TX buffer (W/o).
-- ffff0200: DbgRW0     : 32    : b/w   : Debug register 0 (R/W). 
-- ffff0204: DbgRW1     : 32    : b/w   : Debug register 1 (R/W).
--
-- (b support byte access, w support word access).
-- 
-- The fake UART is implemented in package ion_tb_pkg, not as a proper WB 
-- register but directly on the CPU buses.
-- All other debug registers are simulated as WB registers so they can be used
-- to verify the operation of the WB bridge.
--
--------------------------------------------------------------------------------
-- SIMULATED MEMORY:
--
-- Data cache refill port 
-----------------------------
-- 80000000     4KB     RAM (word access only).
-- 90000000     256MB   ROM (test pattern).
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

signal code_wb_mosi :       t_wishbone_mosi;
signal code_wb_miso :       t_wishbone_miso;

signal data_wb_mosi :       t_wishbone_mosi;
signal data_wb_miso :       t_wishbone_miso;

signal data_uc_wb_mosi :    t_wishbone_mosi;
signal data_uc_wb_miso :    t_wishbone_miso;

signal cop2_mosi :          t_cop2_mosi;
signal cop2_miso :          t_cop2_miso;

signal irq :                std_logic_vector(5 downto 0);


--------------------------------------------------------------------------------
-- Memory refill ports.

type t_natural_table is array(natural range <>) of natural;

-- Wait states simulated by data refill port (elements used in succession).
constant DATA_WS : t_natural_table (0 to 3) := (4,1,3,2);

signal data_wait_ctr :      natural;
signal data_cycle_count :   natural := 0;
signal data_address :       t_word;

type t_ram_table is array(natural range <>) of t_word;
shared variable ram :       t_ram_table(0 to 4095);

signal code_wait_ctr :      natural;
signal code_cycle_count :   natural := 0;
signal code_address :       t_word;


--------------------------------------------------------------------------------
-- Uncached data WB bridge.

-- Wait states simulated by uncached WB port (elements used in succession).
constant UNCACHED_WS : t_natural_table (0 to 3) := (4,1,3,2);

signal uwb_wait_ctr :       natural;
signal uwb_cycle_count :    natural := 0;
signal uwb_address :        t_word;

shared variable debug_regs: t_ram_table(0 to 15);


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
        
        CODE_CACHE_LINES =>     128,
        DATA_CACHE_LINES =>     128
    )
    port map (
        CLK_I               => clk,
        RESET_I             => reset, 

        CODE_WB_MOSI_O      => code_wb_mosi,
        CODE_WB_MISO_I      => code_wb_miso,
        
        DATA_WB_MOSI_O      => data_wb_mosi,
        DATA_WB_MISO_I      => data_wb_miso,
        
        DATA_UC_WB_MOSI_O   => data_uc_wb_mosi,
        DATA_UC_WB_MISO_I   => data_uc_wb_miso,

        COP2_MOSI_O         => cop2_mosi,
        COP2_MISO_I         => cop2_miso,
        
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
        file_close(con_file);
        wait;
        
    end process drive_uut;
    
    
    -- Data refill port interface ----------------------------------------------
    
    -- Crudely simulate a WB interface with a variable number of delay cycles.
    -- The number of wait cycles is taken from a table for variety's sake, this 
    -- model does not approach a real WB slave but should exercise the cache
    -- sufficiently to flush out major bugs.
    
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
                data_address <= (others => '0');
            elsif data_wb_mosi.stb = '1' then
                if data_wait_ctr > 0 then 
                    -- Access in progress, decrement wait counter...
                    data_wait_ctr <= data_wait_ctr - 1;
                    data_wb_miso.ack <= '0';
                    data_address <= data_wb_mosi.adr;
                else 
                    -- Access finished, wait counter reached zero.
                    -- Prepare the wait counter for the next access...
                    data_wait_ctr <= DATA_WS((data_cycle_count+1) mod DATA_WS'length);
                    -- ...and drive the slave WB bus.
                    data_wb_miso.ack <= '1';
                    -- Termination is different for read and write accesses:
                    if data_wb_mosi.we = '1' then 
                        -- Write access: do the simulated write.
                        -- FIXME do address decoding.
                        -- FIXME support byte & halfword writes.
                        ram(conv_integer(data_address(13 downto 2))) := data_wb_mosi.dat;
                    else
                        -- Read access: simulate read & WB slave multiplexor.
                        -- For simplicity´s sake, do the address decoding 
                        -- right here and select between RAM and ROM.
                        if data_address(31 downto 28) = X"9" then
                            -- Fake data: low 16 bits of address replicated twice.
                            data_wb_miso.dat <= data_wb_mosi.adr(15 downto 0) & 
                                    data_wb_mosi.adr(15 downto 0);
                        elsif data_address(31 downto 28) = X"8" then
                            -- Simulated RAM.
                            data_wb_miso.dat <= ram(conv_integer(data_address(13 downto 2)));
                        else 
                            -- Unmapped area: read zeros.
                            -- TODO should raise some sort of alert.
                            data_wb_miso.dat <= (others => '0');
                        end if;
                    end if;
                end if;
            else
                -- No WB access is going on: restore the wait counter to its 
                -- idle state and deassert ACK.
                data_wait_ctr <= DATA_WS((data_cycle_count) mod DATA_WS'length);
                data_wb_miso.ack <= '0';
            end if;
            
            -- Keep track of how many accesses we have performed. 
            -- We use this to select a number of wait states from a table.
            if data_wb_mosi.stb = '1' and data_wait_ctr = 0 then
                data_cycle_count <= data_cycle_count + 1;
            end if;
            
        end if;
    end process data_refill_port;
    
    -- stall the WB bus as long as the wait counter is not zero.
    data_wb_miso.stall <= 
        '1' when data_wb_mosi.stb = '1' and data_wait_ctr > 0 else
        '0';

    -- Code refill port interface ----------------------------------------------
    
    -- We do the same as for the data refill port, except we don't need to 
    -- support write cycles here.
    -- the memory we will be reading is the same as the data bus -- no need to 
    -- simulate any arbitration.
    -- Also, there's no test pattern ROM in this bus.
    
    code_refill_port:
    process(clk)
    begin
        if clk'event and clk='1' then
            if reset = '1' then
                code_wait_ctr <= DATA_WS((code_cycle_count) mod DATA_WS'length);
                code_wb_miso.ack <= '0';
                code_wb_miso.dat <= (others => '1');
                code_address <= (others => '0');
            elsif code_wb_mosi.stb = '1' then
                if code_wait_ctr > 0 then 
                    -- Access in progress, decrement wait counter...
                    code_wait_ctr <= code_wait_ctr - 1;
                    code_wb_miso.ack <= '0';
                    code_address <= code_wb_mosi.adr;
                else 
                    -- Access finished, wait counter reached zero.
                    -- Prepare the wait counter for the next access...
                    code_wait_ctr <= DATA_WS((code_cycle_count+1) mod DATA_WS'length);
                    -- ...and drive the slave WB bus.
                    code_wb_miso.ack <= '1';
                    -- We will ignore write accesses on this bus. 
                    -- (We are already asserting that there aren't any anyway.)
                    -- FIXME add assertion
                    if data_wb_mosi.we = '0' then 
                        -- Read access: simulate read & WB slave multiplexor.
                        if code_address(31 downto 28) = X"8" then
                            -- Simulated RAM.
                            code_wb_miso.dat <= ram(conv_integer(code_address(13 downto 2)));
                        else 
                            -- Cached, unmapped area: read zeros.
                            -- TODO should raise some sort of alert.
                            code_wb_miso.dat <= (others => '0');
                        end if;
                    end if;
                end if;
            else
                -- No WB access is going on: restore the wait counter to its 
                -- idle state and deassert ACK.
                code_wait_ctr <= DATA_WS((code_cycle_count) mod DATA_WS'length);
                code_wb_miso.ack <= '0';
            end if;
            
            -- Keep track of how many accesses we have performed. 
            -- We use this to select a number of wait states from a table.
            if code_wb_mosi.stb = '1' and code_wait_ctr = 0 then
                code_cycle_count <= code_cycle_count + 1;
            end if;
            
        end if;
    end process code_refill_port;
    
    -- stall the WB bus as long as the wait counter is not zero.
    code_wb_miso.stall <= 
        '1' when code_wb_mosi.stb = '1' and code_wait_ctr > 0 else
        '0';
        

    -- Uncached WB port --------------------------------------------------------
    
    uncached_wb_port:
    process(clk)
    begin
        if clk'event and clk='1' then
            if reset = '1' then
                uwb_wait_ctr <= UNCACHED_WS((uwb_cycle_count) mod UNCACHED_WS'length);
                data_uc_wb_miso.ack <= '0';
                data_uc_wb_miso.dat <= (others => '1');
                uwb_address <= (others => '0');
            elsif data_uc_wb_mosi.stb = '1' then
                if uwb_wait_ctr > 0 then 
                    -- Access in progress, decrement wait counter...
                    uwb_wait_ctr <= data_wait_ctr - 1;
                    data_uc_wb_miso.ack <= '0';
                    uwb_address <= data_wb_mosi.adr;
                else 
                    -- Access finished, wait counter reached zero.
                    -- Prepare the wait counter for the next access...
                    uwb_wait_ctr <= UNCACHED_WS((uwb_cycle_count+1) mod UNCACHED_WS'length);
                    -- ...and drive the slave WB bus.
                    data_uc_wb_miso.ack <= '1';
                    -- Termination is different for read and write accesses:
                    if data_uc_wb_mosi.we = '1' then 
                        -- Write access: do the simulated write.
                        -- FIXME simulate write to debug reg
                        debug_regs(0) := data_uc_wb_mosi.dat;
                    else
                        -- Read access: simulate read & WB slave multiplexor.
                        -- FIXME simulate read from debug reg
                        data_uc_wb_miso.dat <= debug_regs(0);
                    end if;
                end if;
            else
                -- No WB access is going on: restore the wait counter to its 
                -- idle state and deassert ACK.
                uwb_wait_ctr <= UNCACHED_WS((uwb_cycle_count) mod UNCACHED_WS'length);
                data_uc_wb_miso.ack <= '0';
            end if;
            
            -- Keep track of how many accesses we have performed. 
            -- We use this to select a number of wait states from a table.
            if data_uc_wb_mosi.stb = '1' and uwb_wait_ctr = 0 then
                uwb_cycle_count <= uwb_cycle_count + 1;
            end if;
            
        end if;
    end process uncached_wb_port;

    -- stall the WB bus as long as the wait counter is not zero.
    data_uc_wb_miso.stall <= 
        '1' when data_uc_wb_mosi.stb = '1' and uwb_wait_ctr > 0 else
        '0';

    
    -- Dummy COP2 for interface testing ----------------------------------------
    
    
    cop2: entity work.ION_COP2_STUB
    port map (
        CLK_I               => clk,
        RESET_I             => reset, 
        
        CPU_MOSI_I          => cop2_mosi,
        CPU_MISO_O          => cop2_miso
    );
   
    
    -- HW interrupt simulation -------------------------------------------------
       
    -- FIXME work in progress
    interrupt_registers:
    process(clk)
    begin
        if clk'event and clk='1' then
            if reset='1' then
                irq <= (others => '0');
            else
                irq <= log_info.hw_irq;
            end if;
        end if;
    end process interrupt_registers;    
        
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
