// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

// dsp_pipeline.sv (step4 update)
// - Active-high synchronous reset (rst) only on control/status registers.
// - Datapath registers have no reset; they start from GSR init values.
// - Extra register stage after the multiplier so DSP48 MREG is used.

module dsp_pipeline #(
    parameter WIDTH      = 18,
    parameter ACC_WIDTH  = 48,
    parameter NUM_TAPS   = 16
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    ce,

    // Data input
    input  logic signed [WIDTH-1:0] data_in,
    input  logic                    data_valid,

    // Coefficient load
    input  logic signed [WIDTH-1:0] coeff_in,
    input  logic [3:0]              coeff_addr,
    input  logic                    coeff_wr,

    // Output
    output logic signed [ACC_WIDTH-1:0] data_out,
    output logic                        data_out_valid,

    // Status
    output logic [3:0]              overflow_flags
);

    logic signed [WIDTH-1:0] coeffs [NUM_TAPS-1:0] = '{default: '0};

    logic signed [WIDTH:0]   pre_add      = '0;
    logic signed [WIDTH-1:0] feedback_reg = '0;

    logic signed [WIDTH-1:0] delay_line [NUM_TAPS-1:0] = '{default: '0};

    logic signed [2*WIDTH-1:0]   mult_r      [NUM_TAPS-1:0] = '{default: '0};
    logic signed [2*WIDTH-1:0]   products    [NUM_TAPS-1:0] = '{default: '0};
    logic signed [ACC_WIDTH-1:0] accum_chain [NUM_TAPS:0]   = '{default: '0};
    // One extra stage compared with the original to match the MREG latency.
    logic [NUM_TAPS:0] valid_pipe = '0;

    always_ff @(posedge clk) begin
        if (coeff_wr)
            coeffs[coeff_addr] <= coeff_in;
    end

    always_ff @(posedge clk) begin
        if (ce && data_valid) begin
            feedback_reg <= delay_line[NUM_TAPS-1];
            pre_add      <= WIDTH'(data_in) + WIDTH'(feedback_reg);
        end
    end

    always_ff @(posedge clk) begin
        if (ce && data_valid) begin
            delay_line[0] <= data_in;
            for (int i = 1; i < NUM_TAPS; i++)
                delay_line[i] <= delay_line[i-1];
        end
    end

    // Multiply (MREG) then PREG stage.
    always_ff @(posedge clk) begin
        if (ce) begin
            for (int i = 0; i < NUM_TAPS; i++) begin
                mult_r[i]   <= delay_line[i] * coeffs[i];
                products[i] <= mult_r[i];
            end
        end
    end

    genvar g;
    generate
        for (g = 0; g < NUM_TAPS; g++) begin : acc_stage
            always_ff @(posedge clk) begin
                if (ce)
                    accum_chain[g+1] <= accum_chain[g] + ACC_WIDTH'(products[g]);
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (rst)
            valid_pipe <= '0;
        else if (ce) begin
            valid_pipe[0] <= data_valid;
            for (int i = 1; i <= NUM_TAPS; i++)
                valid_pipe[i] <= valid_pipe[i-1];
        end
    end

    logic signed [ACC_WIDTH-1:0] final_accum = '0;

    always_ff @(posedge clk) begin
        if (ce)
            final_accum <= accum_chain[NUM_TAPS] + ACC_WIDTH'(pre_add);
    end

    assign data_out       = final_accum;
    assign data_out_valid = valid_pipe[NUM_TAPS];

    always_ff @(posedge clk) begin
        if (rst)
            overflow_flags <= '0;
        else if (ce) begin
            overflow_flags[0] <= (accum_chain[4][ACC_WIDTH-1]  != accum_chain[4][ACC_WIDTH-2]);
            overflow_flags[1] <= (accum_chain[8][ACC_WIDTH-1]  != accum_chain[8][ACC_WIDTH-2]);
            overflow_flags[2] <= (accum_chain[12][ACC_WIDTH-1] != accum_chain[12][ACC_WIDTH-2]);
            overflow_flags[3] <= (final_accum[ACC_WIDTH-1]     != final_accum[ACC_WIDTH-2]);
        end
    end

endmodule
