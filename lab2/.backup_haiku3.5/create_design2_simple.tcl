# ============================================================================
# Design_2 Block Design Creation Script (Simplified)
# ============================================================================
# Changes from design_1:
# 1. BRAM: 8KÁEport ↁE4K×true dual port (A:0x0000, B:0x1000)
# 2. Clock/Reset: External ports (clk_100m, resetn)
# 3. PS Clock: 100MHz ↁE400MHz (via Clock Wizard)
# 4. Other IPs: 100MHz (unchanged)
# ============================================================================

puts "\n========== Creating design_2 =========="

# Step 1: Create new block design
puts "\nStep 1 Creating new block design..."
if {[file exists lab2.srcs/sources_1/bd/design_2]} {
    puts "Note: design_2 directory exists, contents will be updated"
}
set bd [create_bd_design -name design_2 -dir lab2.srcs/sources_1/bd/design_2]
puts "✁EBlock design created: $bd"

# Step 2: Create external ports
puts "\nStep 2 Creating external clock/reset ports..."
set clk_port [create_bd_port -name clk_100m -type CLK -dir I -freq_hz 100000000]
set_property -dict [list CONFIG.FREQ_HZ 100000000] $clk_port

set rst_port [create_bd_port -name resetn -type RST -dir I]
set_property -dict [list CONFIG.POLARITY ACTIVE_LOW] $rst_port

puts "✁EExternal ports created: clk_100m (100MHz), resetn (active low)"

# Step 3: Instantiate IP cores
puts "\nStep 3 Instantiating IP cores..."

# 3.1 Zynq Ultrascale PS
puts "  Adding Zynq PS..."
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0]
set_property -dict [list \
    CONFIG.PSU_MIO_0_PULLCTRL {Disable} \
    CONFIG.PSU_MIO_48_PULLCTRL {Disable} \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
] $ps

# 3.2 Clock Wizard (100MHz -> 400MHz)
puts "  Adding Clock Wizard..."
set clk_wiz [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0]
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ.VALUE_SRC {USER} \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {400.000} \
    CONFIG.USE_DYN_RECONFIG {false} \
] $clk_wiz

# 3.3 Processor System Reset
puts "  Adding Processor System Reset..."
set psr [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0]

# 3.4 AXI DMA
puts "  Adding AXI DMA..."
set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0]
set_property -dict [list \
    CONFIG.c_sg_length_width {26} \
    CONFIG.c_m_axi_mm2s_data_width {64} \
    CONFIG.c_m_axi_s2mm_data_width {64} \
] $dma

# 3.5 AXI Timer
puts "  Adding AXI Timer..."
set timer [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer:2.0 axi_timer_0]

# 3.6 Block Memory Generator (4K x32 true dual port)
puts "  Adding BRAM (4K x32 true dual port)..."
set bram [create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0]
set_property -dict [list \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Write_Width_A {32} \
    CONFIG.Write_Depth_A {4096} \
    CONFIG.Read_Width_A {32} \
    CONFIG.Write_Width_B {32} \
    CONFIG.Read_Width_B {32} \
] $bram

# 3.7 AXI BRAM Controller
puts "  Adding AXI BRAM Controller..."
set bram_ctrl [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0]
set_property -dict [list \
    CONFIG.C_BRAM_INST_MODE {EXTERNAL} \
    CONFIG.C_ECC {0} \
] $bram_ctrl

# 3.8 Custom AXI-Stream Filter
puts "  Adding AXI-Stream Filter..."
set filter [create_bd_cell -type module -reference axis_filter axis_filter_0]

# 3.9 AXI Interconnect
puts "  Adding AXI Interconnect..."
set ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0]
set_property -dict [list CONFIG.NUM_MI {3} CONFIG.NUM_SI {1}] $ic

# 3.10 xlconcat (Interrupt aggregation)
puts "  Adding xlconcat..."
set concat [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0]
set_property -dict [list CONFIG.NUM_PORTS {2}] $concat

# Step 4: Connect clocks and resets
puts "\nStep 4 Connecting clocks and resets..."

# External clk_100m connections
connect_bd_net [get_bd_ports clk_100m] [get_bd_pins clk_wiz_0/clk_in1]
connect_bd_net [get_bd_ports clk_100m] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_ports clk_100m] [get_bd_pins axi_dma_0/m_axi_mm2s_aclk]
connect_bd_net [get_bd_ports clk_100m] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk]
connect_bd_net [get_bd_ports clk_100m] [get_bd_pins axi_dma_0/s_axi_lite_aclk]
connect_bd_net [get_bd_ports clk_100m] [get_bd_pins axi_timer_0/s_axi_aclk]
connect_bd_net [get_bd_ports clk_100m] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk]
connect_bd_net [get_bd_ports clk_100m] [get_bd_pins axis_filter_0/aclk]
connect_bd_net [get_bd_ports clk_100m] [get_bd_pins axi_interconnect_0/ACLK]
connect_bd_net [get_bd_ports clk_100m] [get_bd_pins blk_mem_gen_0/clka]
connect_bd_net [get_bd_ports clk_100m] [get_bd_pins blk_mem_gen_0/clkb]

puts "  ✁E100MHz clock distribution complete"

# External resetn connections
connect_bd_net [get_bd_ports resetn] [get_bd_pins proc_sys_reset_0/ext_reset_in]

# Peripheral reset from PSR
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_dma_0/axi_resetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_timer_0/s_axi_aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axis_filter_0/aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_interconnect_0/ARESETN]

puts "  ✁EReset distribution complete"

# Step 5: Connect data paths
puts "\nStep 5 Connecting data paths..."

# DMA MM2S -> axis_filter -> DMA S2MM
connect_bd_intf_net -intf_net dma_mm2s_filter [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins axis_filter_0/s_axis]
connect_bd_intf_net -intf_net filter_dma_s2mm [get_bd_intf_pins axis_filter_0/m_axis] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

puts "  ✁EDMA MM2S -> Filter -> DMA S2MM connected"

# PS AXI GP0 -> Interconnect
connect_bd_intf_net -intf_net ps_axi_gp0 [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] [get_bd_intf_pins axi_interconnect_0/S00_AXI]

# Interconnect -> AXI DMA, AXI Timer, BRAM Controller
connect_bd_intf_net -intf_net ic_dma [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
connect_bd_intf_net -intf_net ic_timer [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins axi_timer_0/S_AXI]
connect_bd_intf_net -intf_net ic_bram [get_bd_intf_pins axi_interconnect_0/M02_AXI] [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]

puts "  ✁EInterconnect connections complete"

# DMA data paths -> BRAM Controller

puts "  ✁EDMA data transfer paths to BRAM connected"

# BRAM Controller -> BRAM ports
connect_bd_intf_net -intf_net bram_porta [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]
connect_bd_intf_net -intf_net bram_portb [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTB] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTB]

puts "  ✁EBRAM port A and B connected"

# Step 6: Interrupt aggregation
puts "\nStep 6 Configuring interrupts..."

connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins axi_timer_0/interrupt] [get_bd_pins xlconcat_0/In1]

puts "  ✁EInterrupts: DMA MM2S + Timer aggregated"

# Step 7: Configure address map
puts "\nStep 7 Configuring address map..."


puts "  ✁EAddress segments assigned:"
puts "    DMA Base:       0xA0000000"
puts "    Timer Base:     0xA0010000"
puts "    BRAM Base:      0xA0020000"
puts "      Port A:       0xA0020000 (0x0000 - 0x0FFF)"
puts "      Port B:       0xA0021000 (0x1000 - 0x1FFF)"

# Step 8: Save design
puts "\nStep 8 Saving block design..."
save_bd_design

puts "\n✁Edesign_2 block design creation complete!"
puts ""
puts "Next steps:"
puts "  1. Run: validate_bd_design"
puts "  2. Run: generate_target all get_files design_2.bd"
puts "  3. Save files to update/ directory"
puts ""
puts "Key differences from design_1:"
puts "  • External clk_100m (100MHz) and resetn ports"
puts "  • Clock Wizard: 100MHz -> 400MHz (for PS)"
puts "  • BRAM: 4K true dual port (A:0xA0020000, B:0xA0021000)"
puts "  • Other IPs: Still use 100MHz clock"
puts ""
