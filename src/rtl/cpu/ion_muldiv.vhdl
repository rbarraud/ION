--------------------------------------------------------------------------------
-- mips_muldiv.vhdl -- multiplier from Plasma project, slightly modified.
--
-- The original file from Plasma has been adapted to the Ion core. Changes are
-- tagged with '@ion'. There are A_I few notes at the end of the file with the
-- rationale for the changes -- useful only if any trouble shows up later.
-- The structure has not changed, only A_I few implementation details.
--------------------------------------------------------------------------------
---------------------------------------------------------------------
-- TITLE: Multiplication and Division Unit
-- AUTHORS: Steve Rhoads (rhoadss@yahoo.com)
-- DATE CREATED: 1/31/01
-- FILENAME: mult.vhd
-- PROJECT: Plasma CPU core
-- COPYRIGHT: Software placed into the public domain by the author.
--    Software 'as is' without warranty.  Author liable for nothing.
-- DESCRIPTION:
--    Implements the multiplication and division unit in 32 clocks.
--
--    To reduce space, compile your code using the flag "-mno-mul" which 
--    will use software base routines in math.c if USE_SW_MULT is defined.
--    Then remove references to the entity mult in mlite_cpu.vhd.
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
---------------------------------------------------------------------
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
        CLK_I           : in std_logic;
        RESET_I         : in std_logic;
        A_I             : in std_logic_vector(31 downto 0);
        B_I             : in std_logic_vector(31 downto 0);
        MULT_FN_I       : in t_mult_function;
        C_MULT_O        : out std_logic_vector(31 downto 0);
        PAUSE_O         : out std_logic);
end; --entity mult

architecture logic of ION_MULDIV is

   constant MODE_MULT : std_logic := '1';
   constant MODE_DIV  : std_logic := '0';

   signal mode_reg    : std_logic;
   signal negate_reg  : std_logic;
   signal sign_reg    : std_logic;
   signal sign2_reg   : std_logic;
   signal count_reg   : std_logic_vector(5 downto 0);
   signal aa_reg      : std_logic_vector(31 downto 0);
   signal bb_reg      : std_logic_vector(31 downto 0);
   signal upper_reg   : std_logic_vector(31 downto 0);
   signal lower_reg   : std_logic_vector(31 downto 0);

   signal a_neg       : std_logic_vector(31 downto 0);
   signal b_neg       : std_logic_vector(31 downto 0);
   signal sum         : std_logic_vector(32 downto 0);
   signal sum_a       : std_logic_vector(32 downto 0);
   signal sum_b       : std_logic_vector(32 downto 0);
   
begin
 
   -- @ion Output mux no longer uses function bv_negate. Removing one input that
   -- is no longer needed, even if constant, may help in some FPGA architectures 
   -- too.
   -- See @note2
   -- Result
   C_MULT_O <= lower_reg            when MULT_FN_I = MULT_READ_LO and 
                                         negate_reg = '0' else 
             not(lower_reg) + 1     when MULT_FN_I = MULT_READ_LO and 
             --bv_negate(lower_reg)   when MULT_FN_I = MULT_READ_LO and 
                                         negate_reg = '1' else
             upper_reg;             -- when MULT_FN_I = MULT_READ_HI else 
             --ZERO;
 
   -- @ion Stall pipeline while operation completes even if output is not needed
   -- immediately.
   -- See @note3
   PAUSE_O <= '1' when (count_reg(5 downto 0) /= "000000") else '0'; --and 
             --(MULT_FN_I = MULT_READ_LO or MULT_FN_I = MULT_READ_HI) else '0';

   -- ABS and remainder signals
   a_neg <= not(A_I) + 1; --bv_negate(A_I); -- @ion @note2
   b_neg <= not(B_I) + 1; --bv_negate(B_I); -- @ion @note2
 
   -- @ion Replaced function bv_adder with straight vector code
   --sum <= bv_adder(upper_reg, aa_reg, mode_reg);
   sum_a <= ('0' & upper_reg); -- No sign extension: MSB of sum is special
   sum_b <= ('0' & aa_reg);
   with mode_reg select sum <= 
        sum_a + sum_b when '1',
        sum_a - sum_b when others;
    
   --multiplication/division unit
   mult_proc: process(CLK_I, RESET_I, A_I, B_I, MULT_FN_I,
      a_neg, b_neg, sum, sign_reg, mode_reg, negate_reg, 
      count_reg, aa_reg, bb_reg, upper_reg, lower_reg)
      variable count : std_logic_vector(2 downto 0);
   begin
      count := "001";
      -- @ion Old asynchronous reset converted to synchronous, for consistency
      -- (Code indenting mangled by the new 'if' level)
      --if RESET_I = '1' then
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
      --elsif rising_edge(CLK_I) then
      else
         case MULT_FN_I is
            when MULT_WRITE_LO =>
               lower_reg <= A_I;
               negate_reg <= '0';
            when MULT_WRITE_HI =>
               upper_reg <= A_I;
               negate_reg <= '0';
            when MULT_MULT =>
               mode_reg <= MODE_MULT;
               aa_reg <= A_I;
               bb_reg <= B_I;
               upper_reg <= ZERO;
               count_reg <= "100000";
               negate_reg <= '0';
               sign_reg <= '0';
               sign2_reg <= '0';
            when MULT_SIGNED_MULT =>
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
               mode_reg <= MODE_DIV;
               aa_reg <= B_I(0) & ZERO(30 downto 0);
               bb_reg <= B_I;
               upper_reg <= A_I;
               count_reg <= "100000";
               negate_reg <= '0';
            when MULT_SIGNED_DIVIDE =>
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
               end if; --count

         end case;
      
      end if;   
      end if;

   end process;
    
end; --architecture logic

--------------------------------------------------------------------------------
-- @note1 : bv_adder function removed
-- This function was a slightly modified adder/substractor coded in a bitwise
-- manner that made it hard for synth tools to recognize it as such. At least
-- that's what I think. Replacing it with straigth code results in smaller and
-- faster logic (about 23% faster).
--
-- @note2 : bv_negate function removed
-- This function computed a 2's complement bitwise. Removed on the same grounds
-- as @note1 but with no apparent improvement in synthesis results.
--
-- @note3 : PAUSE_O active until operation complete
-- The original Plasma module allowed the pipeline and the multiplier to run
-- concurrently until the multiplier result was needed, and only then the
-- pipeline was stalled if the mul/div operation had not finished yet.
-- We want to make sure we can abort a mul/div so for the time being we stall 
-- until the operation is complete.
-- I *think* that's what the libraries and the toolchain assume anyway.
-- Note that if we later want to change this, the parent module will need 
-- changes too (logic for p1_muldiv_running).
--------------------------------------------------------------------------------