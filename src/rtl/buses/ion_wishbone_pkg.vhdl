--------------------------------------------------------------------------------
-- ION_WISHBONE_PKG.vhdl -- Wishbone bus data types.
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

package ION_WISHBONE_PKG is

---- Interface types -----------------------------------------------------------

type t_wishbone_mosi is record
    adr :               std_logic_vector(31 downto 0);
    dat :               std_logic_vector(31 downto 0);
    sel :               std_logic_vector(3 downto 0);
    we :                std_logic;
    cyc :               std_logic;
    stb :               std_logic;
end record t_wishbone_mosi;

type t_wishbone_miso is record
    ack :               std_logic;
    dat :               std_logic_vector(31 downto 0);
end record t_wishbone_miso;

end package;

package body ION_WISHBONE_PKG is

end package body;
