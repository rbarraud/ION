--------------------------------------------------------------------------------
-- ion_application.vhdl -- Sample application for ION core.
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- IMPORTANT:
--  You need to supply your own 3-state bidirectionsl interface at the 
--  top level entity. See the DE-1 demo for an example of this.
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

use work.OBJ_CODE_PKG.all;

entity ion_application is
    generic(
        -- Size of code TCM block in bytes. 
        -- Set to a power of 2 or to zero to disable code TCM.
        TCM_CODE_SIZE : integer := 2048;
        -- Contents of code TCM.
        --TCM_CODE_INIT : t_obj_code := zero_objcode(2048);
        TCM_CODE_INIT : t_obj_code := OBJ_CODE;
        
        -- Size of data TCM block in bytes.
        -- Set to a power of 2 or to zero to disable data TCM.
        TCM_DATA_SIZE : integer := 2048;
        -- Contents of data TCM.
        TCM_DATA_INIT : t_obj_code := zero_objcode(2048);
        
        -- Size of external SRAM in 16-bit words.
        SRAM_SIZE : integer := 256*1024;
        -- Number of wait states to be used for SRAM.
        SRAM_WAIT_CYCLES : integer := 3;
        
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

        -- External SRAM interface.
        SRAM_ADDR_O         : out std_logic_vector(log2(SRAM_SIZE) downto 1);
        SRAM_DATA_I         : in std_logic_vector(15 downto 0);
        SRAM_DATA_O         : out std_logic_vector(15 downto 0);
        SRAM_WEn_O          : out std_logic;
        SRAM_OEn_O          : out std_logic;
        SRAM_UBn_O          : out std_logic;
        SRAM_LBn_O          : out std_logic;
        SRAM_CEn_O          : out std_logic;
        SRAM_DRIVE_EN_O     : out std_logic;

        IRQ_I               : in std_logic_vector(5 downto 0);
        
        GPIO_0_OUT_O        : out std_logic_vector(15 downto 0);
        GPIO_0_INP_I        : in std_logic_vector(15 downto 0)
    );
end; --entity ion_application

architecture rtl of ion_application is

signal code_wb_mosi :       t_wishbone_mosi;
signal code_wb_miso :       t_wishbone_miso;

signal data_wb_mosi :       t_wishbone_mosi;
signal data_wb_miso :       t_wishbone_miso;

signal sram_wb_mosi :       t_wishbone_mosi;
signal sram_wb_miso :       t_wishbone_miso;

signal data_uc_wb_mosi :    t_wishbone_mosi;
signal data_uc_wb_miso :    t_wishbone_miso;

signal cop2_mosi :          t_cop2_mosi;
signal cop2_miso :          t_cop2_miso;

signal gpio_miso :          t_wishbone_miso;
signal void_miso :          t_wishbone_miso;

signal io_mux_ctrl :        std_logic_vector(1 downto 0);
signal io_mux_ctrl_reg :    std_logic_vector(1 downto 0);
signal io_ce :              std_logic_vector(1 downto 0);


---- Address map constants & functions -----------------------------------------

-- GPIO block -- reserve 16 words.
constant GPIO_BASE : t_word :=          X"ffff0020";
constant GPIO_ASIZE : integer :=        26; 

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



begin

    -- Core instance -----------------------------------------------------------

    core: entity work.ION_CORE
    generic map (
        TCM_CODE_SIZE =>        TCM_CODE_SIZE,
        TCM_CODE_INIT =>        TCM_CODE_INIT,
        TCM_DATA_SIZE =>        TCM_DATA_SIZE,
        
        DATA_CACHE_LINES =>     DATA_CACHE_LINES,
        CODE_CACHE_LINES =>     CODE_CACHE_LINES,
        
        XILINX_REGBANK =>       XILINX_REGBANK
    )
    port map (
        CLK_I               => CLK_I,
        RESET_I             => RESET_I, 

        CODE_WB_MOSI_O      => code_wb_mosi,
        CODE_WB_MISO_I      => code_wb_miso,
        
        DATA_WB_MOSI_O      => data_wb_mosi,
        DATA_WB_MISO_I      => data_wb_miso,
        
        DATA_UC_WB_MOSI_O   => data_uc_wb_mosi,
        DATA_UC_WB_MISO_I   => data_uc_wb_miso,
        
        COP2_MOSI_O         => cop2_mosi,
        COP2_MISO_I         => cop2_miso,

        IRQ_I               => IRQ_I
    );
    
    
    -- SRAM refill memory interface --------------------------------------------
    
    -- 
    sram_arbiter: entity work.ION_WISHBONE_ARBITER
    port map (
        CLK_I               => CLK_I,
        RESET_I             => RESET_I,
        
        CODE_MOSI_I         => code_wb_mosi,
        CODE_MISO_O         => code_wb_miso,

        DATA_MOSI_I         => data_wb_mosi,
        DATA_MISO_O         => data_wb_miso,
        
        MEM_MOSI_0          => sram_wb_mosi,
        MEM_MISO_I          => sram_wb_miso
    );


    -- 
    sram_port: entity work.ION_SRAM16_INTERFACE 
    generic map (
        SRAM_SIZE =>        SRAM_SIZE,
        WAIT_CYCLES =>      SRAM_WAIT_CYCLES
    )
    port map (
        CLK_I               => CLK_I,
        RESET_I             => RESET_I,

        WB_MOSI_I           => sram_wb_mosi,
        WB_MISO_O           => sram_wb_miso,
        
        SRAM_ADDR_O         => SRAM_ADDR_O,
        SRAM_DATA_O         => SRAM_DATA_O, 
        SRAM_DATA_I         => SRAM_DATA_I,
        SRAM_WEn_O          => SRAM_WEn_O, 
        SRAM_OEn_O          => SRAM_OEn_O, 
        SRAM_UBn_O          => SRAM_UBn_O, 
        SRAM_LBn_O          => SRAM_LBn_O, 
        SRAM_CEn_O          => SRAM_CEn_O, 
        SRAM_DRIVE_EN_O     => SRAM_DRIVE_EN_O
    );

    
    -- Dummy COP2 for interface testing ----------------------------------------
    
    cop2: entity work.ION_COP2_STUB
    port map (
        CLK_I               => CLK_I,
        RESET_I             => RESET_I, 
        
        CPU_MOSI_I          => cop2_mosi,
        CPU_MISO_O          => cop2_miso
    );
    
    
    -- I/O devices -------------------------------------------------------------
    
    -- Decode the index of the IO slave being addressed.
    io_mux_ctrl <=
        "01" when adecode(data_uc_wb_mosi.adr, GPIO_BASE, GPIO_ASIZE)='1' else
        "00";

    -- Convert slave index to one-hot enable signal vector.
    with io_mux_ctrl select io_ce <=
        "01" when "01",
        "10" when "10",
        "00" when others;
    
    
    gpio_ports: entity work.ION_GPIO_INTERFACE 
    generic map (
        PORT_WIDTH =>       16
    )
    port map (
        CLK_I               => CLK_I,
        RESET_I             => RESET_I,

        WB_MOSI_I           => data_uc_wb_mosi,
        WB_MISO_O           => gpio_miso,
        
        EN_I                => io_ce(0),
        
        GPIO_0_O            => GPIO_0_OUT_O,
        GPIO_0_I            => GPIO_0_INP_I
    );
    
    -- IO MISO multiplexor ----

    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                io_mux_ctrl_reg <= (others => '0');
            elsif data_uc_wb_mosi.cyc='1' then
                io_mux_ctrl_reg <= io_mux_ctrl;
            end if;
        end if;
    end process;        
    
    with io_mux_ctrl_reg select data_uc_wb_miso <=
        gpio_miso       when "01",
        void_miso       when others;
    
    -- MISO to be fed to the core by the UC_WB MISO multiplexor when 
    -- no valid area is addressed.
    void_miso.stall <= '0';
    void_miso.ack <= '1';
    void_miso.dat <= (others => '0');        


end architecture rtl;
