--------------------------------------------------------------------------------
-- ion_icache.vhdl -- Instruction/Data Cache.
--------------------------------------------------------------------------------
-- 
--
-- NOTES:
--
-- @note1: 
--      All supported CACHE instruction functions involve invalidating a line
--      or explicity zeroing a tag. So the valid flag is always written as 0 
--      except when REFILL.
--      Remember our "Store Tag" implementation uses a hardwired zero TagLo.
--
-- @ note2:
--      In the first clock cycle of all write accesses, the addressed line 
--      is invalidated. The CPU address is only valid in this cycle so we
--      do it right now and save a register and a mux.
--
-- @note3: 
--      When a RD comes the cycle after a WR, we'll lose it unless we register
--      the fact. This happens because the rd_en signal is asserted for a single
--      clock cycle, even if the RD instruction is stalled waiting for the WR
--      to finish.
--      The same thing happens when a WR follows a RD.
--
-- REFERENCES
-- [1] ion_design_notes.pdf -- ION project design notes.
--------------------------------------------------------------------------------
-- NOTES:
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
        
        CE_I                : in std_logic;
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

-- Valid bit appended to address tag; this is what's stored in the tag table.
subtype t_tag is std_logic_vector(TAG_WIDTH+1-1 downto 0);  

-- Tag table implemented as (inferred) synchronous BRAM.
type t_tag_table is array(0 to NUM_LINES-1) of t_tag;
-- Initial value meant for TB only. Helps catch errors in invalidation opcodes.
signal tag_table :          t_tag_table; -- := (others => '1' & X"90000");
-- Signals used to access the tag table.
signal tag :                t_tag_address;
signal tag_reg :            t_tag_address;
signal cached_tag_addr :    t_tag_address;
signal line_index :         t_index;
signal line_address :       t_line_address;
signal cached_tag :         t_tag;
signal tag_table_we :       std_logic;

-- Valid flag to be stored in tag table.
signal new_valid_flag :     std_logic;
-- Valid flag read from tag table during a lookup.
signal cached_tag_valid :   std_logic;

-- Line table implemented as (inferred) BRAM table.
type t_line_table is array(0 to LINE_TABLE_SIZE-1) of t_word;
signal line_table :         t_line_table;
-- Signals used to access the line table.
signal refill_line_address : t_line_address;
signal refill_line_address_reg : t_line_address;
signal cached_word :        t_word;
signal line_table_we :      std_logic;

-- Misc control signals.
signal miss :               std_logic;
signal lookup :             std_logic;
signal lookup_reg :         std_logic;
signal write_cycle :        std_logic;
signal update_tag :         std_logic;
signal data_wr_reg :        t_word;
signal addr_reg :           t_word;
signal wr_be_reg :          std_logic_vector(3 downto 0);
signal read_pending :       std_logic;

-- Refill state machine signals.
type t_refill_state is (
    HIT,
    REFILL,
    WRITETHROUGH,
    REFILL_LAST_WORD
);

signal ns, ps :             t_refill_state;
    
signal refill_ctr :         t_offset;
signal store_delay_ctr :    integer range 0 to 2;
signal refill_done :        std_logic;

          
begin
 
    -- CPU interface -----------------------------------------------------------

    CPU_MISO_O.rd_data <= cached_word;
    CPU_MISO_O.mwait <=
        '1' when ps = REFILL else
        '1' when ps = REFILL_LAST_WORD else 
        '1' when ps = HIT and miss = '1' else -- !!
        '1' when ps = HIT and read_pending = '1' else -- see @note3
        '1' when ps = WRITETHROUGH else
        '0';
    
    lookup <= 
        '1' when CPU_MOSI_I.rd_en='1' and CE_I='1' else 
        '1' when read_pending='1' and ps=HIT else 
        '0';
    
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                lookup_reg <= '0';
            else
                lookup_reg <= lookup;
                if CPU_MOSI_I.wr_be/="0000" then
                    data_wr_reg <= CPU_MOSI_I.wr_data;
                    wr_be_reg <= CPU_MOSI_I.wr_be;
                end if;
                if CPU_MOSI_I.rd_en='1' or CPU_MOSI_I.wr_be/="0000" then
                    addr_reg <= CPU_MOSI_I.addr;
                end if;
            end if;
        end if;
    end process;
 
    -- Assert update_tag for special CACHE instructions only.
    -- FIXME control interface is crude and needs to be defined & refactored
    update_tag <= '1' when 
        CACHE_CTRL_MOSI_I.data_cache = '1' and
        CACHE_CTRL_MOSI_I.function_en = '1'
        else '0';
 
 
    -- Tag table ---------------------------------------------------------------

    -- Extract all relevand fields from incoming CPU address.
    tag <= CPU_MOSI_I.addr(31 downto LINE_ADDRESS_WIDTH+2);
    tag_reg <= addr_reg(31 downto LINE_ADDRESS_WIDTH+2);
    line_index <= CPU_MOSI_I.addr(LINE_ADDRESS_WIDTH+1 downto LINE_OFFSET_WIDTH + 2);
    line_address <= CPU_MOSI_I.addr(LINE_ADDRESS_WIDTH+1 downto 2);
 
    -- Tag table inferred BRAM.
    synchronous_tag_table:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if tag_table_we='1' then 
                tag_table(conv_integer(line_index)) <= new_valid_flag & tag;
            end if;
            
            cached_tag <= tag_table(conv_integer(line_index));
        end if;
    end process synchronous_tag_table;

    -- Extract fields from the word we just read from the tag table.
    cached_tag_valid <= cached_tag(cached_tag'high);
    cached_tag_addr <= cached_tag(cached_tag'high-1 downto 0);
    
    -- When in REFILL, set valid flag. Otherwise reset it.
    with ps select new_valid_flag <= 
        '1' when        REFILL,
        '0' when        others; -- see @note1
    
    -- The miss signal needs only be valid in the "HIT" state.
    miss <= 
        '1' when ((cached_tag_addr /= tag_reg) or 
                  (cached_tag_valid = '0')) and 
            lookup_reg = '1'
        else '0';
    
    write_cycle <= '1' when CPU_MOSI_I.wr_be/="0000" and CE_I='1' else '0';

    
    -- Line table --------------------------------------------------------------

    -- Line table (inferred) BRAM.
    synchronous_line_table:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if line_table_we='1' then 
                line_table(conv_integer(refill_line_address_reg)) <= MEM_MISO_I.dat;
            end if;
            
            cached_word <= line_table(conv_integer(line_address));
        end if;
    end process synchronous_line_table;
    
    -- Since the target address is only present in the ION CPU bus for a single
    -- cycle, we need to register it to use it along the refill operation.
    refill_addr_register:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if lookup = '1' and ps=HIT then 
                refill_line_address(LINE_ADDRESS_WIDTH-1 downto LINE_OFFSET_WIDTH) <= 
                CPU_MOSI_I.addr(LINE_ADDRESS_WIDTH-1+2 downto LINE_OFFSET_WIDTH+2);
            end if;
            refill_line_address_reg <= refill_line_address;
        end if;
    end process refill_addr_register;
    -- The low bits of the refill address come from the refill counter.
    refill_line_address(LINE_OFFSET_WIDTH-1 downto 0) <= refill_ctr;
    
    -- We write onto the line table only in the cycles in which there is valid
    -- refill data in the refill WB bus.
    line_table_we <=
        '1' when ps = REFILL and MEM_MISO_I.ack = '1' else
        '1' when ps = REFILL_LAST_WORD and store_delay_ctr = 2 else
        '0';
    
    
    -- Refill State Machine ----------------------------------------------------

    refill_state_machine_reg:
    process(CLK_I)
    begin
       if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                ps <= HIT;
            else
                ps <= ns;
            end if;
        end if;
    end process refill_state_machine_reg;
    
    
    refill_state_machine_transitions:
    process(ps, miss, refill_done, write_cycle, MEM_MISO_I.stall, 
            store_delay_ctr, read_pending)
    begin
        case ps is
        when HIT =>
            if miss='1' then 
                ns <= REFILL;
            elsif write_cycle='1' then
                ns <= WRITETHROUGH;
            else
                ns <= ps;
            end if;
        when REFILL =>
            if refill_done='1' then
                ns <= REFILL_LAST_WORD;
            else
                ns <= ps;
            end if;
        when REFILL_LAST_WORD =>
            if store_delay_ctr = 0 then
                ns <= HIT;
            else
                ns <= ps;
            end if;
        when WRITETHROUGH =>
            if MEM_MISO_I.stall='0' then
                ns <= HIT;
            else
                ns <= ps;
            end if;
        when others =>
            -- NOTE: We´re not detecting here a real derailed HW state machine, 
            -- only a buggy rtl.
            ns <= HIT;
        end case;
    end process refill_state_machine_transitions;
    
    -- When the last word in the line has been read from the WB bus, we are done
    -- REFILL.
    refill_done <= 
        '1' when refill_ctr = (LINE_SIZE-1) and MEM_MISO_I.stall = '0'
        else '0';
    
    refill_word_counter:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I = '1' then
                refill_ctr <= (others => '0');
            elsif ps = REFILL and MEM_MISO_I.stall = '0' then
                refill_ctr <= refill_ctr + 1;
            end if;
        end if;
    end process refill_word_counter;

    store_delay_counter:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I = '1' then
                store_delay_ctr <= 2;
            elsif ps = REFILL_LAST_WORD then
                if store_delay_ctr /= 0 then 
                    store_delay_ctr <= store_delay_ctr - 1;
                end if;
            else 
                store_delay_ctr <= 2;
            end if;
        end if;
    end process store_delay_counter;

    tag_table_we <= 
        '1' when ps = REFILL and MEM_MISO_I.ack = '1' and refill_ctr="001" else
        '1' when ps = HIT and CPU_MOSI_I.wr_be/="0000" else -- see @note2
        '1' when update_tag = '1' else -- see @note1
        '0';

        
    -- Refill WB interface -----------------------------------------------------
 
    MEM_MOSI_O.adr(31 downto LINE_ADDRESS_WIDTH+2) <= addr_reg(31 downto LINE_ADDRESS_WIDTH+2);
    with ps select MEM_MOSI_O.adr(LINE_ADDRESS_WIDTH-1+2 downto 2) <= 
        refill_line_address                         when REFILL,
        addr_reg(LINE_ADDRESS_WIDTH-1+2 downto 2)   when others;
    MEM_MOSI_O.adr(1 downto 0) <= (others => '0');
    MEM_MOSI_O.dat <= data_wr_reg;
    MEM_MOSI_O.stb <= '1' when (ps = REFILL or ps = WRITETHROUGH) else '0';
    MEM_MOSI_O.cyc <= '1' when (ps = REFILL or ps = WRITETHROUGH) else '0';
    MEM_MOSI_O.we <= '1' when ps = WRITETHROUGH else '0';
    MEM_MOSI_O.tga <= "0000"; -- FIXME tag use unspecified yet
    MEM_MOSI_O.sel <= wr_be_reg;
    
   
    -- The cache control interface MOSI consists of this lone "present" signal.
    CACHE_CTRL_MISO_O.present <= '1';
    

    -- Back-to-back access support logic ---------------------------------------
    
    -- This flag will be raised when a READ comes immediately aftr a write (in
    -- the following clock cycle). Since the ION bus control signals are valid
    -- for only one cycle we need to remember the request here.
    -- The address is not going to change in the meantime.
    read_pending_register:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then 
                read_pending <= '0';
            elsif ps=WRITETHROUGH and CPU_MOSI_I.rd_en='1' then
                read_pending <= '1';
            elsif ps/=WRITETHROUGH then
                read_pending <= '0';
            end if;
        end if;
    end process read_pending_register;
    
    -- FIXME support RD-WR operations too.
        
end architecture rtl;
