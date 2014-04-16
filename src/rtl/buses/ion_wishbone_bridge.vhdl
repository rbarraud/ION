--------------------------------------------------------------------------------
-- ion_wishbone_bridge.vhdl -- Connects an ION bus master to a Wishbone bus.
--------------------------------------------------------------------------------
-- ION_WISHBONE_BRIDGE 
-- This bridge converts ION-bus signals to Wishbone signals ans vice-versa.
-- For the Wb-slaves, the bridge appears as the Wb-bus master.
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

use work.ION_INTERFACES_PKG.all;
use work.ION_INTERNAL_PKG.all;


entity ION_WISHBONE_BRIDGE is
    port(
		CLK_I               : in std_logic;
        RESET_I             : in std_logic;
        ION_MOSI_I          : in t_cpumem_mosi;
        ION_MISO_O          : out t_cpumem_miso;        
        WISHBONE_MOSI_O     : out t_wishbone_mosi;
        WISHBONE_MISO_I     : in t_wishbone_miso		
    );
end; 


architecture ION_WISHBONE_BRIDGE_arc of ION_WISHBONE_BRIDGE is

          
begin

    --WISHBONE_MOSI_O <= ION_MOSI_I;
    --ION_MISO_O <= WISHBONE_MISO_I;
	
	signal wishbone_ack    : std_logic;
	
	process (CLK_I, RESET_I, ION_MOSI_I.rd_en, ON_MOSI_I.wr_be, 
	         WISHBONE_MISO_I.ack)
	
		-- variable cyc_var : boolean := false;
		
		begin	
		
		    -- Signal to register the value of Wb-signal STALL_I
			stall_i_reg    : std_logic;
			
			-----------------------------------------------------------------
			-- Generate ION-bus o/p signals
			-----------------------------------------------------------------
			ION_MISO_O.rd_data <= WISHBONE_MISO_I.dat;
			ION_MISO_O.mwait   <= WISHBONE_MISO_I.stall;
			
			
			-----------------------------------------------------------------
			-- Generate Wishbone o/p signals
			-----------------------------------------------------------------
			WISHBONE_MOSI_O.adr <= ION_MOSI_I.addr;
			WISHBONE_MOSI_O.dat <= ION_MOSI_I.wr_data;
			WISHBONE_MOSI_O.tga <= ION_MOSI_I.wr_be;
			WISHBONE_MOSI_O.we  <= not(ION_MOSI_I.rd_en);
			
			-----------------------------------------------------------------
			-- Generate the Wb STROBE signal from valid read or write cycles
			-----------------------------------------------------------------
			if ((ION_MOSI_I.rd_en = '1' and ION_MOSI_I.wr_be /= '1111') or 
		    (ION_MOSI_I.rd_en = '0' and ION_MOSI_I.wr_be = '1111')) then
				WISHBONE_MOSI_O.stb <= '1';				
			else
			    WISHBONE_MOSI_O.stb <= '0';				
			end if;			
			
			-- Register the value of Wb signal STALL_I
			if (RESET_I = '0') then
			    stall_i_reg <= '0';
			else
			    if (CLK_I='1' and CLK_I'event) then
				    stall_i_reg <= WISHBONE_MISO_I.stall;
				end if;
			end if;	
		
			-----------------------------------------------------------------
			-- Generate the Wb CYCLIC signal from valid read/write cycles	
			-----------------------------------------------------------------
			if ((ION_MOSI_I.rd_en = '1' and ION_MOSI_I.wr_be /= '1111') or 
		    (ION_MOSI_I.rd_en = '0' and ION_MOSI_I.wr_be = '1111')) then
			    WISHBONE_MOSI_O.cyc <= '1';    
			-- Check the STALL & ACK inputs in case of invalid read/write 
			else			    
				-- If STALL was LOW in the previous clk cycle
			    if (stall_i_reg = '0') then
				    -- CYC is de-asserted only if ACK is de-asserted
				    if (WISHBONE_MISO_I.ack = '0') then
					    WISHBONE_MOSI_O.cyc <= '0';
					-- 	CYC remains asserted 
					else
					    WISHBONE_MOSI_O.cyc <= '1';
					end if;	
				-- If STALL was HIGH in previous clk cycle
				else 
       				WISHBONE_MOSI_O.cyc <= '1';
				end if;
			end if;	
			
		end process;

    
end architecture ION_WISHBONE_BRIDGE_arc;

