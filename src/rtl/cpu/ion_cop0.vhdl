--------------------------------------------------------------------------------
-- ION_COP0.vhdl -- COP0 for ION CPU.
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

use work.ION_INTERFACES_PKG.all;
use work.ION_INTERNAL_PKG.all;


entity ION_COP0 is
    generic(
        -- Type of memory to be used for register bank in xilinx HW
        XILINX_REGBANK  : string    := "distributed" -- {distributed|block}
    );
    port(
        CLK_I           : in std_logic;
        RESET_I         : in std_logic;

        CPU_I           : in t_cop0_mosi;
        CPU_O           : out t_cop0_miso
    );
end;

architecture rtl of ION_COP0 is

--------------------------------------------------------------------------------
-- CP0 registers and signals

type t_sr_reg is record
    bev :                   std_logic;
    um :                    std_logic;
    erl :                   std_logic;
    exl :                   std_logic;
    ie :                    std_logic;
end record;

-- CP0[12]: status register flags.
signal sr_reg :             t_sr_reg;
signal sr_reg_mtc0 :        t_sr_reg;

signal cp0_status :         std_logic_vector(4 downto 0);

signal cp0_cache_control_d :  std_logic_vector(17 downto 16);

signal cp0_we_delayed :     std_logic;

signal privileged :         std_logic;
signal exception_stalled_reg :  std_logic;
-- CP0[12]: status register, cache control
signal cp0_cache_control :  std_logic_vector(17 downto 16);
-- CP0[14]: EPC register (PC value saved at exceptions)
signal epc_reg :            t_pc;
-- CP0[13]: 'Cause' register (cause and attributes of exception)
signal cp0_cause :          t_word;
signal cause_bd_reg :       std_logic;
signal cp0_cause_ce :       std_logic_vector(1 downto 0);
signal cause_exc_code_reg : std_logic_vector(4 downto 0);
signal cause_exc_code :     std_logic_vector(4 downto 0);
-- Exception vector or return address, registered for improved timing.
signal vector_reg :         t_pc;
signal pc_load_en_reg :     std_logic;
signal reset_delayed :      std_logic_vector(1 downto 0);

begin

--#### COP0 Registers ##########################################################

-- Handle all registers in the same process: they all operate on the same 
-- events anyway.
cp0_registers:
process(CLK_I)
begin
    if CLK_I'event and CLK_I='1' then
        if RESET_I='1' then
            -- SR flags for RESET_I.
            sr_reg.bev <= '1';
            sr_reg.um <= '0'; -- Kernel mode
            sr_reg.erl <= '1'; -- Error level: Reset
            sr_reg.exl <= '0'; -- Exception level: None
            sr_reg.ie <= '0'; -- Interrupt Enable: No
            -- Other CP0 register resets.
            cp0_cache_control <= "00";
            cause_exc_code_reg <= "00000";
            cause_bd_reg <= '0';
            -- As per the specs, not all registers have a RESET_I value.
        else
            if CPU_I.exception='1' then
                cause_exc_code_reg <= cause_exc_code;
            end if;
            -- Everything is stalled if the pipeline is stalled, including 
            -- exception processing.

            if CPU_I.stall='0' then
                if (CPU_I.exception='1' or exception_stalled_reg='1') then
                    -- Exception: do all that needs to be done right here
                    -- If EXL is not raised already then...
                    if sr_reg.exl = '0' then
                        -- Save return address in EPC register...
                        epc_reg <= CPU_I.pc_restart;
                        -- ...raise EXL flag...
                        sr_reg.exl <= '1';
                        -- ...update cause register... 
                        --cause_exc_code_reg <= cause_exc_code;
                    else
                        -- If ERL was already asserted, update no flags.
                    end if;
                    
                    -- Update the BD flag for exceptions in delay slots
                    cause_bd_reg <= CPU_I.in_delay_slot;
                
                elsif CPU_I.eret='1' and privileged='1' then
                    -- ERET: Return from exception.
                    -- Handle flags as per {FIXME add reference to vol.3 of the ARM}
                    if sr_reg.erl='1' then
                        sr_reg.erl <= '0';
                    else
                        sr_reg.exl <= '0';
                    end if;
                    
                elsif cp0_we_delayed='1' then
                    -- MTC0: load CP0[xx] with Rt
                
                    -- NOTE: in MTCx, the source register is Rt.
                    -- FIXME this works because only SR is writeable; when 
                    -- CP0[13].IP1-0 are implemented, check for CP0 reg index.
                    sr_reg <= sr_reg_mtc0;
                    cp0_cache_control <= cp0_cache_control_d;
                end if;
            end if;
        end if;
    end if;
end process cp0_registers;


cp0_registers_delayed_write:
process(CLK_I)
begin
    if CLK_I'event and CLK_I='1' then
        if RESET_I='1' then
            -- SR flags for RESET_I.
            sr_reg_mtc0.bev <= '1';
            sr_reg_mtc0.um <= '0'; -- Kernel mode
            sr_reg_mtc0.erl <= '1'; -- Error level: Reset
            sr_reg_mtc0.exl <= '0'; -- Exception level: None
            sr_reg_mtc0.ie <= '0'; -- Interrupt Enable: No
            cp0_we_delayed <= '0';
        else
            if CPU_I.pipeline_stalled='0' then
                if CPU_I.we='1' and privileged='1' then
                    cp0_we_delayed <= '1';
                    -- MTC0: load CP0[xx] with Rt
                    -- NOTE: in MTCx, the source register is Rt.
                    -- FIXME this works because only SR is writeable; when 
                    -- CP0[13].IP1-0 are implemented, check for CP0 reg index.
                    sr_reg_mtc0.exl <= CPU_I.data(1);
                    sr_reg_mtc0.erl <= CPU_I.data(2);
                    sr_reg_mtc0.um <= CPU_I.data(4);
                    sr_reg_mtc0.bev <= CPU_I.data(22);
                    cp0_cache_control_d <= CPU_I.data(17 downto 16);
                else 
                    cp0_we_delayed <= '0';
                end if;
            end if;
        end if;
    end if;
end process cp0_registers_delayed_write;

-- FIXME see if this can be replaced with pipeline_stalled
reset_control2:
process(CLK_I)
begin
    if CLK_I'event and CLK_I='1' then
        if RESET_I='1' then
            exception_stalled_reg <= '0';
        else
            if CPU_I.exception='1' and CPU_I.stall='1' then
                exception_stalled_reg <= '1';
            elsif CPU_I.stall='0' then
                exception_stalled_reg <= '0';
            end if;
        end if;
    end if;
end process reset_control2;

-- We'll build a signal reset_delayed to keep track of the 2 cycles after 
-- RESET_I deassertion; used to control pc_load_en_reg vector_reg.
reset_control:
process(CLK_I)
begin
    if CLK_I'event and CLK_I='1' then
        if RESET_I='1' then
            reset_delayed <= "11";
        else
            reset_delayed(1) <= reset_delayed(0);
            reset_delayed(0) <= RESET_I;
        end if;
    end if;
end process reset_control;

vector_register_mux:
process(CLK_I)
begin
    if CLK_I'event and CLK_I='1' then
        if RESET_I='1' then
            vector_reg <= RESET_VECTOR_M4(31 downto 2);
        else
            -- Keep the RESET_I vector in the register until cycle 2 after 
            -- RESET_I deassertion, when it has already been loaded into PC.
            if reset_delayed(0)='0' then
                vector_reg <= X"BFC0018" & "00";
            end if;
            -- FIXME lots of COP0 stuff missing, in case you forget
        end if;
    end if;
end process vector_register_mux;


pc_load_en_reg <= reset_delayed(1) or CPU_I.exception or CPU_I.eret;

--#### Misc logic ##############################################################

-- Privileged status depends on several flags.
privileged <= not ((not sr_reg.erl) and (not sr_reg.exl) and sr_reg.um);

-- Decode exception cause; will be registered only if actually triggered so the 
-- logic need to be valid only in that case.
cause_exc_code <= 
    "00000" when CPU_I.exception='0' else
    "00000" when CPU_I.hw_irq='1' else
    "01010" when CPU_I.unknown_opcode='1' else      -- bad opcode ('reserved')
    -- this triggers for mtc0/mfc0 in user mode too
    "01011" when CPU_I.missing_cop='1' else         -- CP* unavailable
    "01000" when CPU_I.syscall='1' else             -- SYSCALL
    "01001";                                        -- BREAK


--#### CPU interface ###########################################################

CPU_O.idcache_enable <= cp0_cache_control(17);
CPU_O.icache_invalidate <= cp0_cache_control(16);
CPU_O.kernel <= privileged;
CPU_O.pc_load_en <= pc_load_en_reg;
CPU_O.pc_load_value <= vector_reg when CPU_I.eret='0' else epc_reg; -- FIXME @hack5


--#### Read register mux #######################################################

-- Build up the READ registers from the bits and pieces that make them up.
cp0_status <= sr_reg.um & '0' & sr_reg.erl & sr_reg.exl & sr_reg.ie;
cp0_cause_ce <= "00"; -- FIXME CP* traps merged with unimplemented opcode traps
cp0_cause <= cause_bd_reg & '0' & cp0_cause_ce & 
             X"00000" & '0' & cause_exc_code_reg & "00";

-- FIXME the mux should mask to zero for any unused reg index
with CPU_I.index select CPU_O.data <=
    X"00" & "0" & sr_reg.bev & X"0000" & "0" & cp0_status   when "01100",
    cp0_cause                                               when "01101",
    epc_reg & "00"                                          when others;


end architecture rtl;
