--------------------------------------------------------------------------------
-- ion_application.vhdl -- Sample application for ION core.
--------------------------------------------------------------------------------
--
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


entity ion_application is
    generic(
        -- Size of code TCM block in bytes. 
        -- Set to a power of 2 or to zero to disable code TCM.
        TCM_CODE_SIZE : integer := 2048;
        -- Contents of code TCM.
        TCM_CODE_INIT : t_obj_code := zero_objcode(2048);
        
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
        DATA_CACHE_LINES : integer := 0;
        -- Size of code cache in lines. 
        -- Set to a power of 2 or 0 to disable the code cache.
        CODE_CACHE_LINES : integer := 0;
        
        -- Type of memory to be used for register bank in xilinx HW
        XILINX_REGBANK  : string    := "distributed" -- {distributed|block}
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        -- External SRAM interface.
        SRAM_ADDR_O         : out std_logic_vector(log2(SRAM_SIZE) downto 1);
        SRAM_DATA_IO        : inout std_logic_vector(15 downto 0);
        SRAM_WEn_O          : out std_logic;
        SRAM_OEn_O          : out std_logic;
        SRAM_UBn_O          : out std_logic;
        SRAM_LBn_O          : out std_logic;
        SRAM_CEn_O          : out std_logic;
        SRAM_DRIVE_EN_O     : out std_logic;

        -- FIXME to be removed.
        DEBUG_O             : out std_logic
    );
end; --entity ion_application

architecture rtl of ion_application is

signal data_wb_mosi :       t_wishbone_mosi;
signal data_wb_miso :       t_wishbone_miso;

signal data_uc_wb_mosi :    t_wishbone_mosi;
signal data_uc_wb_miso :    t_wishbone_miso;

signal irq :                std_logic_vector(7 downto 0);


signal sram_data_in :       std_logic_vector(15 downto 0);
signal sram_data_out :      std_logic_vector(15 downto 0);
signal sram_drive_en :      std_logic;

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

        DATA_WB_MOSI_O      => data_wb_mosi,
        DATA_WB_MISO_I      => data_wb_miso,
        
        DATA_UC_WB_MOSI_O   => data_uc_wb_mosi,
        DATA_UC_WB_MISO_I   => data_uc_wb_miso,

        IRQ_I               => irq
    );
    
    -- FIXME interrupts missing
    irq <= (others => '0');
    
    -- Refill memory interfaces ------------------------------------------------
    
    -- FIXME code refill port missing entirely
    -- FIXME arbiter for code/data refill buses should be here
    
    sram_port: entity work.ION_SRAM16_INTERFACE 
    generic map (
        SRAM_SIZE =>        SRAM_SIZE,
        WAIT_CYCLES =>      SRAM_WAIT_CYCLES
    )
    port map (
        CLK_I               => CLK_I,
        RESET_I             => RESET_I,

        WB_MOSI_I           => data_wb_mosi,
        WB_MISO_O           => data_wb_miso,
        
        SRAM_ADDR_O         => SRAM_ADDR_O,
        SRAM_DATA_O         => sram_data_out, 
        SRAM_DATA_I         => sram_data_in,
        SRAM_WEn_O          => SRAM_WEn_O, 
        SRAM_OEn_O          => SRAM_OEn_O, 
        SRAM_UBn_O          => SRAM_UBn_O, 
        SRAM_LBn_O          => SRAM_LBn_O, 
        SRAM_CEn_O          => SRAM_CEn_O, 
        SRAM_DRIVE_EN_O     => sram_drive_en
    );

    sram_data_in <= SRAM_DATA_IO;
    
    SRAM_DATA_IO <= sram_data_out when sram_drive_en='1' else (others => 'Z');
    
    
    -- I/O devices -------------------------------------------------------------
    
    
    -- FIXME IO devices missing, WB bus hardwired to a non-blocking state.
    data_uc_wb_miso.dat <= (others => '0');
    data_uc_wb_miso.stall <= '0';
    data_uc_wb_miso.ack <= '1';


end architecture rtl;
