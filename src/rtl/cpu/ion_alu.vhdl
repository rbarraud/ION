--------------------------------------------------------------------------------
-- ion_alu.vhdl -- integer arithmetic ALU, excluding mult/div functionality.
--
--------------------------------------------------------------------------------
-- Copyright (C) 2011 Jose A. Ruiz
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


entity ION_ALU is
    port(
        CLK_I           : in std_logic;
        RESET_I         : in std_logic;
        
        -- function selection
        AC_I            : in t_alu_control;
        -- comparison result FLAGS_O
        FLAGS_O         : out t_alu_flags;        
        -- data inputs
        OP1_I           : in std_logic_vector(31 downto 0);
        OP2_I           : in std_logic_vector(31 downto 0);
        -- data result output
        RES_O           : out std_logic_vector(31 downto 0)
    );
end;

architecture rtl of ION_ALU is

subtype t_eword is std_logic_vector(32 downto 0);

signal inp2_neg :           t_word;
signal alu_eop1, alu_eop2 : t_eword;
signal sex1, sex2 :         std_logic;
signal alu_arith :          t_eword;
signal alu_shift :          t_word;
signal alu_logic_shift :    t_word;
signal alu_logic :          t_word;

signal less_than_zero :     std_logic;
signal final_mux_sel :      std_logic_vector(1 downto 0);
signal alu_temp :           t_word;



begin


with AC_I.neg_sel select inp2_neg <= 
    not OP2_I                          when "01",      -- nor, sub, etc.
    OP2_I(15 downto 0) & X"0000"       when "10",      -- lhi
    X"00000000"                         when "11",      -- zero
    OP2_I                              when others;    -- straight

sex1 <= OP1_I(31) when AC_I.arith_unsigned='0' else '0';
alu_eop1 <= sex1 & OP1_I;
sex2 <= 
    inp2_neg(31) when (AC_I.arith_unsigned='0' or AC_I.use_slt='1') 
    else '0';
alu_eop2 <= sex2 & inp2_neg;
alu_arith <= alu_eop1 + alu_eop2 + AC_I.cy_in;

with AC_I.logic_sel select alu_logic <= 
    OP1_I and inp2_neg         when "00",
    OP1_I or  inp2_neg         when "01",
    OP1_I xor inp2_neg         when "10",
               inp2_neg         when others;

shifter : entity work.ION_SHIFTER
    port map (
        D_I     => OP2_I,
        A_I     => AC_I.shift_amount,
        FN_I    => AC_I.shift_sel,
        R_O     => alu_shift
    );


with AC_I.use_logic select alu_logic_shift <= 
    alu_logic           when "01",
    not alu_logic       when "11",  -- used only by NOR instruction
    alu_shift           when others;


final_mux_sel(0) <= AC_I.use_arith when AC_I.use_slt='0' else less_than_zero;
final_mux_sel(1) <= AC_I.use_slt;
 
with final_mux_sel select alu_temp <= 
    alu_arith(31 downto 0)  when "01",
    alu_logic_shift         when "00",
    X"00000001"             when "11",
    X"00000000"             when others;

less_than_zero <= alu_arith(32);

FLAGS_O.inp1_lt_zero <= OP1_I(31);
FLAGS_O.inp1_lt_inp2 <= less_than_zero;
FLAGS_O.inp1_eq_inp2 <= '1' when alu_arith(31 downto 0)=X"00000000" else '0';
FLAGS_O.inp1_eq_zero <= '1' when OP1_I(31 downto 0)=X"00000000" else '0';

RES_O <= alu_temp;

end; --architecture rtl
