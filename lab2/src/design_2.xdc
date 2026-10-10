# KV260 has no on-board PL oscillator or reset pin. Pins below are the carrier
# bank45_gpio connections from the board files (HDGC pin for the clock).
# Bank 45 VCCO is assumed 3.3 V; confirm against the carrier schematic.

# 100 MHz, 50% duty clock input (bank45_gpio_3, SOM240_1 A15)
set_property PACKAGE_PIN F11 [get_ports clk_100m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100m]
create_clock -name clk_100m -period 10.000 -waveform {0.000 5.000} [get_ports clk_100m]

# Active-low reset input (bank45_gpio_0, SOM240_1 D18)
set_property PACKAGE_PIN J11 [get_ports resetn]
set_property IOSTANDARD LVCMOS33 [get_ports resetn]
set_property PULLUP true [get_ports resetn]
set_false_path -from [get_ports resetn]
