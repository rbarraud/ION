--------------------------------------------------------------------------------
-- mips_muldiv.vhdl -- multiplier from Plasma project, slightly modified.
--
--------------------------------------------------------------------------------
-- This multiplication/division unit is a version of project Plasma's original 
-- mult/div unit (see http://opencores.org/project,plasma).
-- The rtl has been simplified and adapted to the ION environment, but the 
-- core algorithm remains unchanged.
-- Our gratitude to Steve Rhoads for his great Plasma core and this module.
--------------------------------------------------------------------------------
-- Algorithms as described in original core header:
--
-- MULTIPLICATION
-- long64 answer = 0
-- for(i = 0; i < 32; ++i)
-- {
--    answer = (answer >> 1) + (((B_I&1)?A_I:0) << 31);
--    B_I = B_I >> 1;
-- }
--
-- DIVISION
-- long upper=A_I, lower=0;
-- A_I = B_I << 31;
-- for(i = 0; i < 32; ++i)
-- {
--    lower = lower << 1;
--    if(upper >= A_I && A_I && B_I < 2)
--    {
--       upper = upper - A_I;
--       lower |= 1;
--    }
--    A_I = ((B_I&2) << 30) | (A_I >> 1);
--    B_I = B_I >> 1;
-- }
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

use work.ION_INTERFACES_PKG.all;
use work.ION_INTERNAL_PKG.all;


entity ION_MULDIV is
    generic(
        mult_type  : string := "DEFAULT"
    );
    port(
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;
        A_I                 : in std_logic_vector(31 downto 0);
        B_I                 : in std_logic_vector(31 downto 0);
        MULT_FN_I           : in t_mult_function;
        C_MULT_O            : out std_logic_vector(31 downto 0);
        PAUSE_O             : out std_logic
    );
end;

architecture logic of ION_MULDIV is

constant MODE_MULT :        std_logic := '1';
constant MODE_DIV :         std_logic := '0';

signal mode_reg :           std_logic;
signal negate_reg :         std_logic;
signal sign_reg :           std_logic;
signal sign2_reg :          std_logic;
signal count_reg :          std_logic_vector(5 downto 0);
signal aa_reg :             std_logic_vector(31 downto 0);
signal bb_reg :             std_logic_vector(31 downto 0);
signal upper_reg :          std_logic_vector(31 downto 0);
signal lower_reg :          std_logic_vector(31 downto 0);

signal a_neg :              std_logic_vector(31 downto 0);
signal b_neg :              std_logic_vector(31 downto 0);
signal sum :                std_logic_vector(32 downto 0);
signal sum_a :              std_logic_vector(32 downto 0);
signal sum_b :              std_logic_vector(32 downto 0);
   
begin

    -- Output multiplexor.
    C_MULT_O <= 
        lower_reg               when MULT_FN_I = MULT_READ_LO and 
                                     negate_reg = '0' else 
        not(lower_reg) + 1      when MULT_FN_I = MULT_READ_LO and 
                                     negate_reg = '1' else
        upper_reg;
 
    -- Stall pipeline while operation completes even if output is not needed
    -- immediately.
    -- See @note1
    PAUSE_O <= '1' when (count_reg(5 downto 0) /= "000000") else '0';

    -- ABS and remainder signals
    a_neg <= not(A_I) + 1;
    b_neg <= not(B_I) + 1;
 
    sum_a <= ('0' & upper_reg); -- No sign extension: MSB of sum is special
    sum_b <= ('0' & aa_reg);
    with mode_reg select sum <= 
        sum_a + sum_b when '1',
        sum_a - sum_b when others;
    
    -- multiplication/division unit state machine.
    mult_proc: process(CLK_I, RESET_I, A_I, B_I, MULT_FN_I,
        a_neg, b_neg, sum, sign_reg, mode_reg, negate_reg, 
        count_reg, aa_reg, bb_reg, upper_reg, lower_reg)
        variable count : std_logic_vector(2 downto 0);
    begin
        count := "001";

        if rising_edge(CLK_I) then
            if RESET_I = '1' then  
                mode_reg <= '0';
                negate_reg <= '0';
                 sign_reg <= '0';
                 sign2_reg <= '0';
                 count_reg <= "000000";
                 aa_reg <= ZERO;
                 bb_reg <= ZERO;
                 upper_reg <= ZERO;
                 lower_reg <= ZERO;
            else
                case MULT_FN_I is
                when MULT_WRITE_LO =>
                    -- Direct write to LO register.
                    lower_reg <= A_I;
                    negate_reg <= '0';
                when MULT_WRITE_HI =>
                    -- Direct write to HI register.
                    upper_reg <= A_I;
                    negate_reg <= '0';
                when MULT_MULT =>
                    -- Start unsigned multiplication.
                    mode_reg <= MODE_MULT;
                    aa_reg <= A_I;
                    bb_reg <= B_I;
                    upper_reg <= ZERO;
                    count_reg <= "100000";
                    negate_reg <= '0';
                    sign_reg <= '0';
                    sign2_reg <= '0';
                when MULT_SIGNED_MULT =>
                    -- Start signed multiplication.
                    mode_reg <= MODE_MULT;
                    if B_I(31) = '0' then
                        aa_reg <= A_I;
                        bb_reg <= B_I;
                        sign_reg <= A_I(31);
                    else
                        aa_reg <= a_neg;
                        bb_reg <= b_neg;
                        sign_reg <= a_neg(31);
                    end if;
                    sign2_reg <= '0';
                    upper_reg <= ZERO;
                    count_reg <= "100000";
                    negate_reg <= '0';
                when MULT_DIVIDE =>
                    -- Start unsigned division.
                    mode_reg <= MODE_DIV;
                    aa_reg <= B_I(0) & ZERO(30 downto 0);
                    bb_reg <= B_I;
                    upper_reg <= A_I;
                    count_reg <= "100000";
                    negate_reg <= '0';
                when MULT_SIGNED_DIVIDE =>
                    -- Start signed division.
                    mode_reg <= MODE_DIV;
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
                    count_reg <= "100000";
                    negate_reg <= A_I(31) xor B_I(31);
                when others =>
                    -- Do next cycle of operation in course, of any.
                    if count_reg /= "000000" then
                        if mode_reg = MODE_MULT then
                            -- Multiplication
                            if bb_reg(0) = '1' then
                                upper_reg <= (sign_reg xor sum(32)) & sum(31 downto 1);
                                lower_reg <= sum(0) & lower_reg(31 downto 1);
                                sign2_reg <= sign2_reg or sign_reg;
                                sign_reg <= '0';
                                bb_reg <= '0' & bb_reg(31 downto 1);
                            -- The following six lines are optional for speedup
                            --elsif bb_reg(3 downto 0) = "0000" and sign2_reg = '0' and 
                            --      count_reg(5 downto 2) /= "0000" then
                            --   upper_reg <= "0000" & upper_reg(31 downto 4);
                            --   lower_reg <=  upper_reg(3 downto 0) & lower_reg(31 downto 4);
                            --   count := "100";
                            --   bb_reg <= "0000" & bb_reg(31 downto 4);
                            else
                                upper_reg <= sign2_reg & upper_reg(31 downto 1);
                                lower_reg <= upper_reg(0) & lower_reg(31 downto 1);
                                bb_reg <= '0' & bb_reg(31 downto 1);
                            end if;
                        else   
                            -- Division
                            if sum(32) = '0' and aa_reg /= ZERO and 
                                bb_reg(31 downto 1) = ZERO(31 downto 1) then
                                upper_reg <= sum(31 downto 0);
                                lower_reg(0) <= '1';
                            else
                                lower_reg(0) <= '0';
                            end if;
                            aa_reg <= bb_reg(1) & aa_reg(31 downto 1);
                            lower_reg(31 downto 1) <= lower_reg(30 downto 0);
                            bb_reg <= '0' & bb_reg(31 downto 1);
                        end if;
                        count_reg <= count_reg - count;
                   end if; -- count /= 0
                end case; -- state machine
            end if; -- reset/not reset
        end if; -- clock edge
    end process;
    
end; -- architecture logic

--------------------------------------------------------------------------------
-- @note1 : PAUSE_O active until operation complete
-- The original Plasma module allowed the pipeline and the multiplier to run
-- concurrently until the multiplier result was needed, and only then the
-- pipeline was stalled if the mul/div operation had not finished yet.
-- We want to make sure we can abort a mul/div so for the time being we stall 
-- until the operation is complete.
-- I *think* that's what the libraries and the toolchain assume anyway.
-- Note that if we later want to change this, the parent module will need 
-- changes too (logic for p1_muldiv_running).
--------------------------------------------------------------------------------