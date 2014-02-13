--------------------------------------------------------------------------------
-- ion_wishbone_bridge.vhdl -- Connects an ION bus master to a Wishbone bus.
--------------------------------------------------------------------------------
-- ION_WISHBONE_BRIDGE 
--
--
-- REFERENCES
--
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


entity ION_WISHBONE_BRIDGE is
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        ION_MOSI_I          : in t_cpumem_mosi;
        ION_MISO_O          : out t_cpumem_miso;
        
        WISHBONE_MOSI_O     : out t_wishbone_mosi;
        WISHBONE_MISO_O     : out t_wishbone_miso
    );
end;

architecture rtl of ION_WISHBONE_BRIDGE is

          
begin

    -- FIXME This is a total fake! it's a placeholder until real stuff is done.

    WISHBONE_MOSI_O.adr <= ION_MOSI_I.addr;

    
end architecture rtl;

