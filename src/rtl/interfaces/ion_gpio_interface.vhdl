--------------------------------------------------------------------------------
-- ion_gpio_interface.vhdl -- Simple GPIO block with WB interface.
--------------------------------------------------------------------------------
--
-- This module provides a number N (currently hardwired to N=1) of input/output
-- port pairs of configurable width PORT_WIDTH.
-- Each port has an output port and an input port, each PORT_WIDTH bits wide.
-- 
-- Output ports are write only since they share the same address with the read
-- register of the pair. 
--
-- Read ports are registered (a single register per input) but you may want to 
-- supply extra registers for protection against metastability.
--
-- Only the lower bits of the data are significan when writing, and when 
-- reading all bits above PORT_WIDTH will read as zero.
--
-- REFERENCES
-- [1] ion_design_notes.pdf -- ION project design notes.
--------------------------------------------------------------------------------
-- REGISTER MAP:
--
-- When EN_I is asserted, bits 3 to 2 of the address will be decoded as this:
-- 
-- 00 write   : Writes to GPIO_0_OUT
-- 00 read    : Reads from GPIO_0_IN
-- 1x, x1     : Undefined
--------------------------------------------------------------------------------
-- THINGS TO BE DONE:
-- 
-- Eventually, a set/reset register will be added for each output port. This 
-- is why the width is limited to 16 bits.
-- Also eventually the number of ports will be configurable.
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


entity ION_GPIO_INTERFACE is
    generic(
        -- Width of all GPIO ports in bits (1 to 16)
        PORT_WIDTH : natural        := 16
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        -- Core WB interface (this module is a WB slave).
        WB_MOSI_I           : in t_wishbone_mosi;
        WB_MISO_O           : out t_wishbone_miso;
        -- Enable: WB ignored unless this input is asserted.
        EN_I                : in std_logic;

        -- I/O ports (always in pairs).
        GPIO_0_O            : out std_logic_vector(PORT_WIDTH-1 downto 0);
        GPIO_0_I            : in std_logic_vector(PORT_WIDTH-1 downto 0)
    );
end;

architecture rtl of ION_GPIO_INTERFACE is

subtype t_port is std_logic_vector(PORT_WIDTH-1 downto 0);

signal port0_inp_reg :      t_port;

begin
    
    -- Make sure the generic value is within bounds.
    assert (PORT_WIDTH >= 1) and (PORT_WIDTH <= 16)
    report "Invalid port width value for ION_GPIO_INTERFACE module."
    severity failure;

    -- Eventually this will be parameterizable and we'll have a generate loop
    -- here with several registers. for the time being we have only the one.

    port_0_output_reg:
    process(CLK_I)
    begin
       if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                GPIO_0_O <= (others => '0');
            elsif WB_MOSI_I.cyc = '1' and WB_MOSI_I.we = '1' and EN_I='1' then
                GPIO_0_O <= WB_MOSI_I.dat(PORT_WIDTH-1 downto 0);
            end if;
        end if;
    end process port_0_output_reg;

    port_0_input_reg:
    process(CLK_I)
    begin
       if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                port0_inp_reg <= (others => '0');
            else
                port0_inp_reg <= GPIO_0_I;
            end if;
        end if;
    end process port_0_input_reg;

    -- WB interface ------------------------------------------------------------

    -- No need to multiplex output data for the time being.
    WB_MISO_O.dat(31 downto PORT_WIDTH) <= (others => '0');
    WB_MISO_O.dat(PORT_WIDTH-1 downto 0) <= port0_inp_reg;
    -- No wait states.
    WB_MISO_O.stall <= '0';
    WB_MISO_O.ack <= '1';

end architecture rtl;
