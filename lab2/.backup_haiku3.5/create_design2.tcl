# design_2 ブロックデザイン作成スクリプト

# ========== Step 1: design_1 をコピーして design_2 を作成 ==========
puts "Step 1: Copying design_1 to design_2..."

set bd_path "lab2.srcs/sources_1/bd"
set design_1_path "$bd_path/design_1/design_1.bd"

# design_2 ディレクトリ作成
file mkdir "$bd_path/design_2"

# TCL ファイル取得 (design_1の TCL ファイルをコピー)
if {[file exists "$bd_path/design_1/design_1.tcl"]} {
    file copy "$bd_path/design_1/design_1.tcl" "$bd_path/design_2/design_2.tcl"
    puts "✓ Copied design_1.tcl to design_2.tcl"
} else {
    puts "! design_1.tcl not found (may be auto-generated)"
}

# design_2 を新しいブロックデザインとしてオープン
puts "\nStep 2: Creating new block design design_2..."
set design_2 [create_bd_design -name design_2 -dir "$bd_path/design_2"]
puts "✓ Block design 'design_2' created: $design_2"

# ========== Step 3: design_1 から IP を copy する方法は使用不可なため、
# 手動で IP をインスタンスする ==========
puts "\nStep 3: Instantiating IP cores in design_2..."

# ターゲットデザインを design_2 に設定
current_bd_design $design_2

# クロック/リセット入力ポート作成
puts "  - Creating external clock/reset ports..."
set clk_port [create_bd_port -name clk_100m -type CLK -dir I]
set_property -dict [list CONFIG.FREQ_HZ 100000000] $clk_port

set rst_port [create_bd_port -name resetn -type RST -dir I]
set_property -dict [list CONFIG.POLARITY ACTIVE_LOW] $rst_port

puts "  ✓ External clk_100m (100MHz) and resetn ports created"

# Zynq Ultrascale PS
puts "  - Instantiating Zynq PS..."
set ps_cell [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 zynq_ultra_ps_e_0]
set_property -dict [list CONFIG.PSU_MIO_0_PULLCTRL {Disable} CONFIG.PSU_MIO_48_PULLCTRL {Disable} CONFIG.PSU__USE__M_AXI_GP0 {1}] $ps_cell
connect_bd_net -net clk_external [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_ports clk_100m]
connect_bd_net -net rst_external [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_ports resetn]
puts "    ✓ PS connected to external clock/reset"

# Clock Wizard (100MHz -> 400MHz)
puts "  - Instantiating Clock Wizard (100MHz -> 400MHz)..."
set clk_wiz [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0]
set_property -dict [list CONFIG.PRIM_IN_FREQ.VALUE_SRC USER] $clk_wiz
set_property -dict [list CONFIG.PRIM_IN_FREQ 100.000 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 400.000 CONFIG.USE_DYN_RECONFIG false CONFIG.USE_LOCKED false] $clk_wiz
connect_bd_net -net clk_100m_wiz [get_bd_ports clk_100m] [get_bd_pins clk_wiz_0/clk_in1]
set ps_clk_400 [get_bd_pins clk_wiz_0/clk_out1]
puts "    ✓ Clock Wizard configured: 100MHz → 400MHz"

# Processor System Reset (100MHz domain)
puts "  - Instantiating Processor System Reset..."
set proc_sys_reset [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0]
connect_bd_net -net clk_100m_psr [get_bd_ports clk_100m] [get_bd_pins proc_sys_reset_0/slowest_clk]
connect_bd_net -net rst_100m_psr [get_bd_ports resetn] [get_bd_pins proc_sys_reset_0/ext_reset_in]
puts "    ✓ Processor System Reset configured"

# AXI DMA
puts "  - Instantiating AXI DMA..."
set axi_dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0]
set_property -dict [list CONFIG.c_sg_length_width {26} CONFIG.c_m_axi_mm2s_data_width {64} CONFIG.c_m_axi_s2mm_data_width {64}] $axi_dma
connect_bd_net -net clk_100m_dma [get_bd_ports clk_100m] [get_bd_pins axi_dma_0/m_axi_mm2s_aclk]
connect_bd_net -net clk_100m_dma_s2mm [get_bd_ports clk_100m] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk]
connect_bd_net -net clk_100m_dma_lite [get_bd_ports clk_100m] [get_bd_pins axi_dma_0/s_axi_lite_aclk]
connect_bd_net -net rst_pl_dma [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_dma_0/axi_resetn]
puts "    ✓ AXI DMA configured"

# Custom AXI-Stream Filter
puts "  - Instantiating AXI-Stream Filter..."
set axis_filter [create_bd_cell -type ip -vlnv xilinx.com:user:axis_filter:1.0 axis_filter_0]
connect_bd_net -net clk_100m_filter [get_bd_ports clk_100m] [get_bd_pins axis_filter_0/aclk]
connect_bd_net -net rst_pl_filter [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axis_filter_0/aresetn]
puts "    ✓ AXI-Stream Filter configured"

# AXI Timer
puts "  - Instantiating AXI Timer..."
set axi_timer [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer:2.0 axi_timer_0]
connect_bd_net -net clk_100m_timer [get_bd_ports clk_100m] [get_bd_pins axi_timer_0/s_axi_aclk]
connect_bd_net -net rst_pl_timer [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_timer_0/s_axi_aresetn]
puts "    ✓ AXI Timer configured"

# Block Memory Generator (4K × 32-bit true dual port)
puts "  - Instantiating Block Memory (4K x32 true dual port)..."
set bram_cntrl [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_controller:4.1 axi_bram_controller_0]
set_property -dict [list CONFIG.C_BRAM_INST_MODE {EXTERNAL} CONFIG.C_ECC {0}] $bram_cntrl
connect_bd_net -net clk_100m_bram_cntrl [get_bd_ports clk_100m] [get_bd_pins axi_bram_controller_0/s_axi_aclk]
connect_bd_net -net rst_pl_bram [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_bram_controller_0/s_axi_aresetn]

# True Dual Port BRAM (4K x32 = 16K bits)
puts "  - Instantiating BRAM_TDP_MACROS (4K x32)..."
set bram_tpd [create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0]
set_property -dict [list CONFIG.Memory_Type {True_Dual_Port_RAM} CONFIG.Assume_Synchronous_Clk {true} CONFIG.Write_Width_A {32} CONFIG.Write_Depth_A {4096} CONFIG.Read_Width_A {32} CONFIG.Write_Width_B {32} CONFIG.Read_Width_B {32}] $bram_tpd
connect_bd_net -net clk_100m_bram [get_bd_ports clk_100m] [get_bd_pins blk_mem_gen_0/clka]
connect_bd_net -net clk_100m_bram_b [get_bd_ports clk_100m] [get_bd_pins blk_mem_gen_0/clkb]
puts "    ✓ BRAM True Dual Port (4K x32) configured"

# AXI Interconnect
puts "  - Instantiating AXI Interconnect..."
set axi_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0]
set_property -dict [list CONFIG.NUM_MI {3} CONFIG.NUM_SI {1}] $axi_ic
connect_bd_net -net clk_100m_ic [get_bd_ports clk_100m] [get_bd_pins axi_interconnect_0/ACLK]
connect_bd_net -net rst_pl_ic [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_interconnect_0/ARESETN]
puts "    ✓ AXI Interconnect configured"

# xlconcat (Interrupt aggregation)
puts "  - Instantiating xlconcat (interrupt aggregation)..."
set concat [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0]
set_property -dict [list CONFIG.NUM_PORTS {2}] $concat
puts "    ✓ xlconcat configured (2 inputs)"

# xlconstant (GND for unused DMA S2MM interrupt)
puts "  - Instantiating xlconstant (logic 0)..."
set const [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0]
set_property -dict [list CONFIG.CONST_VAL {0}] $const
puts "    ✓ xlconstant configured"

puts "\nStep 4: Connecting data paths..."

# DMA MM2S -> axis_filter -> DMA S2MM
connect_bd_intf_net -intf_net dma_mm2s_filter [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins axis_filter_0/axis_slave_in]
connect_bd_intf_net -intf_net filter_dma_s2mm [get_bd_intf_pins axis_filter_0/axis_slave_out] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]
puts "  ✓ DMA MM2S -> Filter -> DMA S2MM connected"

# PS AXI GP0 -> Interconnect
connect_bd_intf_net -intf_net ps_axi_gp0 [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] [get_bd_intf_pins axi_interconnect_0/S00_AXI]

# Interconnect -> AXI DMA, AXI Timer, BRAM Controller
connect_bd_intf_net -intf_net ic_dma [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
connect_bd_intf_net -intf_net ic_timer [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins axi_timer_0/S_AXI]
connect_bd_intf_net -intf_net ic_bram [get_bd_intf_pins axi_interconnect_0/M02_AXI] [get_bd_intf_pins axi_bram_controller_0/S_AXI]
puts "  ✓ Interconnect connections done"

# DMA MM2S, S2MM -> BRAM Controller
connect_bd_intf_net -intf_net dma_mm2s_bram [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins axi_bram_controller_0/S_AXI]
connect_bd_intf_net -intf_net dma_s2mm_bram [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins axi_bram_controller_0/S_AXI]
puts "  ✓ DMA data paths to BRAM connected"

# BRAM Controller -> BRAM (Port A and B)
connect_bd_intf_net -intf_net bram_ctrl_a [get_bd_intf_pins axi_bram_controller_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]
connect_bd_intf_net -intf_net bram_ctrl_b [get_bd_intf_pins axi_bram_controller_0/BRAM_PORTB] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTB]
puts "  ✓ BRAM port A and B connected"

puts "\nStep 5: Configuring address map..."

# Assign address segments
set_property offset 0xA0000000 [get_bd_addr_segs {zynq_ultra_ps_e_0/FIXED_IO/FIXED_IO}]
set_property offset 0xA0000000 [get_bd_addr_segs {axi_dma_0/S_AXI_LITE/Reg}]
set_property offset 0xA0010000 [get_bd_addr_segs {axi_timer_0/S_AXI/Reg}]
set_property offset 0xA0020000 [get_bd_addr_segs {axi_bram_controller_0/S_AXI/Mem0}]

puts "  ✓ Address segments assigned"
puts "    DMA Base: 0xA0000000"
puts "    Timer Base: 0xA0010000"
puts "    BRAM Base: 0xA0020000"
puts "      - Port A: 0xA0020000"
puts "      - Port B: 0xA0021000"

puts "\nStep 6: Configuring interrupts..."

# Interrupt connections
connect_bd_net -net dma_mm2s_irq [get_bd_pins axi_dma_0/mm2s_irq] [get_bd_pins xlconcat_0/In0]
connect_bd_net -net timer_irq [get_bd_pins axi_timer_0/interrupt] [get_bd_pins xlconcat_0/In1]
connect_bd_net -net irq_out [get_bd_pins xlconcat_0/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

puts "  ✓ Interrupts configured (DMA MM2S + Timer)"

puts "\n✅ design_2 ブロックデザイン作成完了！"
puts "Next: validate_bd_design, then generate_target"

