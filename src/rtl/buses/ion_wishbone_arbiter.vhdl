--------------------------------------------------------------------------------
-- ion_wishbone_arbiter.vhdl -- Simple arbiter for ION refill ports.
--------------------------------------------------------------------------------
--
-- This is not a general purpose WB arbiter; it is meant to share a single 
-- external memory interface between the two refill ports of the ION core,
-- data and code.
--
-- The data port is given priority: when a cycle is requested on the data port, 
-- it will be given control as as soon as any ongoing cycle on the code
-- port is finished (as signalled by deassertion of the WB CYC signal).
-- The data port will lose control as soon as its cycle is over.
-- This scheme has no memory: the above is the only rule.
-- This works because both ports will have gaps between successive refills,
-- and because the ports are not going to lock each other: if the code bus 
-- starved, the data cache would eventually stop issuing data cycles.
--
-- REFERENCES
-- [1] ion_design_notes.pdf -- ION project design notes.
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


entity ION_WISHBONE_ARBITER is
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        -- Connect to core code refill port.
        CODE_MOSI_I         : in t_wishbone_mosi;
        CODE_MISO_O         : out t_wishbone_miso;

        -- Connect to core data refill port.
        DATA_MOSI_I         : in t_wishbone_mosi;
        DATA_MISO_O         : out t_wishbone_miso;
        
        -- Connect to memory interface.
        MEM_MOSI_0          : out t_wishbone_mosi;
        MEM_MISO_I          : in t_wishbone_miso
    );
end;

architecture rtl of ION_WISHBONE_ARBITER is

signal data_port_selected : std_logic;

begin


    ----------------------------------------------------------------------------
    -- Arbitration state machine.

    -- Perhaps calling this a "state machine" is giving it too much credit 
    -- but the simplicity is intended.
    -- We know there are going to be inactive gaps in both buses as cache hits
    -- are served; we rely on those gaps to switch masters.
    selection_register:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then 
                data_port_selected <= '0';
            else
                if data_port_selected =  '0' then
                    -- Select data port as soon as there is a data cycle pending 
                    -- AND the code port is inactive.
                    -- (So we won't break an ongoing CODE cycle.)
                    if DATA_MOSI_I.cyc = '1' and CODE_MOSI_I.cyc = '0' then
                        data_port_selected <= '1';
                    end if;
                else
                    -- Deselect data port as soon as an ongoing data cycle ends.
                    -- (So we won't break an ongoing DATA cycle.)
                    if DATA_MOSI_I.cyc = '0' then
                        data_port_selected <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process selection_register;

    ----------------------------------------------------------------------------
    -- Bus multiplexors.

    -- The memory MOSI is multiplexed according to the selected master port.
    with data_port_selected select MEM_MOSI_0 <=
        DATA_MOSI_I     when '1',
        CODE_MOSI_I     when others;
    
    -- The DATA master port MISO will be connected to the memory MISO as long
    -- as it is selected, otherwise it is stalled.
    with data_port_selected select DATA_MISO_O.ack <=
        MEM_MISO_I.ack      when '1',
        '0'                 when others;

    with data_port_selected select DATA_MISO_O.stall <=
        MEM_MISO_I.stall    when '1',
        '1'                 when others;
        
    DATA_MISO_O.dat <= MEM_MISO_I.dat;

    -- The CODE master port MISO will be connected to the memory MISO as long
    -- as it is selected, otherwise it is stalled.
    with data_port_selected select CODE_MISO_O.ack <=
        MEM_MISO_I.ack      when '0',
        '0'                 when others;

    with data_port_selected select CODE_MISO_O.stall <=
        MEM_MISO_I.stall    when '0',
        '1'                 when others;
        
    CODE_MISO_O.dat <= MEM_MISO_I.dat;
    

end architecture rtl;
