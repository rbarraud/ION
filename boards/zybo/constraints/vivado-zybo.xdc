# This won't actually run so be generous with the clock rate.
create_clock -period 12.0 [get_ports CLK_125MHZ_I]

set_property PACKAGE_PIN T16 [get_ports {SWITCHES_I[3]}]
set_property PACKAGE_PIN W13 [get_ports {SWITCHES_I[2]}]
set_property PACKAGE_PIN P15 [get_ports {SWITCHES_I[1]}]
set_property PACKAGE_PIN G15 [get_ports {SWITCHES_I[0]}]

set_property PACKAGE_PIN Y16 [get_ports {BUTTONS_I[3]}]
set_property PACKAGE_PIN V16 [get_ports {BUTTONS_I[2]}]
set_property PACKAGE_PIN P16 [get_ports {BUTTONS_I[1]}]
set_property PACKAGE_PIN R18 [get_ports {BUTTONS_I[0]}]

set_property PACKAGE_PIN D18 [get_ports {LEDS_O[3]}]
set_property PACKAGE_PIN G14 [get_ports {LEDS_O[2]}]
set_property PACKAGE_PIN M15 [get_ports {LEDS_O[1]}]
set_property PACKAGE_PIN M14 [get_ports {LEDS_O[0]}]

set_property PACKAGE_PIN L16 [get_ports CLK_125MHZ_I]

set_property PACKAGE_PIN W16 [get_ports PMOD_E_2_TXD_O]
set_property PACKAGE_PIN J15 [get_ports PMOD_E_3_RXD_I]

# IO standard set by default. 
# Set individually other pins that need a different standard. 
set_property IOSTANDARD LVCMOS33 [get_ports *]


