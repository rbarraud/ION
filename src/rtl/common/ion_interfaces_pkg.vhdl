--------------------------------------------------------------------------------
-- ION_INTERFACES_PKG.vhdl -- Data types used in the core interface.
--------------------------------------------------------------------------------
-- Needs to be imported by any module that instantiates an ion_core entity.
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

package ION_INTERFACES_PKG is

subtype t_word is std_logic_vector(31 downto 0);

type t_wishbone_mosi is record
    adr :               t_word; -- Address bus
    dat :               t_word; -- Write data bus
	-- Address tag type, contains information associated with the address bus
    tga :               std_logic_vector(3 downto 0);
	-- write enable, indicates if the current local bus cycle is a READ or WRITE
    we :                std_logic;
	-- Indicates that a valid bus cycle is in progress
    cyc :               std_logic;
	-- Strobe output indicates a valid data transfer cycle
    stb :               std_logic;
end record t_wishbone_mosi;

type t_wishbone_miso is record
    -- Acknowledge from Slave for normal termination of a bus cycle at Master
	ack :               std_logic;
    -- Pipeline stall input, indicates current slave is busy
	stall :             std_logic; 
	-- Read data bus
    dat :               t_word;  
	
end record t_wishbone_miso;

end package;

package body ION_INTERFACES_PKG is

    -- No package body is necessary.

end package body;
