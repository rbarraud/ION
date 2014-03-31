--------------------------------------------------------------------------------
-- obj_code_pkg.vhdl -- Application object code in vhdl constant string format.
--------------------------------------------------------------------------------
-- Built for project 'CPU tester'.
--------------------------------------------------------------------------------
-- This file contains object code in the form of a VHDL byte table constant.
-- This constant can be used to initialize FPGA memories for synthesis or
-- simulation.
-- Note that the object code is stored as a plain byte table in byte address
-- order. This table knows nothing of data endianess and can be used to
-- initialize 32-, 16- or 8-bit-wide memory -- memory initialization functions
-- can be found in package mips_pkg.
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
use ieee.numeric_std.all;

use work.ION_INTERFACES_PKG.all;
use work.ION_INTERNAL_PKG.all;

package OBJ_CODE_PKG is

-- Simulation or synthesis parameters ------------------------------------------

constant CODE_MEM_SIZE : integer := 4096;
constant DATA_MEM_SIZE : integer := 1024;


-- Memory initialization data --------------------------------------------------

constant OBJ_CODE : t_obj_code(0 to 2767) := (
  X"10", X"00", X"00", X"61", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"42", X"00", X"00", X"18", X"00", X"00", X"00", X"00", 
  X"3c", X"04", X"bf", X"c0", X"24", X"84", X"05", X"e4", 
  X"0f", X"f0", X"01", X"70", X"00", X"00", X"00", X"00", 
  X"34", X"1c", X"00", X"00", X"34", X"1e", X"00", X"00", 
  X"3c", X"04", X"bf", X"c0", X"24", X"84", X"06", X"26", 
  X"0f", X"f0", X"01", X"70", X"00", X"00", X"00", X"00", 
  X"34", X"1c", X"00", X"00", X"24", X"09", X"00", X"00", 
  X"3c", X"02", X"12", X"34", X"34", X"42", X"56", X"78", 
  X"3c", X"03", X"45", X"67", X"34", X"63", X"89", X"a0", 
  X"3c", X"04", X"78", X"9a", X"34", X"84", X"bc", X"de", 
  X"3c", X"05", X"8a", X"bc", X"34", X"a5", X"de", X"f0", 
  X"ad", X"22", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"34", X"07", X"42", X"42", X"8d", X"27", X"00", X"00", 
  X"00", X"e2", X"38", X"22", X"10", X"e0", X"00", X"02", 
  X"00", X"00", X"00", X"00", X"23", X"9c", X"00", X"01", 
  X"03", X"dc", X"f0", X"20", X"17", X"80", X"00", X"07", 
  X"00", X"00", X"00", X"00", X"3c", X"04", X"bf", X"c0", 
  X"24", X"84", X"05", X"fd", X"0f", X"f0", X"01", X"70", 
  X"00", X"00", X"00", X"00", X"0b", X"f0", X"00", X"8b", 
  X"00", X"00", X"00", X"00", X"3c", X"04", X"bf", X"c0", 
  X"24", X"84", X"06", X"01", X"0f", X"f0", X"01", X"70", 
  X"00", X"00", X"00", X"00", X"3c", X"05", X"80", X"00", 
  X"8c", X"a4", X"00", X"00", X"00", X"00", X"00", X"00", 
  X"3c", X"04", X"bf", X"c0", X"24", X"84", X"06", X"45", 
  X"0f", X"f0", X"01", X"70", X"00", X"00", X"00", X"00", 
  X"34", X"1c", X"00", X"00", X"3c", X"02", X"12", X"34", 
  X"34", X"42", X"56", X"78", X"3c", X"03", X"45", X"67", 
  X"34", X"63", X"89", X"a0", X"3c", X"04", X"78", X"9a", 
  X"34", X"84", X"bc", X"de", X"3c", X"05", X"8a", X"bc", 
  X"34", X"a5", X"de", X"f0", X"00", X"43", X"30", X"20", 
  X"3c", X"09", X"57", X"9b", X"35", X"29", X"e0", X"18", 
  X"00", X"c9", X"48", X"22", X"11", X"20", X"00", X"02", 
  X"00", X"00", X"00", X"00", X"23", X"9c", X"00", X"01", 
  X"00", X"85", X"30", X"20", X"3c", X"14", X"03", X"57", 
  X"36", X"94", X"9b", X"ce", X"00", X"d4", X"a0", X"22", 
  X"12", X"80", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"00", X"85", X"30", X"20", 
  X"20", X"c6", X"d0", X"34", X"3c", X"14", X"03", X"57", 
  X"36", X"94", X"6c", X"02", X"00", X"d4", X"a0", X"22", 
  X"12", X"80", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"00", X"85", X"30", X"20", 
  X"20", X"c6", X"70", X"43", X"3c", X"14", X"03", X"58", 
  X"36", X"94", X"0c", X"11", X"00", X"d4", X"a0", X"22", 
  X"12", X"80", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"00", X"85", X"30", X"20", 
  X"24", X"c6", X"70", X"43", X"3c", X"14", X"03", X"58", 
  X"36", X"94", X"0c", X"11", X"00", X"d4", X"a0", X"22", 
  X"12", X"80", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"00", X"43", X"30", X"22", 
  X"3c", X"09", X"cc", X"cc", X"35", X"29", X"cc", X"d8", 
  X"00", X"c9", X"48", X"22", X"11", X"20", X"00", X"02", 
  X"00", X"00", X"00", X"00", X"23", X"9c", X"00", X"01", 
  X"00", X"85", X"30", X"22", X"3c", X"14", X"ed", X"dd", 
  X"36", X"94", X"dd", X"ee", X"00", X"d4", X"a0", X"22", 
  X"12", X"80", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"00", X"43", X"30", X"23", 
  X"3c", X"09", X"cc", X"cc", X"35", X"29", X"cc", X"d8", 
  X"00", X"c9", X"48", X"22", X"11", X"20", X"00", X"02", 
  X"00", X"00", X"00", X"00", X"23", X"9c", X"00", X"01", 
  X"00", X"85", X"30", X"23", X"3c", X"14", X"ed", X"dd", 
  X"36", X"94", X"dd", X"ee", X"00", X"d4", X"a0", X"22", 
  X"12", X"80", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"03", X"dc", X"f0", X"20", 
  X"17", X"80", X"00", X"07", X"00", X"00", X"00", X"00", 
  X"3c", X"04", X"bf", X"c0", X"24", X"84", X"05", X"fd", 
  X"0f", X"f0", X"01", X"70", X"00", X"00", X"00", X"00", 
  X"0b", X"f0", X"00", X"ea", X"00", X"00", X"00", X"00", 
  X"3c", X"04", X"bf", X"c0", X"24", X"84", X"06", X"01", 
  X"0f", X"f0", X"01", X"70", X"00", X"00", X"00", X"00", 
  X"3c", X"04", X"bf", X"c0", X"24", X"84", X"06", X"64", 
  X"0f", X"f0", X"01", X"70", X"00", X"00", X"00", X"00", 
  X"34", X"1c", X"00", X"00", X"3c", X"02", X"12", X"34", 
  X"34", X"42", X"56", X"78", X"3c", X"03", X"45", X"67", 
  X"34", X"63", X"89", X"a0", X"3c", X"04", X"78", X"9a", 
  X"34", X"84", X"bc", X"de", X"3c", X"05", X"8a", X"bc", 
  X"34", X"a5", X"de", X"f0", X"00", X"43", X"30", X"24", 
  X"3c", X"09", X"00", X"24", X"35", X"29", X"00", X"20", 
  X"00", X"c9", X"48", X"22", X"11", X"20", X"00", X"02", 
  X"00", X"00", X"00", X"00", X"23", X"9c", X"00", X"01", 
  X"00", X"85", X"30", X"24", X"3c", X"14", X"08", X"98", 
  X"36", X"94", X"9c", X"d0", X"00", X"d4", X"a0", X"22", 
  X"12", X"80", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"30", X"a6", X"d0", X"34", 
  X"34", X"14", X"d0", X"30", X"00", X"d4", X"a0", X"22", 
  X"12", X"80", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"00", X"85", X"30", X"25", 
  X"3c", X"14", X"fa", X"be", X"36", X"94", X"fe", X"fe", 
  X"00", X"d4", X"a0", X"22", X"12", X"80", X"00", X"02", 
  X"00", X"00", X"00", X"00", X"23", X"9c", X"00", X"01", 
  X"34", X"a6", X"d0", X"34", X"3c", X"14", X"8a", X"bc", 
  X"36", X"94", X"de", X"f4", X"00", X"d4", X"a0", X"22", 
  X"12", X"80", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"00", X"85", X"30", X"26", 
  X"3c", X"14", X"f2", X"26", X"36", X"94", X"62", X"2e", 
  X"00", X"d4", X"a0", X"22", X"12", X"80", X"00", X"02", 
  X"00", X"00", X"00", X"00", X"23", X"9c", X"00", X"01", 
  X"38", X"a6", X"d0", X"34", X"3c", X"14", X"8a", X"bc", 
  X"36", X"94", X"0e", X"c4", X"00", X"d4", X"a0", X"22", 
  X"12", X"80", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"00", X"85", X"30", X"27", 
  X"3c", X"14", X"05", X"41", X"36", X"94", X"01", X"01", 
  X"00", X"d4", X"a0", X"22", X"12", X"80", X"00", X"02", 
  X"00", X"00", X"00", X"00", X"23", X"9c", X"00", X"01", 
  X"03", X"dc", X"f0", X"20", X"17", X"80", X"00", X"07", 
  X"00", X"00", X"00", X"00", X"3c", X"04", X"bf", X"c0", 
  X"24", X"84", X"05", X"fd", X"0f", X"f0", X"01", X"70", 
  X"00", X"00", X"00", X"00", X"0b", X"f0", X"01", X"3b", 
  X"00", X"00", X"00", X"00", X"3c", X"04", X"bf", X"c0", 
  X"24", X"84", X"06", X"01", X"0f", X"f0", X"01", X"70", 
  X"00", X"00", X"00", X"00", X"3c", X"04", X"bf", X"c0", 
  X"24", X"84", X"06", X"83", X"0f", X"f0", X"01", X"70", 
  X"00", X"00", X"00", X"00", X"34", X"1c", X"00", X"00", 
  X"3c", X"04", X"78", X"9a", X"34", X"84", X"bc", X"de", 
  X"3c", X"05", X"8a", X"bc", X"34", X"a5", X"de", X"f0", 
  X"14", X"a0", X"00", X"02", X"00", X"85", X"00", X"1b", 
  X"00", X"07", X"00", X"0d", X"00", X"00", X"38", X"12", 
  X"00", X"00", X"40", X"12", X"00", X"00", X"48", X"10", 
  X"24", X"08", X"00", X"00", X"01", X"08", X"40", X"22", 
  X"11", X"00", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"3c", X"08", X"78", X"9a", 
  X"35", X"08", X"bc", X"de", X"01", X"28", X"40", X"22", 
  X"11", X"00", X"00", X"02", X"00", X"00", X"00", X"00", 
  X"23", X"9c", X"00", X"01", X"03", X"dc", X"f0", X"20", 
  X"17", X"80", X"00", X"07", X"00", X"00", X"00", X"00", 
  X"3c", X"04", X"bf", X"c0", X"24", X"84", X"05", X"fd", 
  X"0f", X"f0", X"01", X"70", X"00", X"00", X"00", X"00", 
  X"0b", X"f0", X"01", X"62", X"00", X"00", X"00", X"00", 
  X"3c", X"04", X"bf", X"c0", X"24", X"84", X"06", X"01", 
  X"0f", X"f0", X"01", X"70", X"00", X"00", X"00", X"00", 
  X"17", X"c0", X"00", X"07", X"00", X"00", X"00", X"00", 
  X"3c", X"04", X"bf", X"c0", X"24", X"84", X"06", X"08", 
  X"0f", X"f0", X"01", X"70", X"00", X"00", X"00", X"00", 
  X"0b", X"f0", X"01", X"68", X"00", X"00", X"00", X"00", 
  X"3c", X"04", X"bf", X"c0", X"24", X"84", X"06", X"17", 
  X"0f", X"f0", X"01", X"70", X"00", X"00", X"00", X"00", 
  X"0b", X"f0", X"01", X"68", X"00", X"00", X"00", X"00", 
  X"3c", X"05", X"20", X"00", X"80", X"82", X"00", X"00", 
  X"10", X"40", X"00", X"04", X"20", X"84", X"00", X"01", 
  X"a0", X"a2", X"00", X"00", X"10", X"00", X"ff", X"fb", 
  X"00", X"00", X"00", X"00", X"03", X"e0", X"00", X"08", 
  X"00", X"00", X"00", X"00", X"49", X"4f", X"4e", X"20", 
  X"4d", X"49", X"50", X"53", X"20", X"6f", X"70", X"63", 
  X"6f", X"64", X"65", X"20", X"74", X"65", X"73", X"74", 
  X"65", X"72", X"0a", X"0a", X"00", X"4f", X"4b", X"0a", 
  X"00", X"45", X"52", X"52", X"4f", X"52", X"0a", X"00", 
  X"0a", X"54", X"65", X"73", X"74", X"20", X"50", X"41", 
  X"53", X"53", X"45", X"44", X"0a", X"0a", X"00", X"0a", 
  X"54", X"65", X"73", X"74", X"20", X"46", X"41", X"49", 
  X"4c", X"45", X"44", X"0a", X"0a", X"00", X"4c", X"6f", 
  X"61", X"64", X"20", X"69", X"6e", X"74", X"65", X"72", 
  X"6c", X"6f", X"63", X"6b", X"73", X"2e", X"2e", X"2e", 
  X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", 
  X"2e", X"2e", X"2e", X"20", X"00", X"41", X"64", X"64", 
  X"2a", X"2f", X"53", X"75", X"62", X"2a", X"20", X"6f", 
  X"70", X"63", X"6f", X"64", X"65", X"73", X"2e", X"2e", 
  X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", 
  X"2e", X"2e", X"20", X"00", X"4c", X"6f", X"67", X"69", 
  X"63", X"20", X"6f", X"70", X"63", X"6f", X"64", X"65", 
  X"73", X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", 
  X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", 
  X"2e", X"20", X"00", X"4d", X"75", X"6c", X"2a", X"2f", 
  X"44", X"69", X"76", X"2a", X"20", X"6f", X"70", X"63", 
  X"6f", X"64", X"65", X"73", X"2e", X"2e", X"2e", X"2e", 
  X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", X"2e", 
  X"20", X"00", X"00", X"00", X"3c", X"1b", X"00", X"00", 
  X"27", X"7b", X"00", X"3c", X"af", X"7d", X"ff", X"f0", 
  X"af", X"7f", X"ff", X"ec", X"af", X"68", X"ff", X"e8", 
  X"af", X"69", X"ff", X"e4", X"af", X"6a", X"ff", X"e0", 
  X"03", X"60", X"e8", X"21", X"40", X"08", X"70", X"00", 
  X"8d", X"1a", X"00", X"00", X"40", X"1b", X"68", X"00", 
  X"07", X"70", X"00", X"2d", X"00", X"00", X"00", X"00", 
  X"00", X"1a", X"4e", X"82", X"39", X"28", X"00", X"1f", 
  X"11", X"00", X"00", X"1f", X"39", X"28", X"00", X"1c", 
  X"11", X"00", X"00", X"13", X"00", X"00", X"00", X"00", 
  X"3c", X"08", X"20", X"01", X"ad", X"1a", X"04", X"00", 
  X"8f", X"aa", X"ff", X"e0", X"8f", X"a9", X"ff", X"e4", 
  X"8f", X"a8", X"ff", X"e8", X"8f", X"bf", X"ff", X"ec", 
  X"8f", X"bd", X"ff", X"f0", X"40", X"1b", X"70", X"00", 
  X"40", X"1a", X"68", X"00", X"00", X"1a", X"d7", X"c2", 
  X"33", X"5a", X"00", X"01", X"17", X"40", X"00", X"03", 
  X"23", X"7b", X"00", X"04", X"03", X"60", X"00", X"08", 
  X"00", X"00", X"00", X"00", X"23", X"7b", X"00", X"04", 
  X"03", X"60", X"00", X"08", X"42", X"00", X"00", X"10", 
  X"33", X"5b", X"00", X"3f", X"3b", X"68", X"00", X"20", 
  X"11", X"00", X"00", X"14", X"3b", X"68", X"00", X"21", 
  X"11", X"00", X"00", X"1c", X"00", X"00", X"00", X"00", 
  X"3c", X"08", X"20", X"01", X"ad", X"1a", X"04", X"00", 
  X"0b", X"f0", X"01", X"be", X"00", X"00", X"00", X"00", 
  X"33", X"5b", X"00", X"3f", X"3b", X"68", X"00", X"00", 
  X"11", X"00", X"00", X"1e", X"3b", X"68", X"00", X"04", 
  X"11", X"00", X"00", X"29", X"00", X"00", X"00", X"00", 
  X"3c", X"08", X"20", X"01", X"ad", X"1a", X"04", X"00", 
  X"0b", X"f0", X"01", X"be", X"00", X"00", X"00", X"00", 
  X"8d", X"1a", X"00", X"04", X"03", X"e0", X"00", X"08", 
  X"00", X"00", X"00", X"00", X"0f", X"f0", X"02", X"68", 
  X"3c", X"0a", X"80", X"00", X"00", X"00", X"40", X"21", 
  X"03", X"6a", X"48", X"24", X"15", X"20", X"00", X"03", 
  X"00", X"0a", X"50", X"42", X"15", X"40", X"ff", X"fc", 
  X"25", X"08", X"00", X"01", X"0b", X"f0", X"02", X"1e", 
  X"01", X"00", X"d8", X"21", X"0f", X"f0", X"02", X"68", 
  X"3c", X"0a", X"80", X"00", X"00", X"00", X"40", X"21", 
  X"03", X"6a", X"48", X"24", X"11", X"20", X"00", X"03", 
  X"00", X"0a", X"50", X"42", X"15", X"40", X"ff", X"fc", 
  X"25", X"08", X"00", X"01", X"0b", X"f0", X"02", X"1e", 
  X"01", X"00", X"d8", X"21", X"0f", X"f0", X"02", X"68", 
  X"00", X"00", X"00", X"00", X"00", X"1a", X"41", X"82", 
  X"31", X"08", X"00", X"1f", X"00", X"1a", X"4a", X"c2", 
  X"31", X"29", X"00", X"1f", X"01", X"09", X"50", X"21", 
  X"00", X"0a", X"50", X"23", X"25", X"4a", X"00", X"1f", 
  X"01", X"5b", X"d8", X"04", X"01", X"5b", X"d8", X"06", 
  X"0b", X"f0", X"02", X"1e", X"01", X"1b", X"d8", X"06", 
  X"0f", X"f0", X"02", X"68", X"00", X"00", X"00", X"00", 
  X"00", X"1a", X"41", X"82", X"31", X"08", X"00", X"1f", 
  X"00", X"1a", X"4a", X"c2", X"31", X"29", X"00", X"1f", 
  X"01", X"28", X"48", X"23", X"00", X"09", X"58", X"23", 
  X"25", X"6b", X"00", X"1f", X"01", X"1b", X"48", X"04", 
  X"3c", X"0a", X"ff", X"ff", X"35", X"4a", X"ff", X"ff", 
  X"01", X"6a", X"50", X"04", X"01", X"6a", X"50", X"06", 
  X"01", X"0a", X"50", X"04", X"01", X"2a", X"48", X"24", 
  X"01", X"40", X"50", X"27", X"0f", X"f0", X"02", X"68", 
  X"00", X"1a", X"d1", X"40", X"00", X"1a", X"d1", X"42", 
  X"03", X"6a", X"d8", X"24", X"03", X"69", X"d8", X"25", 
  X"0b", X"f0", X"02", X"1e", X"00", X"00", X"00", X"00", 
  X"00", X"1a", X"4c", X"02", X"31", X"29", X"00", X"1f", 
  X"3c", X"08", X"bf", X"c0", X"25", X"08", X"08", X"a0", 
  X"00", X"09", X"48", X"c0", X"01", X"09", X"40", X"20", 
  X"01", X"00", X"00", X"08", X"00", X"00", X"00", X"00", 
  X"0b", X"f0", X"01", X"be", X"00", X"00", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"60", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"61", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"62", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"63", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"64", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"65", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"66", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"67", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"af", X"bb", X"ff", X"e8", 
  X"0b", X"f0", X"02", X"26", X"af", X"bb", X"ff", X"e4", 
  X"0b", X"f0", X"02", X"26", X"af", X"bb", X"ff", X"e0", 
  X"0b", X"f0", X"02", X"26", X"37", X"6b", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"6c", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"6d", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"6e", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"6f", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"70", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"71", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"72", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"73", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"74", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"75", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"76", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"77", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"78", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"79", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"7a", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"7b", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"37", X"7c", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"af", X"bb", X"ff", X"ec", 
  X"0b", X"f0", X"02", X"26", X"37", X"7e", X"00", X"00", 
  X"0b", X"f0", X"02", X"26", X"af", X"bb", X"ff", X"f0", 
  X"af", X"bf", X"00", X"00", X"00", X"1a", X"dd", X"42", 
  X"33", X"7b", X"00", X"1f", X"3c", X"08", X"bf", X"c0", 
  X"25", X"08", X"09", X"d0", X"00", X"1b", X"d8", X"c0", 
  X"01", X"1b", X"40", X"20", X"01", X"00", X"f8", X"09", 
  X"00", X"00", X"00", X"00", X"8f", X"bf", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"00", X"00", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"34", X"1b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"34", X"3b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"34", X"5b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"34", X"7b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"34", X"9b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"34", X"bb", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"34", X"db", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"34", X"fb", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"8f", X"bb", X"ff", X"e8", 
  X"03", X"e0", X"00", X"08", X"8f", X"bb", X"ff", X"e4", 
  X"03", X"e0", X"00", X"08", X"8f", X"bb", X"ff", X"e0", 
  X"03", X"e0", X"00", X"08", X"35", X"7b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"35", X"9b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"35", X"bb", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"35", X"db", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"35", X"fb", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"36", X"1b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"36", X"3b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"36", X"5b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"36", X"7b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"36", X"9b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"36", X"bb", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"36", X"db", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"36", X"fb", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"37", X"1b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"37", X"3b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"37", X"5b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"37", X"7b", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"37", X"9a", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"8f", X"bb", X"ff", X"f0", 
  X"03", X"e0", X"00", X"08", X"37", X"db", X"00", X"00", 
  X"03", X"e0", X"00", X"08", X"8f", X"bb", X"ff", X"ec" 
  );

constant INIT_DATA : t_obj_code(0 to 0) := (others => X"00");


end package OBJ_CODE_PKG;
