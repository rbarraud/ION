--------------------------------------------------------------------------------
-- ion_tcm_code.vhdl -- Tightly Coupled Memory.
--------------------------------------------------------------------------------
-- Tightly Coupled Memory for code space.
-- This block is meant to contain code so it has no byte enables -- see comments
-- for module ION_TCM_CODE for an explanation about why this is a good thing.
--
-- TODO is mips16 is ever implemented, some byte enables might be needed.
--
-- REFERENCES
-- [1] ion_design_notes.pdf -- ION project design notes.
--------------------------------------------------------------------------------
--
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


entity ION_TCM_CODE is
    generic(
        -- Size of TCM block in bytes. Set to zero to disable TCM.
        SIZE : integer := 4096;
        -- Initial contents of TCM. Default is zeros.
        INIT_DATA : t_obj_code := zero_objcode(4096)
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        MEM_MOSI_I          : in t_cpumem_mosi;
        MEM_MISO_O          : out t_cpumem_miso
    );
end;

architecture rtl of ION_TCM_CODE is

constant TCM_ADDR_SIZE : integer := log2(SIZE);

subtype t_tcm_address is std_logic_vector(TCM_ADDR_SIZE-1 downto 2);

signal tcm_addr :           t_tcm_address;
signal tcm_rd_data :        t_word;

-- TCM memory block, initialized with constant data table.
signal tcm_ram :            t_word_table(0 to ((SIZE)-1)) := 
                            objcode_to_wtable(INIT_DATA, SIZE);

          
begin
 
 
tcm_addr <= MEM_MOSI_I.addr(tcm_addr'high downto 2);


--------------------------------------------------------------------------------
---- Memory block inference.

tcm_memory_block:
process(CLK_I)
begin
    if (CLK_I'event and CLK_I='1') then
        tcm_rd_data <= tcm_ram(conv_integer(tcm_addr));
        if MEM_MOSI_I.wr_be/="0000" then
            tcm_ram(conv_integer(unsigned(tcm_addr))) <= MEM_MOSI_I.wr_data;
        end if;
    end if;
end process tcm_memory_block;

MEM_MISO_O.rd_data <= tcm_rd_data;
MEM_MISO_O.mwait <= '0';

end architecture rtl;
