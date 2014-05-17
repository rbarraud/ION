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
    -- Byte lane selection. 3 is MSB, 0 is LSB.
    sel :               std_logic_vector(3 downto 0);
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


type t_cop2_regsel is record
    index :     std_logic_vector(4 downto 0);   -- Reg index.
    sel :       std_logic_vector(2 downto 0);   -- Reg sel field.
    control :   std_logic;          -- Addressing control register.
end record t_cop2_regsel;

type t_cop2_mosi is record
    cofun25_en :    std_logic;          -- Execute 25-bit function.
    cofun16_en :    std_logic;          -- Execute 16-bit function.
    reg_wr_en :     std_logic;          -- Write to COP2 register.
    reg_rd_en :     std_logic;          -- Read from COP2 register.
    cofun :         std_logic_vector(24 downto 0);  -- Function code.
    reg_rd :        t_cop2_regsel;      -- COP2 register to be read.
    reg_wr :        t_cop2_regsel;      -- COP2 register to be written to.
    data :          t_word;             -- Data to be written to COP2.
    stall :         std_logic;          -- Stall write to COP2.
end record t_cop2_mosi;

type t_cop2_miso is record
    stall :         std_logic;          -- Stall CPU pipeline.
    data :          t_word;             -- Data read from COP2 register.
end record t_cop2_miso;

end package;

package body ION_INTERFACES_PKG is

    -- No package body is necessary.

end package body;
