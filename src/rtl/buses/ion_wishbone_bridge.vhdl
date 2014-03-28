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

--use work.ION_INTERFACES_PKG.all;
--use work.ION_INTERNAL_PKG.all;


entity ION_WISHBONE_BRIDGE is
    port(
		--CLK_I               : in std_logic;
        --RESET_I             : in std_logic;
        --ION_MOSI_I          : in t_cpumem_mosi;
        --ION_MISO_O          : out t_cpumem_miso;        
        --WISHBONE_MOSI_O     : out t_wishbone_mosi;
        --WISHBONE_MISO_I     : in t_wishbone_miso
		
		-- ION-bus ports
		-- MOSI
		ION_addr		: in std_logic_vector(31 downto 0); -- Address bus
		ION_rd_en		: in std_logic;					    -- Read Enable	
		ION_wr_be		: in std_logic_vector(3 downto 0);  -- Write Byte Enable. Bit 0 is for wr_data[7..0]
		ION_wr_data     : in std_logic_vector(31 downto 0); -- Write data bus
		-- MISO
		ION_rd_data     : out std_logic_vector(31 downto 0); -- Read data bus
		ION_mwait       : out std_logic;	                 -- Asserted to stall a read or write cycle
		
		-- Wishbone ports
		--CLK_I           : in std_logic;						-- System Interconnect clock
		--RST_I			: in std_logic;						-- Reset input forces the WISHBONE interface to restart
		DAT_I			: in std_logic_vector(31 downto 0); -- Read data bus
		STALL_I			: in std_logic;						-- Pipeline stall input, indicates current slave is busy
		ACK_I			: in std_logic;						-- Acknowledge from Slave for normal termination of a bus cycle at Master
		
		ADR_O			: out std_logic_vector(31 downto 0); -- Address bus
		DAT_O			: out std_logic_vector(31 downto 0); -- Write data bus
		TGA_O			: out std_logic_vector(3 downto 0);  -- Address tag type, contains information associated with the address bus
		WE_O			: out std_logic;					 -- write enable output, indicates if the current local bus cycle is a READ or WRITE cycle	
		STB_O			: out std_logic;					 -- Strobe output indicates a valid data transfer cycle
		CYC_O			: out std_logic;					 -- Indicates that a valid bus cycle is in progress
    );
end; 


architecture ION_WISHBONE_BRIDGE_arc of ION_WISHBONE_BRIDGE is

          
begin

    -- FIXME This is a total fake! it's a placeholder until real stuff is done.

    --WISHBONE_MOSI_O <= ION_MOSI_I;
    --ION_MISO_O <= WISHBONE_MISO_I;
	
	process (ION_addr, ACK_I)
	
		begin
			-- Conversion to ION-bus signals
			ION_rd_data <= DAT_I;
			ION_mwait   <= STALL_I;
			
			-- Conversion to Wishbone-bus signals
			ADR_O <= ION_addr;
			DAT_O <= ION_wr_data;
			TGA_O <= ION_wr_be;
			WE_O  <= not(ION_rd_en);
			
			STB_O
			
			CYC_O 
			
		end process;

    
end architecture ION_WISHBONE_BRIDGE_arc;

