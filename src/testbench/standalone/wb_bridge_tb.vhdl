--##############################################################################
-- wb_bridge_tb.vhdl -- 
--
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


entity WB_BRIDGE_TB is
end;


architecture testbench of WB_BRIDGE_TB is

-- Length of simulation in clock cycles.
constant SIMULATION_LENGTH : integer := 100;

-- Simulation clock rate
constant CLOCK_RATE : integer   := 50e6;
-- Simulation clock period
constant T : time               := (1.0e9/real(CLOCK_RATE)) * 1 ns;


--------------------------------------------------------------------------------
-- Core interface.

signal clk :                std_logic := '0';
signal reset :              std_logic := '1';

signal ion_mosi :           t_cpumem_mosi;
signal ion_miso :           t_cpumem_miso;

signal wb_mosi :            t_wishbone_mosi;
signal wb_miso :            t_wishbone_miso;


--------------------------------------------------------------------------------
-- Uncached data WB bridge.

type t_natural_table is array(natural range <>) of natural;

-- Wait states simulated by uncached WB port (elements used in succession).
constant UNCACHED_WS : t_natural_table (0 to 3) := (4,1,3,2);

signal uwb_wait_ctr :       natural;
signal uwb_cycle_count :    natural := 0;
signal uwb_address :        t_word;

type t_ram_table is array(natural range <>) of t_word;
shared variable debug_regs: t_ram_table(0 to 15);


--------------------------------------------------------------------------------
-- Logging signals & simulation control.

shared variable error_count : integer := 0;

--------------------------------------------------------------------------------
-- 

procedure ion_idle(signal mosi : out t_cpumem_mosi) is
begin
    mosi.rd_en <= '0';
    mosi.wr_be <= "0000";
end procedure ion_idle;

procedure ion_read(
        signal clk : in std_logic;
        signal mosi : inout t_cpumem_mosi;
        signal miso : in t_cpumem_miso;
        address : in std_logic_vector(31 downto 0);
        data : out std_logic_vector(31 downto 0) 
        ) is
begin
    -- Align this read cycle with the next clock edge.
    wait until clk'event and clk='1';

    write(output, "Reading from ["& hstr(address)& "]..."& lf);
    
    mosi.rd_en <= '1';
    mosi.addr <= std_logic_vector(address);
    
    -- Wait until the next clock edge.
    wait until clk'event and clk='1';
    
    -- (An overlapping CPI cycle would start in this cycle; we are not 
    -- simulating overlapping cycles in this simple TB.)
    
    -- Now, if wait is asserted...
    if miso.mwait = '1' then 
        -- ...wait until it is deasserted...
        wait until clk'event and clk='1' and miso.mwait = '0';
    else
        -- ...otherwise the cycle ends here. 
        -- Take data from MISO and we're done.
        data := miso.rd_data;
    end if;
    
    
    wait until clk'event and clk='1';
    wait until clk'event and clk='1';
    wait until clk'event and clk='1';
    
    mosi.rd_en <= '0';
    
end procedure ion_read;
                    
procedure ion_write(
        signal clk : in std_logic;
        signal mosi : inout t_cpumem_mosi;
        signal miso : in t_cpumem_miso;
        address : in std_logic_vector(31 downto 0);
        data : in std_logic_vector(31 downto 0) 
        ) is
begin
    -- Align this read cycle with the next clock edge.
    wait until clk'event and clk='1';

    write(output, "Writing to ["& hstr(address)& "]..."& lf);
    
    mosi.wr_be <= "1111"; -- FIXME simulating full word writes only
    mosi.addr <= std_logic_vector(address);
    mosi.wr_data <= data;
    
    -- Wait until the next clock edge.
    wait until clk'event and clk='1';
    
    -- (An overlapping CPI cycle would start in this cycle; we are not 
    -- simulating overlapping cycles in this simple TB.)
    
    -- Now, if wait is asserted...
    if miso.mwait = '1' then 
        -- ...wait until it is deasserted...
        wait until clk'event and clk='1' and miso.mwait = '0';
    else
        -- ...otherwise the cycle ends here. 
    end if;
    
    mosi.wr_be <= "0000";
    
end procedure ion_write;                    
                    
                    
procedure check_data (
            rd_data : in std_logic_vector(31 downto 0);
            good_data : in std_logic_vector(31 downto 0)
            ) is
begin
    
    if rd_data /= good_data then 
        error_count := error_count + 1;
    end if;
    
    assert rd_data = good_data
    report "Invalid data: got "& hstr(rd_data)& ", expected "& hstr(good_data)
    severity warning;

end procedure check_data;

--------------------------------------------------------------------------------
begin

    -- UUT instantiation -------------------------------------------------------
    
    bridge: entity work.ION_WISHBONE_BRIDGE
    port map (
        CLK_I               => clk,
        RESET_I             => reset, 

        ION_MOSI_I          => ion_mosi,
        ION_MISO_O          => ion_miso,
        
        WISHBONE_MOSI_O     => wb_mosi,
        WISHBONE_MISO_I     => wb_miso
    );

    
    -- Master clock: free running clock used as main module clock --------------
    run_master_clock:
    process(clk)
    begin
        clk <= not clk after T/2;
    end process run_master_clock;

    -- Main simulation process -------------------------------------------------
    drive_uut:
    process
    variable rd_data : std_logic_vector(31 downto 0);
    begin
        wait for T*4;
        reset <= '0';
        
        
        wait for T*4;
        ion_idle(ion_mosi);
        wait for T*1;
        ion_write(clk, ion_mosi, ion_miso, X"90000000", X"12345678");
        ion_read(clk, ion_mosi, ion_miso, X"90000000", rd_data);
        check_data(rd_data, X"12345678");
        ion_idle(ion_mosi);
        wait for T*4;
        ion_write(clk, ion_mosi, ion_miso, X"90000004", X"11223344");
        ion_read(clk, ion_mosi, ion_miso, X"90000004", rd_data);
        check_data(rd_data, X"11223344");
        
        
        -- We're done; stop the simulation.
        if error_count = 0 then 
            write(output, "######## TEST PASSED ########"& lf);
        else
            write(output, "######## TEST FAILED ########"& lf);
        end if;
        
        assert 1=0
        report "TB finished"
        severity failure;
        
    end process drive_uut;



    -- Uncached WB port --------------------------------------------------------
    
    uncached_wb_port:
    process(clk)
    begin
        if clk'event and clk='1' then
            if reset = '1' then
                uwb_wait_ctr <= UNCACHED_WS((uwb_cycle_count) mod UNCACHED_WS'length);
                wb_miso.ack <= '0';
                wb_miso.dat <= (others => '1');
                uwb_address <= (others => '0');
            elsif wb_mosi.stb = '1' then
                if uwb_wait_ctr > 0 then 
                    -- Access in progress, decrement wait counter...
                    uwb_wait_ctr <= uwb_wait_ctr - 1;
                    wb_miso.ack <= '0';
                    uwb_address <= wb_mosi.adr;
                else 
                    -- Access finished, wait counter reached zero.
                    -- Prepare the wait counter for the next access...
                    uwb_wait_ctr <= UNCACHED_WS((uwb_cycle_count+1) mod UNCACHED_WS'length);
                    -- ...and drive the slave WB bus.
                    wb_miso.ack <= '1';
                    -- Termination is different for read and write accesses:
                    if wb_mosi.we = '1' then 
                        -- Write access: do the simulated write.
                        debug_regs(0) := wb_mosi.dat;
                    else
                        -- Read access: simulate read & WB slave multiplexor.
                        wb_miso.dat <= debug_regs(0);
                    end if;
                end if;
            else
                -- No WB access is going on: restore the wait counter to its 
                -- idle state and deassert ACK.
                uwb_wait_ctr <= UNCACHED_WS((uwb_cycle_count) mod UNCACHED_WS'length);
                wb_miso.ack <= '0';
            end if;
            
            -- Keep track of how many accesses we have performed. 
            -- We use this to select a number of wait states from a table.
            if wb_mosi.stb = '1' and uwb_wait_ctr = 0 then
                uwb_cycle_count <= uwb_cycle_count + 1;
            end if;
            
        end if;
    end process uncached_wb_port;

    -- stall the WB bus as long as the wait counter is not zero.
    wb_miso.stall <= 
        '1' when wb_mosi.stb = '1' and uwb_wait_ctr > 0 else
        '0';
    
end architecture testbench;
