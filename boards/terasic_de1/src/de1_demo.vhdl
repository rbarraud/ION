--##############################################################################
-- de1_demo.vhdl -- ION CPU demo on Terasic DE-1 Cyclone-II starter board.
--##############################################################################
-- This module is little more than a wrapper around the application entity.
--------------------------------------------------------------------------------
-- Switch 9 (leftmost) is used as reset.
--------------------------------------------------------------------------------
-- NOTE: See note at bottom of file about optional use of PLL.
--##############################################################################
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
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- Hardware parameters & memory contents from SW build (generated package).
use work.OBJ_CODE_PKG.all;

-- Top entity is a generic wrapper with all the I/O of Terasic DE-1 board.
-- (Many of the board's i/o devices will go unused in this demo)
entity de1_demo is
    port (
        -- ***** Clocks
        clk_50MHz     : in std_logic;
        clk_27MHz     : in std_logic;

        -- ***** Flash 4MB
        flash_addr    : out std_logic_vector(21 downto 0);
        flash_data    : in std_logic_vector(7 downto 0);
        flash_oe_n    : out std_logic;
        flash_we_n    : out std_logic;
        flash_reset_n : out std_logic;

        -- ***** SRAM 256K x 16
        sram_addr     : out std_logic_vector(17 downto 0);
        sram_data     : inout std_logic_vector(15 downto 0);
        sram_oe_n     : out std_logic;
        sram_ub_n     : out std_logic;
        sram_lb_n     : out std_logic;
        sram_ce_n     : out std_logic;
        sram_we_n     : out std_logic;

        -- ***** RS-232
        rxd           : in std_logic;
        txd           : out std_logic;

        -- ***** Switches and buttons
        switches      : in std_logic_vector(9 downto 0);
        buttons       : in std_logic_vector(3 downto 0);

        -- ***** Quad 7-seg displays
        hex0          : out std_logic_vector(0 to 6);
        hex1          : out std_logic_vector(0 to 6);
        hex2          : out std_logic_vector(0 to 6);
        hex3          : out std_logic_vector(0 to 6);

        -- ***** Leds
        red_leds      : out std_logic_vector(9 downto 0);
        green_leds    : out std_logic_vector(7 downto 0);

        -- ***** SD Card
        sd_data       : in  std_logic;
        sd_cs         : out std_logic;
        sd_cmd        : out std_logic;
        sd_clk        : out std_logic
    );
end de1_demo;

architecture minimal of de1_demo is


--##############################################################################
-- Parameters of the demo board (MPU parameters are set in a gnerated package).

-- Clock rate selection (affects UART configuration)
-- Acceptable values: {27000000, 50000000, 45000000(pll config)}
constant CLOCK_FREQ : integer := 50000000;


--##############################################################################
-- I/O registers.

signal p0_out :             std_logic_vector(31 downto 0);
signal p1_in :              std_logic_vector(31 downto 0);


--##############################################################################
-- DE-1 board interface signals

-- Synchronization FF chain for asynchronous reset input
signal reset_sync :         std_logic_vector(3 downto 0);

-- Reset pushbutton debouncing logic
subtype t_debouncer is natural range 0 to CLOCK_FREQ*4;
constant DEBOUNCING_DELAY : t_debouncer := 1500;
signal debouncing_counter : t_debouncer := (CLOCK_FREQ/1000) * DEBOUNCING_DELAY;

-- Quad 7-segment display (non multiplexed) & LEDS
signal display_data :       std_logic_vector(15 downto 0);
signal reg_gleds :          std_logic_vector(7 downto 0);

-- Clock & reset signals
signal clk_1hz :            std_logic;
signal clk_master :         std_logic;
signal counter_1hz :        std_logic_vector(25 downto 0);
signal reset :              std_logic;
-- Master clock signal
signal clk :                std_logic;
-- Clock from PLL, if a PLL is used
signal clk_pll :            std_logic;
-- '1' when PLL is locked or when no PLL is used
signal pll_locked :         std_logic;

-- Altera PLL component declaration (in case it's used)
-- Note that the MegaWizard component needs to be called 'pll' or the component
-- name should be changed in this file.
--component pll
--    port (
--        areset      : in std_logic  := '0';
--        inclk0      : in std_logic  := '0';
--        c0          : out std_logic ;
--        locked      : out std_logic
--    );
--end component;

-- MPU interface signals

constant SRAM_SIZE : integer := 256 * 1024;
constant SRAM_ADDR_SIZE : integer := 18;

signal mpu_sram_addr :      std_logic_vector(SRAM_ADDR_SIZE downto 1);
signal mpu_sram_data_in :   std_logic_vector(15 downto 0);
signal mpu_sram_data_out :  std_logic_vector(15 downto 0);
signal sram_output :        std_logic_vector(15 downto 0);
signal sram_wen :           std_logic;
signal sram_ben :           std_logic_vector(1 downto 0);
signal sram_oen :           std_logic;
signal sram_cen :           std_logic;
signal sram_drive_en :      std_logic;         

signal irq :                std_logic_vector(5 downto 0);
signal port0_out :          std_logic_vector(15 downto 0);
signal port0_in :           std_logic_vector(15 downto 0);



-- Converts hex nibble to 7-segment
-- Segments ordered as "GFEDCBA"; '0' is ON, '1' is OFF
function nibble_to_7seg(nibble : std_logic_vector(3 downto 0))
                        return std_logic_vector is
begin
    case nibble is
    when X"0"       => return "0000001";
    when X"1"       => return "1001111";
    when X"2"       => return "0010010";
    when X"3"       => return "0000110";
    when X"4"       => return "1001100";
    when X"5"       => return "0100100";
    when X"6"       => return "0100000";
    when X"7"       => return "0001111";
    when X"8"       => return "0000000";
    when X"9"       => return "0000100";
    when X"a"       => return "0001000";
    when X"b"       => return "1100000";
    when X"c"       => return "0110001";
    when X"d"       => return "1000010";
    when X"e"       => return "0110000";
    when X"f"       => return "0111000";
    when others     => return "0111111"; -- can't happen
    end case;
end function nibble_to_7seg;


begin

--##############################################################################
-- CPU application core instance
--##############################################################################


    mpu: entity work.ION_APPLICATION
    generic map (
        TCM_CODE_SIZE =>        CODE_MEM_SIZE,
        TCM_CODE_INIT =>        OBJ_CODE,
        TCM_DATA_SIZE =>        DATA_MEM_SIZE,
        
        SRAM_SIZE =>            SRAM_SIZE,
        
        DATA_CACHE_LINES =>     128,
        CODE_CACHE_LINES =>     0
    )
    port map (
        CLK_I               => clk_50MHz,
        RESET_I             => reset, 

        SRAM_ADDR_O         => mpu_sram_addr,
        SRAM_DATA_O         => mpu_sram_data_out,
        SRAM_DATA_I         => mpu_sram_data_in,
        SRAM_WEn_O          => sram_wen, 
        SRAM_OEn_O          => sram_oen, 
        SRAM_UBn_O          => sram_ben(1), 
        SRAM_LBn_O          => sram_ben(0), 
        SRAM_CEn_O          => sram_cen,
        SRAM_DRIVE_EN_O     => sram_drive_en,
        
        IRQ_I               => irq,
        
        GPIO_0_OUT_O        => port0_out,
        GPIO_0_INP_I        => port0_in
    );

    -- FIXME HW interrupts not connected.
    irq <= (others => '0');
    
    -- FIXME GPIO ports looped back as in the simulation TBs.
    port0_in <= port0_out;
    
    -- Make sure we don't attempt to infer more RAM than the DE-1 chip has.
    -- We'll define arbitrary bounds for the code and data TCMs; remember that
    -- TCM sizes are in 32-bit words.
    
    assert CODE_MEM_SIZE <= 4096
    report "Code TCM size too large for target chip."
    severity failure;
    
    assert DATA_MEM_SIZE <= 2048
    report "Data TCM size too large for target chip."
    severity failure;
    
    
--##############################################################################
-- GPIO and LEDs
--##############################################################################

---- LEDS -- We'll use the LEDs to display debug info --------------------------

-- Show the SD interface signals on the green leds for debug
reg_gleds <= p1_in(0) & "0000" & p0_out(2 downto 0);

-- Red leds (light with '1') -- some CPU control signals
red_leds(0) <= '0';
red_leds(1) <= '0';
red_leds(2) <= '0';
red_leds(3) <= '0';
red_leds(4) <= '0';
red_leds(5) <= '0';
red_leds(6) <= '0';
red_leds(7) <= '0';
red_leds(8) <= reset;
red_leds(9) <= clk_1hz;


--##############################################################################
-- terasIC Cyclone II STARTER KIT BOARD -- interface to on-board devices
--##############################################################################

--##############################################################################
-- FLASH
--##############################################################################

-- The FLASH memory is not used in this demo.
flash_we_n <= '1';
flash_reset_n <= '1';
flash_addr <= (others => '0');
flash_oe_n <= '1';


--##############################################################################
-- SRAM
--##############################################################################

-- The SRAM pins are wired straight into the SRAM interface of the MPU core.
sram_addr <= mpu_sram_addr(SRAM_ADDR_SIZE downto 1);
sram_oe_n <= sram_oen;
sram_data <=
    mpu_sram_data_out when sram_drive_en='1' else 
    (others => 'Z');
mpu_sram_data_in <= sram_data;

sram_ub_n <= sram_ben(1);
sram_lb_n <= sram_ben(0);
sram_ce_n <= sram_cen;
sram_we_n <= sram_wen;


--##############################################################################
-- RESET, CLOCK
--##############################################################################


-- This FF chain only prevents metastability trouble, it does not help with
-- switching bounces.
-- (NOTE: the anti-metastability logic is probably not needed when we include 
-- the debouncing logic)
reset_synchronization:
process(clk)
begin
    if clk'event and clk='1' then
        reset_sync(3) <= not switches(9);
        reset_sync(2) <= reset_sync(3);
        reset_sync(1) <= reset_sync(2);
        reset_sync(0) <= reset_sync(1);
    end if;
end process reset_synchronization;

reset_debouncing:
process(clk)
begin
    if clk'event and clk='1' then
        if reset_sync(0)='1' and reset_sync(1)='0' then
            debouncing_counter <= (CLOCK_FREQ/1000) * DEBOUNCING_DELAY;
        else
            if debouncing_counter /= 0 then
                debouncing_counter <= debouncing_counter - 1;
            end if;
        end if;
    end if;
end process reset_debouncing;

-- Reset will be active and glitch free for some serious time (1.5 s).
reset <= '1' when debouncing_counter /= 0 or pll_locked='0' else '0';

-- Generate a 1-Hz 'clock' to flash a LED for visual reference.
process(clk)
begin
  if clk'event and clk='1' then
    if reset = '1' then
      clk_1hz <= '0';
      counter_1hz <= (others => '0');
    else
      if conv_integer(counter_1hz) = CLOCK_FREQ-1 then
        counter_1hz <= (others => '0');
        clk_1hz <= not clk_1hz;
      else
        counter_1hz <= counter_1hz + 1;
      end if;
    end if;
  end if;
end process;

-- Master clock is external 50MHz or 27MHz oscillator

slow_clock:
if CLOCK_FREQ = 27000000 generate
clk <= clk_27MHz;
pll_locked <=  '1';
end generate;

fast_clock:
if CLOCK_FREQ = 50000000 generate
clk <= clk_50MHz;
pll_locked <=  '1';
end generate;

--pll_clock:
--if CLOCK_FREQ /= 27000000 and CLOCK_FREQ/=50000000 generate
---- Assume PLL black box is properly configured for whatever the clock rate is...
--input_clock_pll: component pll
--    port map(
--        areset  => '0',
--        inclk0  => clk_50MHz,
--        c0      => clk_pll,
--        locked  => pll_locked
--    );
--
--clk <= clk_pll;
--end generate;


--##############################################################################
-- LEDS, SWITCHES
--##############################################################################

-- Display the contents of a debug register at the green leds bar
green_leds <= reg_gleds;


--##############################################################################
-- QUAD 7-SEGMENT DISPLAYS
--##############################################################################

-- Show contents of debug register in hex display
display_data <= port0_out;
    

-- 7-segment encoders; the dev board displays are not multiplexed or encoded
hex3 <= nibble_to_7seg(display_data(15 downto 12));
hex2 <= nibble_to_7seg(display_data(11 downto  8));
hex1 <= nibble_to_7seg(display_data( 7 downto  4));
hex0 <= nibble_to_7seg(display_data( 3 downto  0));

--##############################################################################
-- SD card interface
--##############################################################################

-- Connect to FFs for use in bit-banged interface (still unused)
sd_cs       <= p0_out(0);       -- SPI CS
sd_cmd      <= p0_out(2);       -- SPI DI
sd_clk      <= p0_out(1);       -- SPI SCLK
p1_in(0)    <= sd_data;         -- SPI DO


--##############################################################################
-- SERIAL
--##############################################################################

--  Embedded in the MPU entity

end minimal;

--------------------------------------------------------------------------------
-- NOTE: Optional use of a PLL
-- 
-- In order to try the core with any clock other the 50 and 27MHz oscillators 
-- readily available onboard we need to use a PLL.
-- Unfortunately, Quartus-II won't let you just instantiate a PLL like ISE does.
-- Instead, you have to build a PLL module using the MegaWizard tool.
-- A nasty consequence of this is that the PLL can't be reconfigured without
-- rebuilding it with the MW tool, and a bunch of ugly binary files have to be 
-- committed to SVN if the project is to be complete.
-- When I figure up what files need to be committed to SVN I will. Meanwhile you
-- have to build the module yourself if you want to use a PLL -- Sorry!
-- At least it is very straightforward -- create an ALTPLL variation (from the 
-- IO module library) named 'pll' with a 45MHz clock at output c0, that's it.
--
-- Please note that the system will run at >50MHz when using 'balanced' 
-- synthesis. Only the 'area optimized' synthesis may give you trouble.
--------------------------------------------------------------------------------
