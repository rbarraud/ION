--##############################################################################
-- ion_cpu_tb.vhdl -- Test bench for standalone CPU.
--
-- Simulates the CPU connected to fake memory on both buses. 
-- The size and contents of the simulated memory are defined in package 
-- sim_params_pkg.
--
--------------------------------------------------------------------------------
-- MEMORY MAP (except IO areas, see below):
--
--                             Code ROM         Data RAM
--                            -----------------------------
-- Code [00000000..FFFFFFFF] :    R/O              
-- Data [00000000..BFBFFFFF] :                     R/W
-- Data [BFC00000..BFCFFFFF] :    R/O              
-- Data [BFD00000..FFFFFFFF] :                     R/W
--                            -----------------------------
--
-- Note we only simulate two separate blocks, ROM for code and RAM for data.
-- Both are mirrored all over the decoded memory spaces. 
-- The code ROM is accessible from the data bus so that SW constants can be 
-- easily reached.
--
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
-- 20010030: Wait states for simulated code memory accesses (W/o).
-- 20010034: Wait states for simulated data memory accesses (W/o).
--
-- NOTE: These addresses are for write accesses only. For read accesses, the 
-- debug registers 0..3 are mirrored over all the io address range 2001xxxxh.
--
-- The debug registers 0 to 3 can only be used to test 32-bit i/o.
-- All of these registers can only be addressed as 32-bit words. Any other type
-- of access will yield undefined results.
--
-- These registers are only write-enabled if the generic ENABLE_DEBUG_REGISTERS
-- is TRUE.
--------------------------------------------------------------------------------
-- Console logging:
--
-- The TB implements a simple, fake console at address 0x20000000.
-- Any bytes written to that address will be logged to text file
-- "hw_sim_console_log.txt".
--
-- IMPORTANT: The code that echoes UART TX data to the simulation console does
-- line buffering; it will not print anything until it gets a CR (0x0d), and
-- will ifnore LFs (0x0a). Bear this in mind if you see no output when you 
-- expect it.
--
--------------------------------------------------------------------------------
-- WARNING: This TB will only work on Modelsim; uses custom library SignalSpy.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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


entity ION_CPU_TB is
    generic (
        CODE_WCYCLES : integer := 1;
        DATA_WCYCLES : integer := 0;
        
        ENABLE_DEBUG_REGISTERS : boolean := false
    );
end;


architecture testbench of ION_CPU_TB is

-- Simulation clock rate
constant CLOCK_RATE : integer   := 50e6;
-- Simulation clock period
constant T : time               := (1.0e9/real(CLOCK_RATE)) * 1 ns;

--------------------------------------------------------------------------------
-- Memory.

-- For CPU verification, we'll connect a data array to the CPU data port with no 
-- intervening cache, like TCMs.

-- For the data array, we'll use the data memory size and initialization values.
constant DTCM_SIZE : integer := DATA_MEM_SIZE;
constant DTCM_ADDR_SIZE : integer := log2(DTCM_SIZE);

-- Using shared variables for big memory arrays speeds up simulation a lot;
-- see Modelsim 6.3 User Manual, section on 'Modelling Memory'.
-- WARNING: I have only tested this construct with Modelsim SE 6.3.
shared variable dtcm : t_word_table(0 to DTCM_SIZE-1) := (others => X"00000000");

signal dtcm_addr :          std_logic_vector(DTCM_ADDR_SIZE downto 2);
signal dtcm_data :          t_word;
signal data_dtcm_ce :       std_logic;
signal data_dtcm_ce_reg :   std_logic;
signal data_rd_en_reg :     std_logic;
signal dtcm_wait :          std_logic;
signal data_ctcm_ce :       std_logic;

signal data_dtcm :          t_word;
signal data_ctcm :          t_word;


-- For the code array, we'll use the code memory size and initialization values.
constant CTCM_SIZE : integer := CODE_MEM_SIZE;
constant CTCM_ADDR_SIZE : integer := log2(CTCM_SIZE);

shared variable ctcm : t_word_table(0 to CTCM_SIZE-1) := objcode_to_wtable(obj_code, CTCM_SIZE);

signal ctcm_addr :          std_logic_vector(CTCM_ADDR_SIZE downto 2);
signal ctcm_data :          t_word;
signal ctcm_wait :          std_logic;

signal code_wait_ctr :      integer range -2 to 63;
signal data_wait_ctr :      integer range -2 to 63;

signal code_ctcm_ce_reg :   std_logic;
signal code_ctcm :          t_word;


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
    data_ctcm_ce <= '1' when data_mosi.addr(31 downto 20) = X"bfc" else '0';
    data_dtcm_ce <= '1' when data_mosi.addr(31 downto 28) /= X"2" and 
                   data_ctcm_ce='0' 
               else '0';
            
    -- Simulated data RAM write port.
    -- Note we ignore the wait states; we get the data when it's in DATA_MOSI
    -- and let the CPU deal with the simulated wait states.
    -- This is the behavior expected from a real ION bus slave.
    simulated_dtcm_write:
    process(clk)
    begin
        if clk'event and clk='1' then
            if data_dtcm_ce='1' then 
                if data_mosi.wr_be(0)='1' then
                    dtcm(to_integer(unsigned(dtcm_addr)))(7 downto 0) := data_mosi.wr_data(7 downto 0);
                end if;
                if data_mosi.wr_be(1)='1' then
                    dtcm(to_integer(unsigned(dtcm_addr)))(15 downto 8) := data_mosi.wr_data(15 downto 8);
                end if;
                if data_mosi.wr_be(2)='1' then
                    dtcm(to_integer(unsigned(dtcm_addr)))(23 downto 16) := data_mosi.wr_data(23 downto 16);
                end if;
                if data_mosi.wr_be(3)='1' then
                    dtcm(to_integer(unsigned(dtcm_addr)))(31 downto 24) := data_mosi.wr_data(31 downto 24);
                end if;
            end if;
        end if;
    end process simulated_dtcm_write;
    
    -- Simulated data RAM read port.
    data_memory:
    process(clk)
    begin
        if clk'event and clk='1' and data_dtcm_ce='1' then
            -- Update data bus the cycle after rd_en is asserted if there's no 
            -- wait states, or the cycle after wait goes low otherwise.
            --if (to_integer(wait_states_data)=0) or (data_wait_ctr = 1) then
                data_dtcm <= dtcm(to_integer(unsigned(dtcm_addr)));
            --end if;
        end if;
    end process data_memory;

    -- Simulated code RAM read port connected to the data bus.
    code_memory_as_data:
    process(clk)
    begin
        if clk'event and clk='1' and data_ctcm_ce='1' then
            -- Update data bus the cycle after rd_en is asserted if there's no 
            -- wait states, or the cycle after wait goes low otherwise.
            if (to_integer(wait_states_data)=0) or (data_wait_ctr = 1) then
                data_ctcm <= ctcm(to_integer(unsigned(dtcm_addr)));
            end if;
        end if;
    end process code_memory_as_data;
    
    -- Read data will come from either the code array or the data array; we 
    -- to drive the mux with a delayed CE, the data bus is pipelined.
    -- The data abus will be driven only when the ION bus specs say so, to
    -- help pinpoint bugs in the bus logic.
    data_miso.rd_data <= 
        data_dtcm when data_dtcm_ce_reg='1' and data_wait_ctr=0 else 
        data_ctcm when data_dtcm_ce_reg='0' and data_wait_ctr=0 else
        (others => 'Z');
    -- TODO Debug IO register inputs are unimplemented.
 
 
    data_mem_wait_states:
    process(clk)
    begin
        if clk'event and clk='1' then
            if reset = '1' then
                data_wait_ctr <= -2;
            elsif data_dtcm_ce='1' and (data_mosi.rd_en='1' or data_mosi.wr_be/="0000") then
                data_wait_ctr <= to_integer(wait_states_data);
            elsif data_wait_ctr >= -1 then
                data_wait_ctr <= data_wait_ctr - 1;
            else 
                data_wait_ctr <= -2;
            end if;
            
            data_dtcm_ce_reg <= data_dtcm_ce;
            data_rd_en_reg <= data_mosi.rd_en;
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
            if (to_integer(wait_states_code)=0) or (code_wait_ctr = 1) then
                code_ctcm <= ctcm(to_integer(unsigned(ctcm_addr)));
            end if;
        end if;
    end process code_memory;    

    code_miso.rd_data <=
        code_ctcm when code_wait_ctr <= 0 else 
        (others => 'Z');
    
    
    code_mem_wait_states:
    process(clk)
    begin
        if clk'event and clk='1' then
            if reset = '1' then
                code_wait_ctr <= -2;
            elsif code_mosi.rd_en='1' then
                code_wait_ctr <= to_integer(wait_states_code);
            elsif code_wait_ctr >= -1 then
                code_wait_ctr <= code_wait_ctr - 1;
            else 
                code_wait_ctr <= -2;
            end if;
            
            code_ctcm_ce_reg <= code_mosi.rd_en;
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
                wait_states_code <= to_unsigned(CODE_WCYCLES,wait_states_code'length);
                wait_states_data <= to_unsigned(DATA_WCYCLES,wait_states_data'length);
            else
                if debug_reg_ce='1' and data_mosi.wr_be/="0000" and 
                   ENABLE_DEBUG_REGISTERS then
                    case data_mosi.addr(15 downto 0) is
                    when X"0030" => 
                        wait_states_code <= unsigned(data_mosi.wr_data(5 downto 0));
                    when X"0034" =>
                        wait_states_data <= unsigned(data_mosi.wr_data(5 downto 0));
                    when others => -- ignore access.
                    end case;
                end if;
            end if;
        end if;
    end process debug_register_writes;

    
    -- Placeholder signals, to be completed ------------------------------------
    
    irq <= (others => '0');
    cache_miso.ready <= '1';
    
    -- Logging process: launch logger function ---------------------------------
    log_execution:
    process
    begin
        log_cpu_activity(clk_delayed, reset, done, 
                         "ION_CPU_TB", "cpu",
                         log_info, "log_info",
                         LOG_TRIGGER_ADDRESS, log_file, con_file);
        wait;
    end process log_execution;
    
end architecture testbench;
