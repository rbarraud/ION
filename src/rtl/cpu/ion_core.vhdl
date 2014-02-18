--------------------------------------------------------------------------------
-- ion_core.vhdl -- MIPS32r2(tm) compatible CPU core
--------------------------------------------------------------------------------
-- This is the main project module. It contains the CPU plus the TCMs and caches
-- if it is configured to have any. 
-- The user does not need to tinker wth any modules at or below this level.
--------------------------------------------------------------------------------
-- FIXME add brief usge instructions.
-- FIXME add reference to datasheet.
--------------------------------------------------------------------------------
--
-- This is halffinished stuff; it should have at least one wishbone bridge for
-- uncached data, necessary to hang peripherals on.
--
--------------------------------------------------------------------------------
-- Copyright (C) 2014 Jose A. Ruiz
--                                                              
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

use work.ION_MAIN_PKG.all;


entity ion_core is
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

        -- FIXME cache refill ports missing
        -- FIXME uncached wishbone ports missing
        
        -- Fixme this should be a Wishbone port, not an ION port.
        DATA_UC_WB_MOSI_O   : out t_cpumem_mosi;
        DATA_UC_WB_MISO_I   : in t_cpumem_miso;
        
        IRQ_I               : in std_logic_vector(7 downto 0)
    );
end; --entity ion_cpu

architecture rtl of ion_core is


--------------------------------------------------------------------------------
-- CPU interface signals

signal data_cpu_mosi :      t_cpumem_mosi;
signal data_cpu_miso :      t_cpumem_miso;
signal code_cpu_mosi :      t_cpumem_mosi;
signal code_cpu_miso :      t_cpumem_miso;

signal cache_ctrl_mosi :    t_cache_mosi;
signal cache_ctrl_miso :    t_cache_miso;

--------------------------------------------------------------------------------
-- Code space signals

-- CPU to cache mux.
signal code_cache_miso :    t_cpumem_miso;
signal code_cache_mosi :    t_cpumem_mosi;
-- Cache mux to Code TCM area decoder.
signal code_uc_0_miso :     t_cpumem_miso;
signal code_uc_0_mosi :     t_cpumem_mosi;
-- Code TCM area decoder to CTCM arbiter.
signal code_ctcm_arb_miso : t_cpumem_miso;
signal code_ctcm_arb_mosi : t_cpumem_mosi;
-- CTCM arbiter to Code TCM.
signal code_tcm_miso :      t_cpumem_miso;
signal code_tcm_mosi :      t_cpumem_mosi;

-- FIXME this should come from one of the CP0 config registers.
constant code_tcm_base :    t_word := X"BFC00000";          

--------------------------------------------------------------------------------
-- Data space signals

-- CPU to cache mux.
signal data_cached_miso :   t_cpumem_miso;
signal data_cached_mosi :   t_cpumem_mosi;
-- Cache mux to Data TCM mux.
signal data_uc_0_miso : t_cpumem_miso;
signal data_uc_0_mosi : t_cpumem_mosi;
-- Data TCM mux to Data TCM.
signal data_tcm_miso :      t_cpumem_miso;
signal data_tcm_mosi :      t_cpumem_mosi;
-- Data TCM mux to Data/Code TCM arbiter mux.
signal data_uc_1_miso : t_cpumem_miso;
signal data_uc_1_mosi : t_cpumem_mosi;
-- Data/Code TCM arbiter mux to Wishbone bridge.
signal data_uc_2_miso : t_cpumem_miso;
signal data_uc_2_mosi : t_cpumem_mosi;
-- Data/Code TCM arbiter mux to arbiter.
signal data_ctcm_arb_mosi : t_cpumem_mosi;
signal data_ctcm_arb_miso : t_cpumem_miso;

-- FIXME this should come from one of the CP0 config registers.
signal data_tcm_base :      t_word := X"00000000";          

--------------------------------------------------------------------------------
-- Wishbone bridge signals

signal wbone_mem_miso :     t_cpumem_miso;


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
        
        DATA_MOSI_O         => data_cpu_mosi,
        DATA_MISO_I         => data_cpu_miso,

        CODE_MOSI_O         => code_cpu_mosi,
        CODE_MISO_I         => code_cpu_miso,

        CACHE_CTRL_MOSI_O   => cache_ctrl_mosi,
        CACHE_CTRL_MISO_I   => cache_ctrl_miso,

        IRQ_I               => IRQ_I
    );

    -- FIXME caches missing.
    -- FIXME cache control interface to be refactored.
    cache_ctrl_miso.ready <= '1';
    
    
--------------------------------------------------------------------------------
-- Code Bus.
-- FIXME Code TCM should be writeable from data space.

    -- Code cache ----------------------------------------------------------

    -- TODO this mux is needed even when the cache is missing; otherwise we
    -- get synth problems in Q2 (BRAM Dout goes straight to BRAM.Ain).
    code_mux_cache: entity work.ION_CACHE_MUX
    port map (
        CLK_I               => CLK_I,
        RESET_I             => RESET_I, 

        MASTER_MOSI_I       => code_cpu_mosi,
        MASTER_MISO_O       => code_cpu_miso,
        
        K0_CACHED_IN        => '1',
        
        CACHED_MOSI_O       => code_cache_mosi,
        CACHED_MISO_I       => code_cache_miso,
        
        UNCACHED_MOSI_O     => code_uc_0_mosi,
        UNCACHED_MISO_I     => code_uc_0_miso
    );
    
    code_cache_present:
    if CODE_CACHE_LINES > 0 generate

        assert 1=0
        report "Code cache unimplemented, set CODE_CACHE_SIZE => 0."
        severity failure;
        
    end generate code_cache_present;

    code_cache_missing:
    if CODE_CACHE_LINES = 0 generate

        code_cache_miso.mwait <= '0';
        code_cache_miso.rd_data <= (others => '0');
        
    end generate code_cache_missing;

    -- Code TCM ------------------------------------------------------------

    tcm_code_present:
    if TCM_CODE_SIZE > 0 generate
        
        -- Filter Code accesses to CTCM space.
        code_area_decoder: entity work.ION_BUS_DECODER
        generic map (
            SLAVE_AREA_SIZE     => TCM_CODE_SIZE
        )
        port map (
            CLK_I               => CLK_I,
            RESET_I             => RESET_I, 
        
            MASTER_MOSI_I       => code_uc_0_mosi,
            MASTER_MISO_O       => code_uc_0_miso,
            
            SLAVE_BASE_I        => code_tcm_base,
            
            SLAVE_MOSI_O        => code_ctcm_arb_mosi,
            SLAVE_MISO_I        => code_ctcm_arb_miso
        );

        -- Arbiter: share Code TCM between Code and Data space accesses.
        -- note that Data accesses have priority necessarily.
        code_arbiter: entity work.ION_CTCM_ARBITER
        generic map (
            SLAVE_0_AREA_SIZE   => TCM_CODE_SIZE
        )
        port map (
            CLK_I               => CLK_I,
            RESET_I             => RESET_I, 
        
            MASTER_0_MOSI_I     => data_ctcm_arb_mosi,
            MASTER_0_MISO_O     => data_ctcm_arb_miso,
        
            MASTER_1_MOSI_I     => code_ctcm_arb_mosi,
            MASTER_1_MISO_O     => code_ctcm_arb_miso,
            
            SLAVE_MOSI_O        => code_tcm_mosi,
            SLAVE_MISO_I        => code_tcm_miso
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
            
            MEM_MOSI_I          => code_tcm_mosi,
            MEM_MISO_O          => code_tcm_miso
        );
    
    end generate tcm_code_present;

    tcm_code_missing:
    if TCM_CODE_SIZE = 0 generate
    
        code_uc_0_miso.mwait <= '0';
        code_uc_0_miso.rd_data <= (others => '0');
    
    end generate tcm_code_missing;
    
    
--------------------------------------------------------------------------------
-- Data Bus.

    -- Data cache ----------------------------------------------------------

    data_cache_present:
    if DATA_CACHE_LINES > 0 generate

        assert 1=0
        report "Data cache unimplemented, set DATA_CACHE_LINES => 0."
        severity failure;
        
    end generate data_cache_present;

    data_cache_missing:
    if DATA_CACHE_LINES = 0 generate

        data_uc_0_mosi <= data_cpu_mosi;
        data_cpu_miso <= data_uc_0_miso;
        
    end generate data_cache_missing;

    -- Data TCM ------------------------------------------------------------

    tcm_data_present:
    if TCM_DATA_SIZE > 0 generate

        data_mux_0: entity work.ION_BUS_MUX
        generic map (
            SLAVE_0_AREA_SIZE   => TCM_DATA_SIZE
        )
        port map (
            CLK_I               => CLK_I,
            RESET_I             => RESET_I, 

            MASTER_MOSI_I       => data_uc_0_mosi,
            MASTER_MISO_O       => data_uc_0_miso,
            
            SLAVE_0_BASE_I      => data_tcm_base,
            
            SLAVE_0_MOSI_O      => data_tcm_mosi,
            SLAVE_0_MISO_I      => data_tcm_miso,
            
            SLAVE_1_MOSI_O      => data_uc_1_mosi,
            SLAVE_1_MISO_I      => data_uc_1_miso
        );
        
        data_tcm: entity work.ION_TCM_DATA
        generic map (
            SIZE                => TCM_DATA_SIZE,
            INIT_DATA           => TCM_DATA_INIT
        )
        port map (
            CLK_I               => CLK_I,
            RESET_I             => RESET_I, 
            
            MEM_MOSI_I          => data_tcm_mosi,
            MEM_MISO_O          => data_tcm_miso
        );
    
    end generate tcm_data_present;

    tcm_data_missing:
    if TCM_DATA_SIZE = 0 generate
    
        data_uc_1_mosi <= data_uc_0_mosi;
        data_uc_0_miso <= data_uc_1_miso;
    
    end generate tcm_data_missing;

    data_mux_1: entity work.ION_BUS_MUX
    generic map (
        SLAVE_0_AREA_SIZE   => TCM_CODE_SIZE
    )
    port map (
        CLK_I               => CLK_I,
        RESET_I             => RESET_I, 
    
        MASTER_MOSI_I       => data_uc_1_mosi,
        MASTER_MISO_O       => data_uc_1_miso,
        
        -- Code TCM must be seen at the same address in both spaces.
        SLAVE_0_BASE_I      => code_tcm_base,
        
        SLAVE_0_MOSI_O      => data_ctcm_arb_mosi,
        SLAVE_0_MISO_I      => data_ctcm_arb_miso,
        
        SLAVE_1_MOSI_O      => data_uc_2_mosi,
        SLAVE_1_MISO_I      => data_uc_2_miso
    );
    
    
--------------------------------------------------------------------------------
-- Wishbone Bridge & access arbiter.

    -- FIXME there should be a wishbone bridge here, this is a synth stub.
    DATA_UC_WB_MOSI_O <= data_uc_2_mosi;
    data_uc_2_miso <= DATA_UC_WB_MISO_I;


end architecture rtl;
