--------------------------------------------------------------------------------
-- ion_ctcm_arbiter.vhdl -- Arbiter for access to CTCM from data & code buses.
--------------------------------------------------------------------------------
-- This is a minimalistic arbiter meant to enable access to the code TCM from
-- both the code and data buses, for both read and write.
-- The code TCM needs to be accessible so that the SW can load code into it 
-- and so that the SW can access its constants without resorting to linker 
-- trickery.
-- 
-- Note that this stuff only works for masters that don´t produce any wait
-- states themselves, like the code TCM. 
-- Also, the data port is always given priority over the code port.
-- This is NOT a generic arbiter nor a good starting point for one!
--
-- REFERENCES
-- [1] ion_notes.pdf -- ION project design notes.
--------------------------------------------------------------------------------
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

-- IMPORTANT: This is NOT a GENERAL ION BUS ARBITER; it does not pass along the 
-- slave wait line. It works with the Code TCM but will fail with other slaves.
-- Also, it's tailored for Data and Code master ports.
entity ION_CTCM_ARBITER is
    generic(
        -- Size of memory area occupied by slave 0 in bytes.
        SLAVE_0_AREA_SIZE : integer := 4096
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        MASTER_D_CE_I       : in std_logic;
        MASTER_D_MOSI_I     : in t_cpumem_mosi;
        MASTER_D_MISO_O     : out t_cpumem_miso;

        MASTER_C_CE_I       : in std_logic;
        MASTER_C_MOSI_I     : in t_cpumem_mosi;
        MASTER_C_MISO_O     : out t_cpumem_miso;
        
        SLAVE_MOSI_O        : out t_cpumem_mosi;
        SLAVE_MISO_I        : in t_cpumem_miso
    );
end;

architecture rtl of ION_CTCM_ARBITER is

-- Asserted when both masters attempt to access the slave in the same cycle.
signal clash :              std_logic;
signal clash_reg :          std_logic;

signal data_request :       std_logic;
signal code_request :       std_logic;

          
begin
 
    ----------------------------------------------------------------------------
    ---- Arbitration logic.
    
    -- Figure up when the masters are actually using the port.
    data_request <= 
        '1' when MASTER_D_MOSI_I.rd_en='1' else
        '1' when MASTER_D_MOSI_I.wr_be /="0000" else
        '0';

    code_request <= 
        '1' when MASTER_C_MOSI_I.rd_en='1' else
        '0';

    -- when both masters attempt an access on the same cycle we have a clash.
    clash <= (MASTER_D_CE_I and data_request) and 
             (MASTER_C_CE_I and code_request);
    
    -- We need to register a clash because we have to wait the code for two
    -- cycles, clash and clash+1.
    -- FIXME this is not necessary, test it with a single wait.
    process(CLK_I)
    begin
        if (CLK_I'event and CLK_I='1') then
            if RESET_I='1' then 
                clash_reg <= '0';
            else
                clash_reg <= clash;
            end if;
        end if;
    end process;
        
    -- MOSI is combinationally multiplexed giving priority to the data port.
    SLAVE_MOSI_O <= 
        MASTER_D_MOSI_I when MASTER_D_CE_I='1' and data_request='1' else
        MASTER_C_MOSI_I;

    -- The data mosi comes straight from the slave.
    MASTER_D_MISO_O <= SLAVE_MISO_I;
    
    -- The code port will be stalled during a clash cycle.
    MASTER_C_MISO_O.rd_data <= SLAVE_MISO_I.rd_data;
    MASTER_C_MISO_O.mwait <= clash or clash_reg;
    

end architecture rtl;
