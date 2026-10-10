// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

// mreduc.sv (step4 update)
// Top-level: 8 parallel DSP pipeline channels with crossbar routing,
// per-channel statistics engines, and a configuration register bank.
// Reset is now an active-high synchronous `rst`, applied only to control/status state.

module mreduc
    #(
      parameter NUM_CHANNELS = 8,
      parameter DATA_WIDTH   = 18,
      parameter ACC_WIDTH    = 24,
      parameter NUM_TAPS     = 16,
      parameter NUM_CONFIGS  = 32
      )
    (
     input  logic                          clk,
     input  logic                          rst,
    
     input [2:0] isel, osel,bytesel,
     // Per-channel data input
     input  logic signed [DATA_WIDTH-1:0]  data_in,
     input  logic                          valid_in,

     // Coefficient broadcast (shared bus — one channel at a time)
     input  logic signed [DATA_WIDTH-1:0]  coeff_data,
     input  logic [3:0]                    coeff_addr,   // 16 taps
     input  logic [2:0]                    coeff_ch_sel, // 8 channels
     input  logic                          coeff_wr,

     // Crossbar control
     input  logic [2:0]                    xbar_src [NUM_CHANNELS-1:0],

     // Configuration register bank
     input  logic [4:0]                    cfg_addr,
     input  logic [31:0]                   cfg_wdata,
     input  logic                          cfg_wr,
     output logic [31:0]                   cfg_rdata,

     // Per-channel output (post-crossbar)
     output reg signed [ACC_WIDTH-1:0]   data_out ,
     output reg                          valid_out,
     output reg                          overflow,

     // Statistics readback (selected channel)
     input  logic [2:0]                    stat_ch_sel,
     output logic signed [7:0]   byte_min_out,
     output logic signed [7:0]   byte_max_out,
     output logic signed [7:0]   byte_mean_out,
     output logic [31:0]                   stat_count_out
     );

    // ----------------------------------------------------------------
    // Configuration register bank — high-fanout broadcast
    // ----------------------------------------------------------------
    logic [31:0] cfg_regs [NUM_CONFIGS-1:0];
    logic [NUM_CHANNELS-1:0] ch_enable;
    logic [NUM_CHANNELS-1:0] stats_enable;
    logic                    xbar_bypass;
    logic [3:0]              gain_shift;

    reg signed [DATA_WIDTH-1:0]  ch_data_in  [NUM_CHANNELS-1:0] ;
    reg [NUM_CHANNELS-1:0]       ch_valid_in ;
    reg signed [ACC_WIDTH-1:0]   ch_data_out [NUM_CHANNELS-1:0] ;
    reg [NUM_CHANNELS-1:0]       ch_valid_out = '0;
    reg [NUM_CHANNELS-1:0]       ch_overflow  = '0;
    
    reg [2:0] isel_reg,osel_reg,bytesel_reg ;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < NUM_CONFIGS; i++)
                cfg_regs[i] <= '0;
            cfg_regs[0] <= 32'h0000_00FF; // all channels enabled
            cfg_regs[1] <= 32'h0000_00FF; // all stats enabled
        end else if (cfg_wr) begin
            cfg_regs[cfg_addr] <= cfg_wdata;
        end
    end

    assign cfg_rdata    = cfg_regs[cfg_addr];
    assign ch_enable    = cfg_regs[0][NUM_CHANNELS-1:0];
    assign stats_enable = cfg_regs[1][NUM_CHANNELS-1:0];
    assign xbar_bypass  = cfg_regs[2][0];
    assign gain_shift   = cfg_regs[3][3:0];

    // ----------------------------------------------------------------
    // DSP pipeline instances
    // ----------------------------------------------------------------
    logic signed [ACC_WIDTH-1:0] pipe_out   [NUM_CHANNELS-1:0];
    logic [NUM_CHANNELS-1:0]     pipe_valid;
    logic [3:0]                  pipe_oflow [NUM_CHANNELS-1:0];

    genvar ch;
    generate
        for (ch = 0; ch < NUM_CHANNELS; ch++) begin : channel
            dsp_pipeline #(
			   .WIDTH     (DATA_WIDTH),
			   .ACC_WIDTH (ACC_WIDTH),
			   .NUM_TAPS  (NUM_TAPS)
			   ) u_dsp (
				    .clk            (clk),
				    .rst            (rst),
				    .ce             (ch_enable[ch]),
				    .data_in        (ch_data_in[ch]),
				    .data_valid     (ch_valid_in[ch]),
				    .coeff_in       (coeff_data),
				    .coeff_addr     (coeff_addr),
				    .coeff_wr       (coeff_wr && (coeff_ch_sel == ch[2:0])),
				    .data_out       (pipe_out[ch]),
				    .data_out_valid (pipe_valid[ch]),
				    .overflow_flags (pipe_oflow[ch])
				    );
        end
    endgenerate

    // ----------------------------------------------------------------
    // Gain scaling
    // ----------------------------------------------------------------
    logic signed [ACC_WIDTH-1:0] scaled_out [NUM_CHANNELS-1:0];
    logic [NUM_CHANNELS-1:0]     scaled_valid;

    always_ff @(posedge clk) begin
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            scaled_out[i]   <= pipe_out[i] >>> gain_shift;
            scaled_valid[i] <= pipe_valid[i];
        end
    end

    // ----------------------------------------------------------------
    // 8x8 Output crossbar
    // ----------------------------------------------------------------
    logic signed [ACC_WIDTH-1:0] xbar_out   [NUM_CHANNELS-1:0] = '{default: '0};
    logic [NUM_CHANNELS-1:0]     xbar_valid = '0;

    always_ff @(posedge clk) begin
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            if (xbar_bypass)
                xbar_out[i] <= scaled_out[i];
            else
                xbar_out[i] <= scaled_out[xbar_src[i]];
        end
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            if (rst)
                xbar_valid[i] <= 1'b0;
            else if (xbar_bypass)
                xbar_valid[i] <= scaled_valid[i];
            else
                xbar_valid[i] <= scaled_valid[xbar_src[i]];
        end
    end

    // ----------------------------------------------------------------
    // Output saturation — clamp to signed range [-(2^31), 2^31-1]
    // ----------------------------------------------------------------
    localparam logic signed [ACC_WIDTH-1:0] SAT_MAX =  (1 <<< 31) - 1;
    localparam logic signed [ACC_WIDTH-1:0] SAT_MIN = -(1 <<< 31);

    always_ff @(posedge clk) begin
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            if (xbar_out[i] > SAT_MAX)
                ch_data_out[i] <= SAT_MAX;
            else if (xbar_out[i] < SAT_MIN)
                ch_data_out[i] <= SAT_MIN;
            else
                ch_data_out[i] <= xbar_out[i];
        end
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            if (rst) begin
                ch_valid_out[i] <= 1'b0;
                ch_overflow[i]  <= 1'b0;
            end else begin
                ch_valid_out[i] <= xbar_valid[i];
                ch_overflow[i]  <= (xbar_out[i] > SAT_MAX) || (xbar_out[i] < SAT_MIN);
            end
        end
    end

    // ----------------------------------------------------------------
    // Per-channel statistics engines
    // ----------------------------------------------------------------
    logic signed [ACC_WIDTH-1:0] s_min  [NUM_CHANNELS-1:0];
    logic signed [ACC_WIDTH-1:0] s_max  [NUM_CHANNELS-1:0];
    logic signed [ACC_WIDTH-1:0] s_mean [NUM_CHANNELS-1:0];
    logic [31:0]                 s_cnt  [NUM_CHANNELS-1:0];

    generate
        for (ch = 0; ch < NUM_CHANNELS; ch++) begin : stats
            stats_engine #(
			   .DATA_WIDTH (ACC_WIDTH)
			   ) u_stats (
				      .clk          (clk),
				      .rst          (rst),
				      .enable       (stats_enable[ch]),
				      .data_in      (xbar_out[ch]),
				      .data_valid   (xbar_valid[ch]),
				      .stat_min     (s_min[ch]),
				      .stat_max     (s_max[ch]),
				      .stat_mean    (s_mean[ch]),
				      .sample_count (s_cnt[ch])
				      );
        end
    endgenerate

    // Stats output mux
    assign stat_min_out   = s_min[stat_ch_sel];
    assign stat_max_out   = s_max[stat_ch_sel];
    assign stat_mean_out  = s_mean[stat_ch_sel];
    assign stat_count_out = s_cnt[stat_ch_sel];
    
    always @(posedge clk) begin
	isel_reg <= isel;
	osel_reg <= osel ;
	ch_data_in[isel_reg] <= data_in ;
	ch_valid_in[isel_reg] <= valid_in ;
	data_out <= ch_data_out[osel_reg] ;
	valid_out <= ch_valid_out[osel_reg];
	overflow <= ch_overflow[osel_reg];
	bytesel_reg <= bytesel ;
	byte_min_out <= stat_min_out >> bytesel_reg*8;
	byte_max_out <= stat_max_out >> bytesel_reg*8;
	byte_mean_out <= stat_mean_out >> bytesel_reg*8;
    end
    
endmodule
