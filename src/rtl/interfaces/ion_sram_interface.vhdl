--------------------------------------------------------------------------------
-- ion_sram16_interface.vhdl -- WB-to-16-bit-SRAM interface.
--------------------------------------------------------------------------------
-- 
-- The interface targets a specific SRAM chip, the 256Kx16 61LV25616 from ISSI.
-- This chip is representative of the class of SRAMs this module is meant for.
-- (And happens to be used in the DE-1 board we're targetting...)
--
-- REFERENCES
-- [1] http://www.issi.com/WW/pdf/61C256AL.pdf -- Target SRAM datasheet.
-- [2] ion_design_notes.pdf -- ION project design notes.
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


entity ION_SRAM16_INTERFACE is
    generic(
        -- Size of RAM in 16-bit words.
        SRAM_SIZE : integer         := 256 * 1024;
        -- Wait states introduced in each read or write 16-bit cycle.
        WAIT_CYCLES : integer       := 3
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        -- Core WB interface (this module is a WB slave).
        WB_MOSI_I           : in t_wishbone_mosi;
        WB_MISO_O           : out t_wishbone_miso;
        
        -- External SRAM interface.
        SRAM_ADDR_O         : out std_logic_vector(log2(SRAM_SIZE) downto 1);
        SRAM_DATA_O         : out std_logic_vector(15 downto 0);
        SRAM_DATA_I         : in std_logic_vector(15 downto 0);
        SRAM_WEn_O          : out std_logic;
        SRAM_OEn_O          : out std_logic;
        SRAM_UBn_O          : out std_logic;
        SRAM_LBn_O          : out std_logic;
        SRAM_CEn_O          : out std_logic;
        SRAM_DRIVE_EN_O     : out std_logic
    );
end;

architecture rtl of ION_SRAM16_INTERFACE is

constant SRAM_ADDR_SIZE : integer := log2(SRAM_SIZE);

type t_sram_state is (
    IDLE,
    READ_0,
    READ_0_HOLD,
    READ_1,
    READ_1_HOLD,
    WRITE_0,
    WRITE_0_HOLD,
    WRITE_1,
    WRITE_1_HOLD
);

signal ps, ns :             t_sram_state;

signal wait_ctr :           integer range 0 to WAIT_CYCLES;
signal wait_done :          std_logic;
         
signal low_hword_reg :      std_logic_vector(15 downto 0);
         
begin

    -- Control state machine ---------------------------------------------------
 
    control_state_machine_reg:
    process(CLK_I)
    begin
       if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                ps <= IDLE;
            else
                ps <= ns;
            end if;
        end if;
    end process control_state_machine_reg; 
 
    
    control_state_machine_transitions:
    process(ps, wait_done, WB_MOSI_I)
    begin
        case ps is
        when IDLE =>
            if WB_MOSI_I.cyc = '1' and WB_MOSI_I.we = '0' then
                ns <= READ_0;
            elsif WB_MOSI_I.cyc = '1' and WB_MOSI_I.we = '1' then
                ns <= WRITE_0;
            else
                ns <= ps;
            end if;
        when READ_0 =>
            if wait_done='1' then
                ns <= READ_0_HOLD;
            else
                ns <= ps;
            end if;
        when READ_0_HOLD =>
            ns <= READ_1;
        when READ_1 =>
            if wait_done='1' then
                ns <= READ_1_HOLD;
            else
                ns <= ps;
            end if;
        when READ_1_HOLD =>
            ns <= IDLE;
        when WRITE_0 =>
            if wait_done='1' then
                ns <= WRITE_0_HOLD;
            else
                ns <= ps;
            end if;
        when WRITE_0_HOLD =>
            ns <= WRITE_1;
        when WRITE_1 =>
            if wait_done='1' then
                ns <= WRITE_1_HOLD;
            else
                ns <= ps;
            end if;
        when WRITE_1_HOLD =>
            ns <= IDLE;
        when others =>
            -- NOTE: We´re not detecting here a real derailed HW state machine, 
            -- only a buggy rtl.
            ns <= IDLE;
        end case;
    end process control_state_machine_transitions;
 
    -- Wait state counter ------------------------------------------------------
 
    wait_cycle_counter_reg:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                wait_ctr <= WAIT_CYCLES;
            else
                if wait_ctr /= 0 then
                    wait_ctr <= wait_ctr - 1;
                end if;
            end if;
        end if;
    end process wait_cycle_counter_reg; 
 
    wait_done <= '1' when wait_ctr = 0 else '0';
 
    -- External interface ------------------------------------------------------
 
    with ps select SRAM_DRIVE_EN_O <= 
        '1' when WRITE_0,
        '1' when WRITE_0_HOLD,
        '1' when WRITE_1,
        '1' when WRITE_1_HOLD,
        '0' when others;
    
    with ps select SRAM_CEn_O <=
        '1' when IDLE,
        '0' when others;
        
    with ps select SRAM_UBn_O <=
        '0' when READ_0 | READ_0_HOLD | READ_1 | READ_1_HOLD,
        not WB_MOSI_I.sel(1) when WRITE_0 | WRITE_0_HOLD,
        not WB_MOSI_I.sel(3) when WRITE_1 | WRITE_1_HOLD,
        '1' when others;

    with ps select SRAM_LBn_O <=
        '0' when READ_0 | READ_0_HOLD | READ_1 | READ_1_HOLD,
        not WB_MOSI_I.sel(0) when WRITE_0 | WRITE_0_HOLD,
        not WB_MOSI_I.sel(2) when WRITE_1 | WRITE_1_HOLD,
        '1' when others;

    with ps select SRAM_OEn_O <=
        '0' when READ_0 | READ_0_HOLD | READ_1 | READ_1_HOLD,
        '1' when others;

    with ps select SRAM_WEn_O <=
        '0' when WRITE_0 | WRITE_1,
        '1' when others;
 
    with ps select SRAM_DATA_O <=
        WB_MOSI_I.dat(31 downto 16) when WRITE_1 | WRITE_1_HOLD,
        WB_MOSI_I.dat(15 downto 0)  when others;
    
    with ps select SRAM_ADDR_O(1) <=
        '0' when READ_0 | READ_0_HOLD | WRITE_0 | WRITE_0_HOLD,
        '1' when READ_1 | READ_1_HOLD | WRITE_1 | WRITE_1_HOLD,
        '1' when others;
        
    SRAM_ADDR_O(SRAM_ADDR_O'high downto 2) <= WB_MOSI_I.adr(SRAM_ADDR_O'high downto 2);
         
    
    low_halfword_register:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if ps = READ_0 and wait_ctr=0 then
                low_hword_reg <= SRAM_DATA_I;
            end if;
        end if;
    end process low_halfword_register;     
 
    -- Wishbone interface ------------------------------------------------------
    
    WB_MISO_O.stall <=
        '1' when ps=IDLE and WB_MOSI_I.cyc='1' else
        '1' when ps=READ_0 else
        '1' when ps=READ_0_HOLD else
        '1' when ps=READ_1 and wait_ctr/=0 else
        '1' when ps=READ_1_HOLD and WB_MOSI_I.cyc='1' else
        '1' when ps=WRITE_0 else
        '1' when ps=WRITE_0_HOLD else
        '1' when ps=WRITE_1 and wait_ctr/=0 else
        '1' when ps=WRITE_1_HOLD and WB_MOSI_I.cyc='1' else
        '0';
    
    WB_MISO_O.ack <=
        '1' when ps=READ_1 and wait_ctr=0 else
        '1' when ps=WRITE_1 and wait_ctr=0 else
        '0';
    
    WB_MISO_O.dat <= SRAM_DATA_I & low_hword_reg;
 
end architecture rtl;
