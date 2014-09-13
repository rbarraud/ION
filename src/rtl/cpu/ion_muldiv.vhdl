--------------------------------------------------------------------------------
-- mips_muldiv.vhdl -- multiplier/divider module.
--------------------------------------------------------------------------------
--
-- The module can be synthesized in two versions differing in the implementation
-- of the multiplier:
--
-- 1.- Sequential multiplier, with MULT_TYPE = "FAST".
--      This option will infer a pipelined multiplier (2 stages) using whatever
--      DSP resources the underlying FPGA provides (e.g. DSP48 blocks).
-- 2.- Sequential Booth multiplier, with MULT_TYPE = "SEQUENTIAL".
--      This option will implement a Booth algorithm which takes 33 cycles to 
--      compute a product, with no optimizations for leading signs, etc.
--      Some of the logic is shared with the division logic.
--      FIXME Sequential multiplier not implemented; only "FAST" is.
-- 
-- As for the division, it is implemented with a sequential algorithm.
-- which takes 33 clock cycles to perform either a signed or unsigned division.
--
-- A true, efficient signed division algorithm is somewhat complicated, so we 
-- go the lazy route here: Compute ABS(A)/ABS(B) and then adjust the sign of the 
-- quotient Q and remainder R according to these rules:
--
--  # The remainder has the same sign as the dividend.
--  # The quotient is positive if divisor and dividend have the same sign, 
--    otherwise it's negative.
--
-- These rules match the C99 specs.
--------------------------------------------------------------------------------
-- FIXME sequential multiplier option not implemented. 
-- The description of the multiplier above is that of Plasma's, which this 
-- project has been using until recently. It will be offered as an option
-- in subsequent versions of this module.
--------------------------------------------------------------------------------
-- Copyright (C) 2014 Jose A. Ruiz and Debayan Paul.
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
use ieee.numeric_std.all;

use work.ION_INTERFACES_PKG.all;
use work.ION_INTERNAL_PKG.all;


entity ION_MULDIV is
   generic(
        MULT_TYPE : string := "FAST"
   );
   port(
        CLK_I           : in std_logic;
        RESET_I         : in std_logic;
        A_I             : in std_logic_vector(31 downto 0);
        B_I             : in std_logic_vector(31 downto 0);
        MULT_FN_I       : in t_mult_function;
        C_MULT_O        : out std_logic_vector(31 downto 0);
        PAUSE_O         : out std_logic);
end; --entity mult

architecture logic of ION_MULDIV is

-- Multiplier block signals.

signal ma, mb :             signed(32 downto 0);
signal max, mbx :           std_logic;
signal product :            signed(65 downto 0);
signal product_p0 :         signed(65 downto 0);

-- Divider block signals.

signal sign_reg :           std_logic;
signal sign2_reg :          std_logic;
signal negate_quot_reg :    std_logic;
signal negate_rem_reg :     std_logic; 
signal aa_reg :             std_logic_vector(31 downto 0);
signal bb_reg :             std_logic_vector(31 downto 0);
signal upper_reg :          std_logic_vector(31 downto 0);
signal lower_reg :          std_logic_vector(31 downto 0);
signal sum :                signed(32 downto 0);
signal sum_a :              std_logic_vector(32 downto 0);
signal sum_b :              std_logic_vector(32 downto 0);
signal a_neg :              std_logic_vector(31 downto 0);
signal b_neg :              std_logic_vector(31 downto 0);

---- State machine, control & interface signals.

type t_mdiv_state is (
        S_IDLE,         -- Block is idle.
        S_MULT,         -- Multiplication in progress (signer or unsigned).
        S_DIVU,         -- Unsigned division in progress.
        S_DIVS          -- Signed division in progress.
    );

signal ps, ns :             t_mdiv_state;
signal start_divu :         std_logic;
signal start_divs :         std_logic;
signal start_mult :         std_logic;
signal counter :            integer range 0 to 33;
    
signal hireg, loreg :       signed(31 downto 0);    
signal output :             signed(31 downto 0);


begin

    -- Output glue logic -------------------------------------------------------

    with MULT_FN_I select output <=
        loreg           when MULT_READ_LO,
        hireg           when others;


    C_MULT_O <= std_logic_vector(output);
    PAUSE_O <= '0' when ps=S_IDLE else '1';

    result_register:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if (ps=S_DIVU) and counter=0 then 
                hireg <= signed(upper_reg(31 downto 0));
                loreg <= signed(lower_reg(31 downto 0));
            elsif (ps=S_DIVS) and counter=0 then 
                if negate_rem_reg='1' then 
                    hireg <= signed(not(upper_reg(31 downto 0))) + 1;
                else
                    hireg <= signed(upper_reg(31 downto 0));
                end if;

                if negate_quot_reg='1' then
                    loreg <= signed(not(lower_reg(31 downto 0))) + 1;
                else
                    loreg <= signed(lower_reg(31 downto 0));
                end if;
            elsif ps=S_MULT and counter=0 then 
                hireg <= product(63 downto 32);
                loreg <= product(31 downto 0);
            end if;
        end if;
    end process result_register;
    
    -- Control state machine ---------------------------------------------------

    state_register:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                ps <= S_IDLE;
            else
                ps <= ns;
            end if;
        end if;
    end process state_register;

    state_machine_transitions:
    process(ns, MULT_FN_I, counter, start_divs, start_divu, start_mult)
    begin
        case ps is
        when S_IDLE =>
            if start_divs='1' then
                ns <= S_DIVS;
            elsif start_divu='1' then
                ns <= S_DIVU;
            elsif start_mult='1' then
                ns <= S_MULT;
            else
                ns <= ps;
            end if;
        when S_MULT | S_DIVS | S_DIVU =>
            if counter=0 then
                ns <= S_IDLE;
            else
                ns <= ps;
            end if;
        when others => 
            ns <= S_IDLE;
        end case;
    end process state_machine_transitions;
    
    with MULT_FN_I select start_divs <= 
        '1' when MULT_SIGNED_DIVIDE, 
        '0' when others;
    with MULT_FN_I select start_divu <= 
        '1' when MULT_DIVIDE,
        '0' when others;
    with MULT_FN_I select start_mult <= 
        '1' when MULT_MULT | MULT_SIGNED_MULT,
        '0' when others;
    
    cycle_counter:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                counter <= 0;
            else
                if ps=S_IDLE and start_mult='1' then
                    counter <= 1;
                elsif ps=S_IDLE and (start_divs='1' or start_divu='1') then 
                    counter <= 32;
                elsif ps=S_DIVS or ps=S_DIVU or ps=S_MULT then
                    if counter > 0 then 
                        counter <= counter - 1;
                    end if;
                end if;
            end if;
        end if;
    end process cycle_counter;
    
    
    
    -- Multiplier --------------------------------------------------------------

    max <= A_I(31) when MULT_FN_I = MULT_SIGNED_MULT or 
                        MULT_FN_I = MULT_SIGNED_DIVIDE else '0';
    mbx <= B_I(31) when MULT_FN_I = MULT_SIGNED_MULT or 
                        MULT_FN_I = MULT_SIGNED_DIVIDE else '0';

    ma <= signed(max & A_I);
    mb <= signed(mbx & B_I);


    pipelined_dedicated_multiplier:
    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            product_p0 <= ma * mb;
            product <= product_p0;
        end if;
    end process pipelined_dedicated_multiplier;


    -- Divider -----------------------------------------------------------------

    process(CLK_I)
    begin
        if CLK_I'event and CLK_I='1' then
            if RESET_I='1' then
                aa_reg <= ZERO;
                bb_reg <= ZERO;
                upper_reg <= ZERO;
                lower_reg <= ZERO;
            else 
                if start_divu='1' then
                    -- Start unsigned division.
                    aa_reg <= B_I(0) & ZERO(30 downto 0);
                    bb_reg <= B_I;
                    upper_reg <= A_I;
                    negate_quot_reg <= '0';
                    negate_rem_reg <= '0';
                elsif start_divs='1' then 
                    -- Start signed division.
                    if B_I(31) = '0' then
                        aa_reg(31) <= B_I(0);
                        bb_reg <= B_I;
                    else
                        aa_reg(31) <= b_neg(0);
                        bb_reg <= b_neg;
                    end if;
                    if A_I(31) = '0' then
                        upper_reg <= A_I;
                    else
                        upper_reg <= a_neg;
                    end if;
                    aa_reg(30 downto 0) <= ZERO(30 downto 0);
                    negate_quot_reg <= A_I(31) xor B_I(31);
                    negate_rem_reg <= A_I(31);
                else
                    -- Continue signed or unsigned division in course
                    if ps=S_DIVU or ps=S_DIVS then
                        if sum(32) = '0' and aa_reg /= ZERO and 
                            bb_reg(31 downto 1) = ZERO(31 downto 1) then
                            upper_reg <= std_logic_vector(sum(31 downto 0));
                            lower_reg(0) <= '1';
                        else
                            lower_reg(0) <= '0';
                        end if;
                        aa_reg <= bb_reg(1) & aa_reg(31 downto 1);
                        lower_reg(31 downto 1) <= lower_reg(30 downto 0);
                        bb_reg <= '0' & bb_reg(31 downto 1);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Partial subtractor: subtract shifted divisor from dividend.
    sum_a <= ('0' & upper_reg); -- No sign extension: MSB of sum is special
    sum_b <= ('0' & aa_reg);
    sum <= signed(sum_a) - signed(sum_b);

    -- We'll use these negated input values for ABS(A_I) and ABS(B_I).
    a_neg <= std_logic_vector(-signed(A_I));
    b_neg <= std_logic_vector(-signed(B_I));
 

end; --architecture logic
