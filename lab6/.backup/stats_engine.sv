// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

// stats_engine.sv (step4 update)
// Active-high synchronous reset (rst) on the statistics state and valid flags only.

module stats_engine #(
    parameter DATA_WIDTH = 48,
    parameter HIST_BINS  = 256
)(
    input  logic                          clk,
    input  logic                          rst,
    input  logic                          enable,

    input  logic signed [DATA_WIDTH-1:0]  data_in,
    input  logic                          data_valid,

    output logic signed [DATA_WIDTH-1:0]  stat_min,
    output logic signed [DATA_WIDTH-1:0]  stat_max,
    output logic signed [DATA_WIDTH-1:0]  stat_mean,
    output logic [31:0]                   sample_count
);

    always_ff @(posedge clk) begin
        if (rst) begin
            stat_min <= {1'b0, {(DATA_WIDTH-1){1'b1}}}; // max positive
            stat_max <= {1'b1, {(DATA_WIDTH-1){1'b0}}}; // max negative
        end else if (enable && data_valid) begin
            if (data_in < stat_min)
                stat_min <= data_in;
            if (data_in > stat_max)
                stat_max <= data_in;
        end
    end

    // IIR moving average: mean += (data_in - mean) >>> 4
    logic signed [DATA_WIDTH-1:0] mean_reg;
    logic signed [DATA_WIDTH-1:0] diff;

    always_ff @(posedge clk) begin
        if (rst) begin
            mean_reg <= '0;
        end else if (enable && data_valid) begin
            diff     = data_in - mean_reg;
            mean_reg <= mean_reg + (diff >>> 4);
        end
    end

    assign stat_mean = mean_reg;

    logic [31:0] count;

    always_ff @(posedge clk) begin
        if (rst)
            count <= '0;
        else if (enable && data_valid)
            count <= count + 1;
    end

    assign sample_count = count;

    // BRAM-based histogram — 256 bins x 32-bit counters
    logic [7:0]  hist_addr_r = '0, hist_addr_rr = '0;
    logic [31:0] hist_mem [HIST_BINS-1:0];
    logic [31:0] hist_rdata;
    logic        hist_valid_r, hist_valid_rr;

    always_ff @(posedge clk) begin
        hist_addr_r <= data_in[DATA_WIDTH-1 -: 8]; // top 8 bits as bin
        if (rst)
            hist_valid_r <= 1'b0;
        else
            hist_valid_r <= enable && data_valid;
    end

    always_ff @(posedge clk) begin
        hist_rdata    <= hist_mem[hist_addr_r];
        hist_addr_rr  <= hist_addr_r;
        hist_valid_rr <= hist_valid_r;
    end

    always_ff @(posedge clk) begin
        if (hist_valid_rr)
            hist_mem[hist_addr_rr] <= hist_rdata + 1;
    end

endmodule
