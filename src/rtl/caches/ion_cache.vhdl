--------------------------------------------------------------------------------
-- ion_icache.vhdl -- Instruction Cache.
--------------------------------------------------------------------------------
-- 
--
-- REFERENCES
-- [1] ion_design_notes.pdf -- ION project design notes.
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


entity ION_CACHE is
    generic(
        -- Number of lines per way.
        NUM_LINES : integer := 128;
        -- Size of line in 32-bit words.
        LINE_SIZE : integer := 8
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;

        CACHE_CTRL_MOSI_I   : in t_cache_mosi;
        CACHE_CTRL_MISO_O   : out t_cache_miso;
        
        CPU_MOSI_I          : in t_cpumem_mosi;
        CPU_MISO_O          : out t_cpumem_miso;
        
        MEM_MOSI_O          : out t_wishbone_mosi;
        MEM_MISO_I          : in t_wishbone_miso
    );
end;

architecture rtl of ION_CACHE is

constant LINE_INDEX_WIDTH : integer := log2(NUM_LINES);
constant LINE_OFFSET_WIDTH : integer := log2(LINE_SIZE);
constant LINE_ADDRESS_WIDTH : integer := LINE_INDEX_WIDTH + LINE_OFFSET_WIDTH;
constant TAG_WIDTH : integer := 32 - 2 - LINE_ADDRESS_WIDTH;

constant LINE_TABLE_SIZE : integer := LINE_SIZE * NUM_LINES;

-- Tag table signals.

subtype t_index is std_logic_vector(LINE_INDEX_WIDTH-1 downto 0);
subtype t_offset is std_logic_vector(LINE_OFFSET_WIDTH-1 downto 0);
subtype t_line_address is std_logic_vector(LINE_ADDRESS_WIDTH-1 downto 0);
subtype t_tag_address is std_logic_vector(TAG_WIDTH-1 downto 0);

subtype t_tag is std_logic_vector(TAG_WIDTH+1-1 downto 0);  

type t_tag_table is array(0 to NUM_LINES-1) of t_tag;

signal tag_table :          t_tag_table;
signal tag :                t_tag_address;
signal line_index :         t_index;
signal line_address :       t_line_address;

signal cached_tag :         t_tag;

signal tag_table_we :       std_logic;

-- Line table signals.

type t_line_table is array(0 to LINE_TABLE_SIZE-1) of t_word;
signal line_table :         t_line_table;

signal refill_line_address : t_line_address;
signal cached_word :        t_word;
signal line_table_we :      std_logic;


-- Misc signals.

signal miss :               std_logic;
signal lookup :             std_logic;


-- Refill state machine signals.

type t_refill_state is (
    hitting,
    refilling,
    storing_last_word
);

signal ns, ps :             t_refill_state;
    
signal refill_ctr :         t_offset;
signal store_delay_ctr :    integer range 0 to 2;

signal refill_done :        std_logic;
          
begin
 
    -- CPU interface -----------------------------------------------------------
 

    CPU_MISO_O.rd_data <= cached_word;
    CPU_MISO_O.mwait <=
        '1' when ps = refilling else
        '1' when ps = storing_last_word else 
        '1' when ps = hitting and miss = '1' else
        '0';
    
    lookup <= 
        '1' when CPU_MOSI_I.rd_en='1'
        else '0'; 
 
    -- Tag table ---------------------------------------------------------------

    tag <= CPU_MOSI_I.addr(31 downto LINE_ADDRESS_WIDTH+2);
    line_index <= CPU_MOSI_I.addr(LINE_ADDRESS_WIDTH+1 downto LINE_OFFSET_WIDTH + 2);
    line_address <= CPU_MOSI_I.addr(LINE_ADDRESS_WIDTH+1 downto 2);
 
     
    synchronous_tag_table:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if tag_table_we='1' then 
                tag_table(conv_integer(line_index)) <= '1' & tag;
            end if;
            
            cached_tag <= tag_table(conv_integer(line_index));
        end if;
    end process synchronous_tag_table;

    
    -- The miss signal needs only be valid in the "hitting" state.
    miss <= 
        '1' when (cached_tag(TAG_WIDTH-2 downto 0) /= tag) and lookup='1'
        else '0';
    
    
    -- Line table --------------------------------------------------------------
    
    synchronous_line_table:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if line_table_we='1' then 
                line_table(conv_integer(refill_line_address)) <= MEM_MISO_I.dat;
            end if;
            
            cached_word <= line_table(conv_integer(line_address));
        end if;
    end process synchronous_line_table;
    
    
    refill_addr_register:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if lookup = '1' then 
                refill_line_address(LINE_ADDRESS_WIDTH-1 downto LINE_OFFSET_WIDTH) <= 
                CPU_MOSI_I.addr(LINE_ADDRESS_WIDTH-1+2 downto LINE_OFFSET_WIDTH+2);
            end if;
        end if;
    end process refill_addr_register;
    refill_line_address(LINE_OFFSET_WIDTH-1 downto 0) <= refill_ctr;
    
    
    line_table_we <=
        '1' when ps = refilling else
        '1' when ps = storing_last_word and store_delay_ctr = 2 else
        '0';
    
    
    -- Refill State Machine ----------------------------------------------------

    refill_state_machine_reg:
    process(CLK_I)
    begin
       if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                ps <= hitting;
            else
                ps <= ns;
            end if;
        end if;
    end process refill_state_machine_reg;
    
    
    refill_state_machine_transitions:
    process(ps, miss, refill_done, store_delay_ctr)
    begin
        case ps is
        when hitting =>
            if miss='1' then 
                ns <= refilling;
            else
                ns <= ps;
            end if;
        when refilling =>
            if refill_done='1' then
                ns <= storing_last_word;
            else
                ns <= ps;
            end if;
        when storing_last_word =>
            if store_delay_ctr = 0 then
                ns <= hitting;
            else
                ns <= ps;
            end if;
        when others =>
            -- NOTE: We´re not detecting here a real derailed HW state machine, 
            -- only a buggy rtl.
            ns <= hitting;
        end case;
    end process refill_state_machine_transitions;
    
    -- When the last word in the line has been read from the WB bus, we are done
    -- refilling.
    refill_done <= 
        '1' when refill_ctr = (LINE_SIZE-1) and MEM_MISO_I.ack = '1'
        else '0';
    
    refill_word_counter:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I = '1' then
                refill_ctr <= (others => '0');
            elsif ps = refilling then
                refill_ctr <= refill_ctr - 1;
            end if;
        end if;
    end process refill_word_counter;

    store_delay_counter:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I = '1' then
                store_delay_ctr <= 2;
            elsif ps = storing_last_word then
                if store_delay_ctr /= 0 then 
                    store_delay_ctr <= store_delay_ctr - 1;
                end if;
            else 
                store_delay_ctr <= 2;
            end if;
        end if;
    end process store_delay_counter;

    tag_table_we <= 
        '1' when ps = refilling and MEM_MISO_I.ack = '1' else
        '1' when ps = storing_last_word and store_delay_ctr = 2 else
        '0';

        
    -- Refill WB interface -----------------------------------------------------
 
    --MEM_MOSI_O.adr <= xxx;
    MEM_MOSI_O.stb <= '1' when ps = refilling else '0';
    MEM_MOSI_O.cyc <= '1' when ps = refilling else '0';
    MEM_MOSI_O.we <= '0';
    MEM_MOSI_O.sel <= "1111";
    
    
    CACHE_CTRL_MISO_O.ready <= '1';
    

        
end architecture rtl;
