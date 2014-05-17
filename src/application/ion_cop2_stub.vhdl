--------------------------------------------------------------------------------
-- ion_cop2_stub.vhdl -- Dummy COP2 for test purposes.
--------------------------------------------------------------------------------
-- 
-- This is a dummy COP2 meant to serve two purposes:
--  -# Support the tests for COP2 functionality.
--  -# Provide a working example for the implementation of the COP2 interface.
--
-- FUNCTIONALITY:
-- 
-- This COP2 stub provides only just enough functionality to test the COP2 
-- interface, it's not meant to do any useful work. 
-- This is what this module does at the moment:
--
-- -# Register bank with 16 32-bit general purpose registers.
-- -# Register bank with 16 32-bit general purpose registers.
--    (Both implemented in a single BRAM.)
-- -# "Sel" field is written to top 3 bits of register when writing.
-- -# "Sel" field is ignored on reads.
-- -# Operation fields are ignored.
--
-- FIXME cover all the COP2 interface including function codes.
--
-- REFERENCES
-- [1] ion_design_notes.pdf -- ION project design notes.
-- [1] ion_core.pdf -- ION core datasheet.
--------------------------------------------------------------------------------
--
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


entity ION_COP2_STUB is
    generic(
        -- Size of TCM block in 32-bit words. Set to zero to disable TCM.
        SIZE : integer := 4096;
        -- Initial contents of TCM. Default is zeros.
        INIT_DATA : t_obj_code := zero_objcode(16)
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;
        
        CPU_MOSI_I          : in t_cop2_mosi;
        CPU_MISO_O          : out t_cop2_miso
    );
end;

architecture rtl of ION_COP2_STUB is

signal rbank :              t_rbank := (others => X"00000000");

signal rs_rbank :           t_word;
signal rbank_wr_data :      t_word;
signal rbank_we :           std_logic;
signal rbank_wr_addr :      t_regnum;
signal rbank_rd_addr :      t_regnum;

-- IMPORTANT: This attribute is used by Xilinx tools to select how to implement
-- the register bank. If we don't use it, by default XST would infer 1 BRAMs for
-- the 1024-bit 2-port reg bank, which we don't want.
-- This can take the values {distributed|block}.
attribute ram_style :       string;
attribute ram_style of rbank : signal is "distributed";


          
begin
    
    -- Connect the register bank adress inputs straight to the MOSI.
    rbank_we <= CPU_MOSI_I.reg_wr_en;
    rbank_wr_addr <= 
        CPU_MOSI_I.reg_wr.control & 
        CPU_MOSI_I.reg_wr.index(3 downto 0);
    rbank_rd_addr <= 
        CPU_MOSI_I.reg_rd.control & 
        CPU_MOSI_I.reg_rd.index(3 downto 0);

    -- When reading regular registers (as opposed to control), put the SEL 
    -- field in the high 3 bits so we at least have some way to check the 
    -- connection. This will have to be improved...
    with CPU_MOSI_I.reg_wr.control select rbank_wr_data <= 
        CPU_MOSI_I.reg_wr.sel & CPU_MOSI_I.data(28 downto 0)    when '0',
        CPU_MOSI_I.data                                         when others;
    

    -- Register bank as double-port RAM. Should synth to 1 BRAM unless you use
    -- synth attributes to prevent it (see 'ram_style' attribute above) or your
    -- FPGA has no BRAMs.
    -- This is a near-identical copy-paste of the main CPU reg bank.
    synchronous_reg_bank:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if rbank_we='1' then 
                rbank(conv_integer(rbank_wr_addr)) <= rbank_wr_data;
            end if;

            rs_rbank <= rbank(conv_integer(rbank_rd_addr));
        end if;
    end process synchronous_reg_bank;    

    
    CPU_MISO_O.stall <= '0';
    CPU_MISO_O.data <= rs_rbank;
    
    
end architecture rtl;
