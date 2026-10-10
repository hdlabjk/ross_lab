// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

// stats_engine_dsp.sv (step6 update, drop-in for stats_engine)
// The IIR mean is held in one DSP48E1 as Q = -16*mean (S = 16*mean):
//   S_new = S - (S>>>4) + d   <=>   Q_new = Q - ((Q>>>4) + d)
//   P = Z - (X + Y + CIN),  Z = P,  X = A:B = d,  Y = C = Q>>>4,  CIN = 0
// stat_mean = S>>>4, delayed by 2 cycles compared with the step4 RTL
// (AREG/BREG stage + output register). Rounding differs by at most 1 LSB.
// min/max/count/histogram are unchanged from step4.

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

    // ----------------------------------------------------------------
    // IIR mean in a DSP48E1 (Q = -16*mean)
    // ----------------------------------------------------------------
    logic en_r = 1'b0;   // follows the AREG/BREG delay of data_in
    always_ff @(posedge clk)
        en_r <= enable && data_valid;

    logic signed [47:0] d48;
    logic signed [47:0] q_p;
    logic        [47:0] c_in;
    assign d48  = 48'(data_in);
    assign c_in = {{4{q_p[47]}}, q_p[47:4]};

    DSP48E1 #(
        .A_INPUT        ("DIRECT"),
        .B_INPUT        ("DIRECT"),
        .USE_DPORT      ("FALSE"),
        .USE_MULT       ("NONE"),
        .USE_SIMD       ("ONE48"),
        .AREG           (1),
        .BREG           (1),
        .CREG           (0),
        .MREG           (0),
        .PREG           (1),
        .ADREG          (0),
        .DREG           (0),
        .ACASCREG       (1),
        .BCASCREG       (1),
        .ALUMODEREG     (0),
        .CARRYINREG     (0),
        .CARRYINSELREG  (0),
        .INMODEREG      (0),
        .OPMODEREG      (0)
    ) u_mean_dsp (
        .CLK            (clk),
        .A              (d48[47:18]),
        .B              (d48[17:0]),
        .C              (c_in),
        .D              (25'd0),
        .ACIN           (30'd0),
        .BCIN           (18'd0),
        .PCIN           (48'd0),
        .CARRYCASCIN    (1'b0),
        .MULTSIGNIN     (1'b0),
        .CARRYIN        (1'b0),
        .CARRYINSEL     (3'b000),
        .INMODE         (5'b00000),
        .OPMODE         (7'b010_11_11),  // Z=P, Y=C, X=A:B
        .ALUMODE        (4'b0011),       // Z - (X + Y + CIN)
        .CEA1           (1'b1),
        .CEA2           (1'b1),
        .CEB1           (1'b1),
        .CEB2           (1'b1),
        .CEC            (1'b1),
        .CED            (1'b0),
        .CEAD           (1'b0),
        .CEM            (1'b0),
        .CEP            (en_r),
        .CEALUMODE      (1'b1),
        .CECARRYIN      (1'b1),
        .CECTRL         (1'b1),
        .CEINMODE       (1'b1),
        .RSTA           (1'b0),
        .RSTB           (1'b0),
        .RSTC           (1'b0),
        .RSTD           (1'b0),
        .RSTM           (1'b0),
        .RSTP           (rst),
        .RSTALUMODE     (1'b0),
        .RSTALLCARRYIN  (1'b0),
        .RSTCTRL        (1'b0),
        .RSTINMODE      (1'b0),
        .P              (q_p)
    );

    // mean = S>>>4 = (-Q)>>>4, registered outside the accumulation loop.
    logic signed [27:0] s28;
    assign s28 = -q_p[27:0];

    logic signed [DATA_WIDTH-1:0] mean_reg;
    always_ff @(posedge clk) begin
        if (rst)
            mean_reg <= '0;
        else
            mean_reg <= DATA_WIDTH'(s28 >>> 4);
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
