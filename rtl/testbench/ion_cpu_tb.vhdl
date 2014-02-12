--##############################################################################
-- Simulation test bench -- not synthesizable.
--
-- Simulates the MCU core connected to a simulated external static RAM on a 
-- 16-bit bus, plus an optional 8-bit static ROM. This setup is more or less 
-- that of develoment board DE-1 from Terasic.
--------------------------------------------------------------------------------
-- Simulated I/O
-- Apart from the io devices within the SoC module, this test bench simulates
-- the following ports:
--
-- 20010000: HW IRQ 0 countdown register (W/o).
-- 20010004: HW IRQ 1 countdown register (W/o).
-- 20010008: HW IRQ 2 countdown register (W/o).
-- 2001000c: HW IRQ 3 countdown register (W/o).
-- 20010010: HW IRQ 4 countdown register (W/o).
-- 20010014: HW IRQ 5 countdown register (W/o).
-- 20010018: HW IRQ 6 countdown register (W/o).
-- 2001001c: HW IRQ 7 countdown register (W/o).
-- 20010020: Debug register 0 (R/W).
-- 20010024: Debug register 1 (R/W).
-- 20010028: Debug register 2 (R/W).
-- 2001002c: Debug register 3 (R/W).
-- 20010030: Wait states for simulated code memory accesses (W/o).
-- 20010030: Wait states for simulated data memory accesses (W/o).
--
-- NOTE: these addresses are for write accesses only. for read accesses, the 
-- debug registers 0..3 are mirrored over all the io address range 2001xxxxh.
--
-- Writing N to an IRQ X countdown register will trigger hardware interrupt X
-- N clock cycles later. The interrupt line will be asserted for 1 clock cycle.
--
-- The debug registers 0 to 3 can only be used to test 32-bit i/o.
-- All of these registers can only be addressed as 32-bit words. Any other type
-- of access will yield undefined results.
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


entity ION_CPU_TB is
end;


architecture testbench of ION_CPU_TB is

--------------------------------------------------------------------------------
-- Memory.

-- For CPU verification, we'll connect a data array to the CPU data port with no 
-- intervening cache, like TCMs.

-- For the data array, we'll use the SRAM size and initialization values.
constant DTCM_SIZE : integer := SRAM_SIZE;
constant DTCM_ADDR_SIZE : integer := log2(DTCM_SIZE);

-- Using shared variables for big memory arrays speeds up simulation a lot;
-- see Modelsim 6.3 User Manual, section on 'Modelling Memory'.
-- WARNING: I have only tested this construct with Modelsim SE 6.3.
shared variable dtcm : t_word_table(0 to DTCM_SIZE-1) := (others => X"00000000");

signal dtcm_addr :          std_logic_vector(DTCM_ADDR_SIZE downto 2);
signal dtcm_data :          t_word;
signal dtcm_ce :            std_logic;
signal dtcm_wait :          std_logic;

-- For the code array, we'll use the BRAM size and initialization values.
constant CTCM_SIZE : integer := BRAM_SIZE;
constant CTCM_ADDR_SIZE : integer := log2(CTCM_SIZE);

shared variable ctcm : t_word_table(0 to CTCM_SIZE-1) := objcode_to_wtable(obj_code, CTCM_SIZE);

signal ctcm_addr :          std_logic_vector(CTCM_ADDR_SIZE downto 2);
signal ctcm_data :          t_word;
signal ctcm_wait :          std_logic;

signal code_wait_ctr :      integer range 0 to 63;
signal data_wait_ctr :      integer range 0 to 63;

--------------------------------------------------------------------------------
-- CPU interface.

signal clk :                std_logic := '0';
signal clk_delayed :        std_logic;
signal reset :              std_logic := '1';

signal data_mosi :          t_cpumem_mosi;
signal data_miso :          t_cpumem_miso;

signal code_mosi :          t_cpumem_mosi;
signal code_miso :          t_cpumem_miso;

signal cache_mosi :         t_cache_mosi;
signal cache_miso :         t_cache_miso;

signal irq :                std_logic_vector(7 downto 0);

--------------------------------------------------------------------------------
-- Debug registers.

signal debug_reg_ce :       std_logic;

signal wait_states_code :   unsigned(5 downto 0) := (others => '0');
signal wait_states_data :   unsigned(5 downto 0) := (others => '0');

--------------------------------------------------------------------------------
-- Logging signals & simulation control.

signal done :               std_logic := '0';

-- Log file
file log_file: TEXT open write_mode is "hw_sim_log.txt";

-- Console output log file
file con_file: TEXT open write_mode is "hw_sim_console_log.txt";

-- All the info needed by the logger is here
signal log_info :           t_log_info;

-- Dummy address decode signal for console output pseudoport.
signal console_we :         std_logic;

--------------------------------------------------------------------------------

begin

    cpu: entity work.ION_CPU
    generic map (
        XILINX_REGBANK => "distributed"
    )
    port map (
        CLK_I               => clk,
        RESET_I             => reset, 
        
        DATA_MOSI_O         => data_mosi,
        DATA_MISO_I         => data_miso,

        CODE_MOSI_O         => code_mosi,
        CODE_MISO_I         => code_miso,

        CACHE_CTRL_MOSI_O   => cache_mosi,
        CACHE_CTRL_MISO_I   => cache_miso,

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
    
    clk_delayed <= clk after 1 ns;

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

    
    -- Data memory -------------------------------------------------------------
    
    dtcm_addr <= data_mosi.addr(dtcm_addr'high downto 2);
    data_miso.mwait <= dtcm_wait;
    dtcm_ce <= '1' when data_mosi.addr(31 downto 28) /= X"2" else '0';
            
    -- Note we inore the wait states; we get the data when it's in DATA_MOSI
    -- and let the CPU deal with the simulated wait states.
    simulated_dtcm_write:
    process(clk)
    begin
        if clk'event and clk='1' then
            if dtcm_ce='1' then 
                if data_mosi.wr_be(0)='1' then
                    dtcm(conv_integer(unsigned(dtcm_addr)))(7 downto 0) := data_mosi.wr_data(7 downto 0);
                end if;
                if data_mosi.wr_be(1)='1' then
                    dtcm(conv_integer(unsigned(dtcm_addr)))(15 downto 8) := data_mosi.wr_data(15 downto 8);
                end if;
                if data_mosi.wr_be(2)='1' then
                    dtcm(conv_integer(unsigned(dtcm_addr)))(23 downto 16) := data_mosi.wr_data(23 downto 16);
                end if;
                if data_mosi.wr_be(3)='1' then
                    dtcm(conv_integer(unsigned(dtcm_addr)))(31 downto 24) := data_mosi.wr_data(31 downto 24);
                end if;
            end if;
        end if;
    end process simulated_dtcm_write;
    
    data_memory:
    process(clk)
    begin
        if clk'event and clk='1' and dtcm_ce='1' then
            -- Update data bus the cycle after rd_en is asserted if there's no 
            -- wait states, or the cycle after wait goes low otherwise.
            if (conv_integer(wait_states_data)=0) or (data_wait_ctr = 1) then
                data_miso.rd_data <= dtcm(conv_integer(unsigned(dtcm_addr)));
            end if;
        end if;
    end process data_memory;
 
    data_mem_wait_states:
    process(clk)
    begin
        if clk'event and clk='1' then
            if reset = '1' then
                data_wait_ctr <= 0;
            elsif dtcm_ce='1' and (data_mosi.rd_en='1' or data_mosi.wr_be/="0000") and data_wait_ctr=0 then
                data_wait_ctr <= conv_integer(wait_states_data);
            elsif data_wait_ctr > 0 then
                data_wait_ctr <= data_wait_ctr - 1;
            else 
                data_wait_ctr <= 0;
            end if;
        end if;
    end process data_mem_wait_states;
    
    dtcm_wait <= '1' when data_wait_ctr > 0 else '0';
  
    
    -- Code memory -------------------------------------------------------------
    
    ctcm_addr <= code_mosi.addr(ctcm_addr'high downto 2);
    code_miso.mwait <= ctcm_wait;
    
    code_memory:
    process(clk)
    begin
        if clk'event and clk='1' then
            -- Update data bus the cycle after rd_en is asserted if there's no 
            -- wait states, or the cycle after wait goes low otherwise.
            if (conv_integer(wait_states_code)=0) or (code_wait_ctr = 1) then
                code_miso.rd_data <= ctcm(conv_integer(unsigned(ctcm_addr)));
            end if;
        end if;
    end process code_memory;    

    code_mem_wait_states:
    process(clk)
    begin
        if clk'event and clk='1' then
            if reset = '1' then
                code_wait_ctr <= 0;
            elsif code_mosi.rd_en='1' and code_wait_ctr=0 then
                code_wait_ctr <= conv_integer(wait_states_code);
            elsif code_wait_ctr > 0 then
                code_wait_ctr <= code_wait_ctr - 1;
            else 
                code_wait_ctr <= 0;
            end if;
        end if;
    end process code_mem_wait_states;
    
    ctcm_wait <= '1' when code_wait_ctr > 0 else '0';

    
    -- Debug registers ---------------------------------------------------------
    
    debug_reg_ce <= '1' when data_mosi.addr(31 downto 16) = X"2001" else '0';
    
    debug_register_writes:
    process(clk)
    begin
        if clk'event and clk='1' then 
            if reset = '1' then
                wait_states_code <= "000011";
                wait_states_data <= "000010";
            elsif debug_reg_ce='1' and data_mosi.wr_be/="0000" then
                case data_mosi.addr(15 downto 0) is
                when X"0030" => 
                    wait_states_code <= unsigned(data_mosi.wr_data(5 downto 0));
                when X"0034" =>
                    wait_states_data <= unsigned(data_mosi.wr_data(5 downto 0));
                when others => -- ignore access.
                end case;
            end if;
        end if;
    end process debug_register_writes;
    
    -- Decode a fake console output port to be used in the test code.
    console_we <= '1' when 
        data_mosi.addr = X"20000000" and
        data_mosi.wr_be /= "0000"
        else '0';

    
    -- Placeholder signals, to be completed ------------------------------------
    
    irq <= (others => '0');
    cache_miso.ready <= '1';
    
    -- Logging process: launch logger function ---------------------------------
    log_execution:
    process
    begin
        log_cpu_activity(clk_delayed, reset, done, 
                         "ION_CPU_TB", "cpu",
                         log_info, "log_info", "console_we",
                         LOG_TRIGGER_ADDRESS, log_file, con_file);
        wait;
    end process log_execution;
    
end architecture testbench;