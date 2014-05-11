--------------------------------------------------------------------------------
-- ion_core.vhdl -- MIPS32r2(tm) compatible CPU core
--------------------------------------------------------------------------------
-- This is the main project module. It contains the CPU plus the TCMs and caches
-- if it is configured to have any. 
-- The user does not need to tinker with any modules at or below this level.
--------------------------------------------------------------------------------
-- FIXME when caches are missing they should be replaced with a WB bridge.
-- TODO add brief usage instructions.
-- TODO add reference to datasheet.
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- This source file may be used and distributed without         
-- restriction provided that this copyright statement is not    
-- removed from the file and that any derivative work contains  
-- the original copyright notice and the associated disclaimer. 
--                                                              
-- This source file is free software; you can redistribute it   
-- and/or modify it under the terms of the GNU Lesser General   
-- Public License as published by the Free Software Foundation; 
-- either version 2.1 of the License, or (at your option) any   
-- later version.                                               
--                                                              
-- This source is distributed in the hope that it will be       
-- useful, but WITHOUT ANY WARRANTY; without even the implied   
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
-- PURPOSE.  See the GNU Lesser General Public License for more 
-- details.                                                     
--                                                              
-- You should have received a copy of the GNU Lesser General    
-- Public License along with this source; if not, download it   
-- from http://www.opencores.org/lgpl.shtml
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.ION_INTERFACES_PKG.all;
use work.ION_INTERNAL_PKG.all;

entity ion_core is
    generic(
        -- Size of code TCM block in 32-bit words. 
        -- Set to a power of 2 or to zero to disable code TCM.
        TCM_CODE_SIZE : integer := 2048;
        -- Contents of code TCM. Defaults to zero.
        TCM_CODE_INIT : t_obj_code := zero_objcode(16);
        
        -- Size of data TCM block in 32-bit words.
        -- Set to a power of 2 or to zero to disable data TCM.
        TCM_DATA_SIZE : integer := 2048;
        -- Contents of data TCM.
        TCM_DATA_INIT : t_obj_code := zero_objcode(16);
        
        -- Size of data cache in lines. 
        -- Set to a power of 2 or 0 to disable the data cache.
        DATA_CACHE_LINES : integer := 128;
        -- Size of code cache in lines. 
        -- Set to a power of 2 or 0 to disable the code cache.
        CODE_CACHE_LINES : integer := 128;
        
        -- Type of memory to be used for register bank in xilinx HW
        XILINX_REGBANK  : string    := "distributed" -- {distributed|block}
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        -- Code cache refill port.
        CODE_WB_MOSI_O      : out t_wishbone_mosi;
        CODE_WB_MISO_I      : in t_wishbone_miso;

        -- Data cache refill port.
        DATA_WB_MOSI_O      : out t_wishbone_mosi;
        DATA_WB_MISO_I      : in t_wishbone_miso;
        
        -- Uncached data WB bridge port.
        DATA_UC_WB_MOSI_O   : out t_wishbone_mosi;
        DATA_UC_WB_MISO_I   : in t_wishbone_miso;

        -- COP2 interface.
        COP2_MOSI_O         : out t_cop2_mosi;
        COP2_MISO_I         : in t_cop2_miso;

        IRQ_I               : in std_logic_vector(5 downto 0)
    );
end; --entity ion_cpu

architecture rtl of ion_core is


--------------------------------------------------------------------------------
-- CPU interface signals

signal data_mosi :          t_cpumem_mosi;
signal data_miso :          t_cpumem_miso;
signal code_mosi :          t_cpumem_mosi;
signal code_miso :          t_cpumem_miso;

signal cache_ctrl_mosi :    t_cache_mosi;
signal icache_ctrl_miso :   t_cache_miso;
signal dcache_ctrl_miso :   t_cache_miso;

--------------------------------------------------------------------------------
-- Code space signals

-- Address decoding signals.
signal code_mux_ctrl :      std_logic_vector(1 downto 0);
signal code_mux_ctrl_reg :  std_logic_vector(1 downto 0);
signal code_ce :            std_logic_vector(1 downto 0);

-- Instruction Cache MISO bus & enable signal.
signal icache_miso :        t_cpumem_miso;

-- Code TCM MISO bus & enable signal.
signal ctcm_c_miso :        t_cpumem_miso;

-- Bus from CTCM arbiter to CTCM.
signal ctcm_mosi :          t_cpumem_mosi;
signal ctcm_miso :          t_cpumem_miso;

--------------------------------------------------------------------------------
-- Data space signals

-- Address decoding signals.
signal data_mux_ctrl :      std_logic_vector(2 downto 0);
signal data_mux_ctrl_reg :  std_logic_vector(2 downto 0);
signal data_ce :            std_logic_vector(3 downto 0);

-- Data Cache MISO bus & enable signal.
signal dcache_miso :        t_cpumem_miso;
signal dcache_ce :          std_logic;

-- Data TCM MISO bus & enable signal.
signal dtcm_miso :          t_cpumem_miso;
signal dtcm_ce :            std_logic;

-- Code TCM MISO bus & enable signal (CTCM seen from data bus).
signal ctcm_d_miso :        t_cpumem_miso;

-- Uncached Data, external WB bridge MISO bus & enable signal.
signal ucd_wb_mosi :        t_cpumem_mosi;
signal ucd_wb_miso :        t_cpumem_miso;


signal void_miso :          t_cpumem_miso;

--------------------------------------------------------------------------------
-- Address decoding constant & constant functions.

-- Data TCM mapped to the start of KSEG1 uncached area.
constant DTCM_BASE : t_word :=          X"A0000000";          
constant DTCM_ASIZE : integer :=        log2(TCM_DATA_SIZE+2);
-- Code TCM mapped to reset vector within KSEG1 uncached area.
constant CTCM_BASE : t_word :=          X"BFC00000";
constant CTCM_ASIZE : integer :=        log2(TCM_CODE_SIZE+2);
-- Code TCM accessible on data bus on the same address as on the code bus.
constant DCTCM_BASE : t_word :=         X"BFC00000";

-- Wishbone port is mapped to high 1GB area, meant for I/O mostly.
constant DWB_BASE : t_word :=           X"c0000000";
constant DWB_ASIZE : integer :=         30; 

-- NOTE: all the functions defined in this entity are "constant functions" that
-- can be used in synthesizable rtl as long as their parameters are constants.

-- Return '1' if high 's' of address 'a' match those of address 'b'.
function adecode(a : t_word; b : t_word; s : integer) return std_logic is
begin
    if a(31 downto s+1) = b(31 downto s+1) then
        return '1';
    else
        return '0';
    end if;
end function adecode;

-- Decode address to see if it is within the cached area.
-- (Cached addresses are all addresses from 0x00000000 to 0x9fffffff.)
-- Return '1' if address 'a' is cached, '0' otherwise.
function cached(a : t_word) return std_logic is
begin
    if a(31 downto 29) = "101" or a(31 downto 30) = "11" then
        return '0';
    else
        return '1';
    end if;
end function cached;


begin

--------------------------------------------------------------------------------
-- CPU

    cpu: entity work.ION_CPU
    generic map (
        XILINX_REGBANK =>   XILINX_REGBANK
    )
    port map (
        CLK_I               => CLK_I,
        RESET_I             => RESET_I, 
        
        DATA_MOSI_O         => data_mosi,
        DATA_MISO_I         => data_miso,

        CODE_MOSI_O         => code_mosi,
        CODE_MISO_I         => code_miso,

        CACHE_CTRL_MOSI_O   => cache_ctrl_mosi,
        ICACHE_CTRL_MISO_I  => icache_ctrl_miso,
        DCACHE_CTRL_MISO_I  => dcache_ctrl_miso,
        
        COP2_MOSI_O         => COP2_MOSI_O,
        COP2_MISO_I         => COP2_MISO_I,

        IRQ_I               => IRQ_I
    );

        
--------------------------------------------------------------------------------
-- Code Bus interconnect.

    -- Address decoding --------------------------------------------------------
    
    -- Decode the index of the slave being addressed.
    code_mux_ctrl <=
        "01" when adecode(code_mosi.addr, CTCM_BASE, CTCM_ASIZE) = '1' else
        "10" when cached(code_mosi.addr) = '1' else
        "00";

    -- Convert slave index to one-hot enable signal vector.
    with code_mux_ctrl select code_ce <=
        "01" when "01",
        "10" when "10",
        "00" when others;
    
    
    -- Code MISO multiplexor -----------------------------------------------
        
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                code_mux_ctrl_reg <= (others => '0');
            elsif code_mosi.rd_en='1' then
                code_mux_ctrl_reg <= code_mux_ctrl;
            end if;
        end if;
    end process;        
    
    with code_mux_ctrl_reg select code_miso <=
        ctcm_c_miso     when "01",
        icache_miso     when "10",
        void_miso       when others;

        
    -- MISO to be fed to the CPU by the code and data MISO multiplexors when 
    -- no valid area is addressed.
    void_miso.mwait <= '0';
    void_miso.rd_data <= (others => '0');        
        
        
    -- Code cache ----------------------------------------------------------
    
    code_cache_present:
    if CODE_CACHE_LINES > 0 generate

        code_cache: entity work.ION_CACHE 
        generic map (
            NUM_LINES => CODE_CACHE_LINES
        )
        port map (
            CLK_I               => CLK_I,
            RESET_I             => RESET_I,

            -- FIXME there should be a MISO for each cache in the control port
            CACHE_CTRL_MOSI_I   => cache_ctrl_mosi,
            CACHE_CTRL_MISO_O   => OPEN,
            
            CE_I                => code_ce(1),
            CPU_MOSI_I          => code_mosi,
            CPU_MISO_O          => icache_miso,
            
            MEM_MOSI_O          => CODE_WB_MOSI_O,
            MEM_MISO_I          => CODE_WB_MISO_I
        );
        
    end generate code_cache_present;

    code_cache_missing:
    if CODE_CACHE_LINES = 0 generate

        icache_miso.mwait <= '0';
        icache_miso.rd_data <= (others => '0');
        
        -- FIXME a missing code cache should be replaced by a WB bridge.
        CODE_WB_MOSI_O.cyc <= '0';
        CODE_WB_MOSI_O.stb <= '0';
        
        icache_ctrl_miso.present <= '0';
        
    end generate code_cache_missing;

    -- Code TCM ------------------------------------------------------------

    tcm_code_present:
    if TCM_CODE_SIZE > 0 generate

        -- Arbiter: share Code TCM between Code and Data space accesses.
        -- note that Data accesses have priority necessarily.
        code_arbiter: entity work.ION_CTCM_ARBITER
        port map (
            CLK_I               => CLK_I,
            RESET_I             => RESET_I, 
        
            MASTER_D_CE_I       => data_ce(2),
            MASTER_D_MOSI_I     => data_mosi,
            MASTER_D_MISO_O     => ctcm_d_miso,
        
            MASTER_C_CE_I       => code_ce(0),
            MASTER_C_MOSI_I     => code_mosi,
            MASTER_C_MISO_O     => ctcm_c_miso,
            
            SLAVE_MOSI_O        => ctcm_mosi,
            SLAVE_MISO_I        => ctcm_miso
        );
    
        -- Code TCM block.
        code_tcm: entity work.ION_TCM_CODE
        generic map (
            SIZE                => TCM_CODE_SIZE,
            INIT_DATA           => TCM_CODE_INIT
        )
        port map (
            CLK_I               => CLK_I,
            RESET_I             => RESET_I, 
            
            EN_I                => code_ce(0),
            
            MEM_MOSI_I          => ctcm_mosi,
            MEM_MISO_O          => ctcm_miso
        );
    
    end generate tcm_code_present;

    tcm_code_missing:
    if TCM_CODE_SIZE = 0 generate
    
        ctcm_miso.mwait <= '0';
        ctcm_miso.rd_data <= (others => '0');
    
    end generate tcm_code_missing;
    
    
--------------------------------------------------------------------------------
-- Data Bus interconnect.

    -- Address decoding --------------------------------------------------------
    
    -- Decode the index of the slave being addressed. 
    data_mux_ctrl <=
        "001" when adecode(data_mosi.addr, DTCM_BASE, DTCM_ASIZE) = '1' else
        "011" when adecode(data_mosi.addr, DCTCM_BASE, CTCM_ASIZE) = '1' else
        "010" when cached(data_mosi.addr) = '1' else
        "100" when adecode(data_mosi.addr, DWB_BASE, DWB_ASIZE) = '1' else
        "100";

    -- Convert slave index to one-hot enable signal vector.
    with data_mux_ctrl select data_ce <=
        "0001" when "001",
        "0010" when "010",
        "0100" when "011",
        "1000" when "100",
        "0000" when others;
    
    
    -- Data MISO multiplexor -----------------------------------------------
        
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                data_mux_ctrl_reg <= (others => '0');
            elsif data_mosi.rd_en='1' or data_mosi.wr_be/="0000" then
                data_mux_ctrl_reg <= data_mux_ctrl;
            end if;
        end if;
    end process;        
    
    with data_mux_ctrl_reg select data_miso <=
        dtcm_miso       when "001",
        dcache_miso     when "010",
        ctcm_d_miso     when "011",
        ucd_wb_miso     when "100",
        void_miso       when others;
 
    -- Data cache ----------------------------------------------------------

    data_cache_present:
    if DATA_CACHE_LINES > 0 generate
        
        data_cache: entity work.ION_CACHE 
        generic map (
            NUM_LINES => DATA_CACHE_LINES
        )
        port map (
            CLK_I               => CLK_I,
            RESET_I             => RESET_I,

            -- FIXME there should be a MISO for each cache in the control port
            CACHE_CTRL_MOSI_I   => cache_ctrl_mosi,
            CACHE_CTRL_MISO_O   => dcache_ctrl_miso,
            
            CE_I                => data_ce(1),
            CPU_MOSI_I          => data_mosi,
            CPU_MISO_O          => dcache_miso,
            
            MEM_MOSI_O          => DATA_WB_MOSI_O,
            MEM_MISO_I          => DATA_WB_MISO_I
        );
        
    end generate data_cache_present;

    data_cache_missing:
    if DATA_CACHE_LINES = 0 generate

        dcache_miso.mwait <= '0';
        dcache_miso.rd_data <= (others => '0');
        
        -- FIXME a missing data cache should be replaced by a WB bridge.
        DATA_WB_MOSI_O.cyc <= '0';
        DATA_WB_MOSI_O.stb <= '0';
        
        dcache_ctrl_miso.present <= '0';
        
    end generate data_cache_missing;

    -- Data TCM ------------------------------------------------------------

    tcm_data_present:
    if TCM_DATA_SIZE > 0 generate

        data_tcm: entity work.ION_TCM_DATA
        generic map (
            SIZE                => TCM_DATA_SIZE,
            INIT_DATA           => TCM_DATA_INIT
        )
        port map (
            CLK_I               => CLK_I,
            RESET_I             => RESET_I, 
            
            EN_I                => data_ce(0),
            
            MEM_MOSI_I          => data_mosi,
            MEM_MISO_O          => dtcm_miso
        );
    
    end generate tcm_data_present;

    tcm_data_missing:
    if TCM_DATA_SIZE = 0 generate
    
        dtcm_miso.mwait <= '0';
        dtcm_miso.rd_data <= (others => '0');
    
    end generate tcm_data_missing;
    
    
    -- Wishbone Bridge ---------------------------------------------------------

    -- The CPU side of the WB bridge will only be enabled if addressed.
    with data_ce(3) select ucd_wb_mosi.rd_en <= 
        data_mosi.rd_en         when '1',
        '0'                     when others;
        
    with data_ce(3) select ucd_wb_mosi.wr_be <= 
        data_mosi.wr_be         when '1',
        "0000"                  when others;
    
    ucd_wb_mosi.addr <= data_mosi.addr;
    ucd_wb_mosi.wr_data <= data_mosi.wr_data;
        
    -- WB bridge instance.
    data_wb_bridge: entity work.ION_WISHBONE_BRIDGE
        port map (
            CLK_I               => CLK_I,
            RESET_I             => RESET_I, 
            
            ION_MOSI_I          => ucd_wb_mosi,
            ION_MISO_O          => ucd_wb_miso,        
            
            WISHBONE_MOSI_O     => DATA_UC_WB_MOSI_O,
            WISHBONE_MISO_I     => DATA_UC_WB_MISO_I
        );
    


end architecture rtl;
