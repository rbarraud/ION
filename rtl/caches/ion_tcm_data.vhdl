--------------------------------------------------------------------------------
-- ion_tcm_data.vhdl -- Tightly Coupled Memory for the data space.
--------------------------------------------------------------------------------
-- FIXME explain!
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


entity ION_TCM_DATA is
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

architecture rtl of ION_TCM_DATA is

constant TCM_ADDR_SIZE : integer := log2(SIZE);

subtype t_tcm_address is std_logic_vector(TCM_ADDR_SIZE-1 downto 2);

signal tcm_addr :           t_tcm_address;
signal tcm_rd_data :        t_word;

signal tcm_rd_data0 :       t_byte;
signal tcm_rd_data1 :       t_byte;
signal tcm_rd_data2 :       t_byte;
signal tcm_rd_data3 :       t_byte;
signal wr_data0 :           t_byte;
signal wr_data1 :           t_byte;
signal wr_data2 :           t_byte;
signal wr_data3 :           t_byte;

                            -- FIXME initial value is not being loaded
signal tcm_ram0:            t_byte_table(0 to ((SIZE/4)-1)) := 
                            (others => X"00");
                            -- we need new version of this function:
                            --objcode_to_btable(INIT_DATA, SIZE, 0);
signal tcm_ram1:            t_byte_table(0 to ((SIZE/4)-1)) := 
                            (others => X"00");
signal tcm_ram2:            t_byte_table(0 to ((SIZE/4)-1)) := 
                            (others => X"00");
signal tcm_ram3:            t_byte_table(0 to ((SIZE/4)-1)) := 
                            (others => X"00");

          
begin
 
 
tcm_addr <= MEM_MOSI_I.addr(tcm_addr'high downto 2);


--------------------------------------------------------------------------------
---- Memory block inference.


-- FIXME byte enables missing!
tcm_memory_block0:
process(CLK_I)
begin
    if (CLK_I'event and CLK_I='1') then
        tcm_rd_data0 <= tcm_ram0(conv_integer(tcm_addr));
        if MEM_MOSI_I.wr_be(0)='1' then
            tcm_ram0(conv_integer(unsigned(tcm_addr))) <= wr_data0;
        end if;
    end if;
end process tcm_memory_block0;

tcm_memory_block1:
process(CLK_I)
begin
    if (CLK_I'event and CLK_I='1') then
        tcm_rd_data1 <= tcm_ram1(conv_integer(tcm_addr));
        if MEM_MOSI_I.wr_be(1)='1' then
            tcm_ram1(conv_integer(unsigned(tcm_addr))) <= wr_data1;
        end if;
    end if;
end process tcm_memory_block1;

tcm_memory_block2:
process(CLK_I)
begin
    if (CLK_I'event and CLK_I='1') then
        tcm_rd_data2 <= tcm_ram2(conv_integer(tcm_addr));
        if MEM_MOSI_I.wr_be(2)='1' then
            tcm_ram2(conv_integer(unsigned(tcm_addr))) <= wr_data2;
        end if;
    end if;
end process tcm_memory_block2;

tcm_memory_block3:
process(CLK_I)
begin
    if (CLK_I'event and CLK_I='1') then
        tcm_rd_data3 <= tcm_ram3(conv_integer(tcm_addr));
        if MEM_MOSI_I.wr_be(3)='1' then
            tcm_ram3(conv_integer(unsigned(tcm_addr))) <= wr_data3;
        end if;
    end if;
end process tcm_memory_block3;

wr_data0 <= MEM_MOSI_I.wr_data( 7 downto  0);
wr_data1 <= MEM_MOSI_I.wr_data(15 downto  8);
wr_data2 <= MEM_MOSI_I.wr_data(23 downto 16);
wr_data3 <= MEM_MOSI_I.wr_data(31 downto 24);

MEM_MISO_O.rd_data <= tcm_rd_data3 & tcm_rd_data2 & tcm_rd_data1 & tcm_rd_data0;
MEM_MISO_O.mwait <= '0';

end architecture rtl;
