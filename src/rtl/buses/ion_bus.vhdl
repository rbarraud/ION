--------------------------------------------------------------------------------
-- ion_bus.vhdl -- ION Bus multiplexors and auxiliary blocks.
--------------------------------------------------------------------------------
-- ION_BUS_MUX -- Bus multiplexor (1 master, 2 slaves).
--
-- Use this module to connect a master to two slaves. 
-- Slave 0 will only be selected if the target address is within the target 
-- area as defined by the SIZE generic and the SLAVE_0_BASE_I address input. 
-- It will have its address capped to SIZE.
-- Slave 1 will be selected otherwise, and the address will not be modified.
-- In both cases the non-selected slave will get its enable signals zeroed.
--
-- REFERENCES
-- [1] ion_design_notes.pdf -- ION project design notes.
--------------------------------------------------------------------------------
-- KNOWN BUGS AND CAVEATS:
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


entity ION_BUS_MUX is
    generic(
        -- Size of memory area occupied by slave 0 in bytes.
        SLAVE_0_AREA_SIZE : integer := 4096
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        MASTER_MOSI_I       : in t_cpumem_mosi;
        MASTER_MISO_O       : out t_cpumem_miso;
        
        SLAVE_0_BASE_I      : in t_word;
        
        SLAVE_0_MOSI_O      : out t_cpumem_mosi;
        SLAVE_0_MISO_I      : in t_cpumem_miso;
        
        SLAVE_1_MOSI_O      : out t_cpumem_mosi;
        SLAVE_1_MISO_I      : in t_cpumem_miso
    );
end;

architecture rtl of ION_BUS_MUX is

constant MATCH_ADDR_SIZE : integer := log2(SLAVE_0_AREA_SIZE);

subtype t_match_address is std_logic_vector(MATCH_ADDR_SIZE-1 downto 2);

signal slave0_addr :        t_match_address;
signal slave0_ce :          std_logic;
signal slave0_ce_reg :      std_logic;

constant HI :               integer := slave0_addr'high;
          
begin
 
--------------------------------------------------------------------------------
---- Address decoding.
 
slave0_addr <= MASTER_MOSI_I.addr(slave0_addr'high downto 2);

slave0_ce <= 
    '1' when MASTER_MOSI_I.addr(31 downto slave0_addr'high+1) = 
             SLAVE_0_BASE_I(31 downto slave0_addr'high+1) 
    else '0';

registered_ce:
process(CLK_I)
begin
    if (CLK_I'event and CLK_I='1') then
        slave0_ce_reg <= slave0_ce;
    end if;
end process registered_ce;

--------------------------------------------------------------------------------
---- MOSI passthrough, MISO multiplexor.

-- Slave 1 sees the master bus address unmodified and the enables filtered.
SLAVE_1_MOSI_O.addr <= MASTER_MOSI_I.addr;
SLAVE_1_MOSI_O.wr_data <= MASTER_MOSI_I.wr_data;
SLAVE_1_MOSI_O.wr_be <= MASTER_MOSI_I.wr_be when slave0_ce='0' else "0000";
SLAVE_1_MOSI_O.rd_en <= MASTER_MOSI_I.rd_en when slave0_ce='0' else '0';

-- Slave 0 will have its enable signals filtered AND the address capped to SIZE.
SLAVE_0_MOSI_O.addr(HI downto 0) <= MASTER_MOSI_I.addr(HI downto 0);
SLAVE_0_MOSI_O.addr(31 downto HI+1) <= (others => '0');
SLAVE_0_MOSI_O.wr_data <= MASTER_MOSI_I.wr_data;
SLAVE_0_MOSI_O.wr_be <= MASTER_MOSI_I.wr_be when slave0_ce='1' else "0000";
SLAVE_0_MOSI_O.rd_en <= MASTER_MOSI_I.rd_en when slave0_ce='1' else '0';

-- MISO multiplexor controlled by registered CE; see ION bus chronograms.
with slave0_ce_reg select MASTER_MISO_O <= 
    SLAVE_0_MISO_I      when '1',
    SLAVE_1_MISO_I      when others;

end architecture rtl;


--##############################################################################


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.ION_MAIN_PKG.all;


entity ION_CACHE_MUX is
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        MASTER_MOSI_I       : in t_cpumem_mosi;
        MASTER_MISO_O       : out t_cpumem_miso;
        
        K0_CACHED_IN        : in std_logic;
        
        CACHED_MOSI_O       : out t_cpumem_mosi;
        CACHED_MISO_I       : in t_cpumem_miso;
        
        UNCACHED_MOSI_O     : out t_cpumem_mosi;
        UNCACHED_MISO_I     : in t_cpumem_miso
    );
end;

architecture rtl of ION_CACHE_MUX is

signal cached_ce :          std_logic;
signal cached_ce_reg :      std_logic;

begin

cached_ce <= 
    '0' when MASTER_MOSI_I.addr(31 downto 29) = "101" else
    '0' when MASTER_MOSI_I.addr(31 downto 29) = "100" and K0_CACHED_IN='0' else
    '1';

registered_ce:
process(CLK_I)
begin
    if (CLK_I'event and CLK_I='1') then
        cached_ce_reg <= cached_ce;
    end if;
end process registered_ce;

--------------------------------------------------------------------------------
---- MOSI passthrough, MISO multiplexor.

-- Both slave ports have their signals filtered and are otherwise unaltered.

UNCACHED_MOSI_O.addr <= MASTER_MOSI_I.addr;
UNCACHED_MOSI_O.wr_data <= MASTER_MOSI_I.wr_data;
UNCACHED_MOSI_O.wr_be <= MASTER_MOSI_I.wr_be when cached_ce='0' else "0000";
UNCACHED_MOSI_O.rd_en <= MASTER_MOSI_I.rd_en when cached_ce='0' else '0';

CACHED_MOSI_O.addr <= MASTER_MOSI_I.addr;
CACHED_MOSI_O.wr_data <= MASTER_MOSI_I.wr_data;
CACHED_MOSI_O.wr_be <= MASTER_MOSI_I.wr_be when cached_ce='1' else "0000";
CACHED_MOSI_O.rd_en <= MASTER_MOSI_I.rd_en when cached_ce='1' else '0';

-- MISO multiplexor controlled by registered CE; see ION bus chronograms.
with cached_ce_reg select MASTER_MISO_O <= 
    CACHED_MISO_I       when '1',
    UNCACHED_MISO_I     when others;

end rtl;

--##############################################################################


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.ION_MAIN_PKG.all;

-- IMPORTANT: This is NOT a GENERAL ION BUS ARBITER; it does not pass along the 
-- slave wait line. It works with the Code TCM but will fail with other slaves.
-- Also, it's tailored for Data and Code master ports -- see registered MISO_0.
entity ION_CTCM_ARBITER is
    generic(
        -- Size of memory area occupied by slave 0 in bytes.
        SLAVE_0_AREA_SIZE : integer := 4096
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        MASTER_0_MOSI_I     : in t_cpumem_mosi;
        MASTER_0_MISO_O     : out t_cpumem_miso;

        MASTER_1_MOSI_I     : in t_cpumem_mosi;
        MASTER_1_MISO_O     : out t_cpumem_miso;
        
        SLAVE_MOSI_O        : out t_cpumem_mosi;
        SLAVE_MISO_I        : in t_cpumem_miso
    );
end;

architecture rtl of ION_CTCM_ARBITER is

signal master0_ce :         std_logic;
signal master0_ce_reg :     std_logic_vector(1 downto 0);
signal master0_request :    std_logic;
signal master0_selected :   std_logic;
signal master1_request :    std_logic;
signal master1_selected :   std_logic;
          
begin
 
--------------------------------------------------------------------------------
---- Address decoding.

master0_ce <=
    '1' when MASTER_0_MOSI_I.wr_be /= "0000" else 
    '1' when MASTER_0_MOSI_I.rd_en = '1' else 
    '0';

registered_ce:
process(CLK_I)
begin
    if (CLK_I'event and CLK_I='1') then
        if RESET_I='1' then 
            master0_ce_reg <= "00";
        else
            master0_ce_reg(0) <= master0_ce;
            master0_ce_reg(1) <= master0_ce_reg(0);
        end if;
    end if;
end process registered_ce;

master0_selected <= master0_ce or master0_ce_reg(0);
master0_request <= 
    '1' when MASTER_0_MOSI_I.rd_en='1' else
    '1' when MASTER_0_MOSI_I.wr_be /="0000" else
    '0';
master1_selected <= not master0_selected;
master1_request <= 
    '1' when MASTER_1_MOSI_I.rd_en='1' else
    '1' when MASTER_1_MOSI_I.wr_be /="0000" else
    '0';

--------------------------------------------------------------------------------
---- MOSI & MISO multiplexors.

SLAVE_MOSI_O <= 
    MASTER_0_MOSI_I when master0_ce='1' else
    MASTER_1_MOSI_I;

registered_miso:
process(CLK_I)
begin
    if (CLK_I'event and CLK_I='1') then
        if master0_ce_reg(0)='1' then
            MASTER_0_MISO_O.rd_data <= SLAVE_MISO_I.rd_data;
        end if;
    end if;
end process registered_miso;    

-- FIXME we're not passing along the input MISO wait lines! not for general use!

-- FIXME explain: DATA_MISO needs the data stable 2 cycles AFTER rd_en is 
-- deasserted: the normal cycle and one extra used on load_interlock.
MASTER_0_MISO_O.mwait <= master0_ce_reg(0);
    
MASTER_1_MISO_O.rd_data <= SLAVE_MISO_I.rd_data;
MASTER_1_MISO_O.mwait <= master0_ce_reg(1); --master0_ce or 

end architecture rtl;

--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.ION_MAIN_PKG.all;


entity ION_BUS_DECODER is
    generic(
        -- Size of memory area occupied by slave 0 in bytes.
        SLAVE_AREA_SIZE : integer := 4096
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        MASTER_MOSI_I       : in t_cpumem_mosi;
        MASTER_MISO_O       : out t_cpumem_miso;
        
        SLAVE_BASE_I        : in t_word;
        
        SLAVE_MOSI_O        : out t_cpumem_mosi;
        SLAVE_MISO_I        : in t_cpumem_miso
    );
end;

architecture rtl of ION_BUS_DECODER is

constant MATCH_ADDR_SIZE : integer := log2(SLAVE_AREA_SIZE);

subtype t_match_address is std_logic_vector(MATCH_ADDR_SIZE-1 downto 2);

signal slave_addr :         t_match_address;
signal slave_ce :           std_logic;

constant HI :               integer := slave_addr'high;
          
begin
 
--------------------------------------------------------------------------------
---- Address decoding.
 
slave_addr <= MASTER_MOSI_I.addr(slave_addr'high downto 2);

slave_ce <= 
    '1' when MASTER_MOSI_I.addr(31 downto slave_addr'high+1) = 
             SLAVE_BASE_I(31 downto slave_addr'high+1) 
    else '0';

--------------------------------------------------------------------------------
---- MOSI passthrough, MISO multiplexor.

-- Slave 0 will have its enable signals filtered, other signals unmodified.
SLAVE_MOSI_O.addr <= MASTER_MOSI_I.addr;
SLAVE_MOSI_O.wr_data <= MASTER_MOSI_I.wr_data;
SLAVE_MOSI_O.wr_be <= MASTER_MOSI_I.wr_be when slave_ce='1' else "0000";
SLAVE_MOSI_O.rd_en <= MASTER_MOSI_I.rd_en when slave_ce='1' else '0';

-- MISO multiplexor controlled by registered CE; see ION bus chronograms.
MASTER_MISO_O <= SLAVE_MISO_I;

end architecture rtl;
