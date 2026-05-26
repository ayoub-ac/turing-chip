// SPDX-License-Identifier: Apache-2.0
//
// rd_cell — one Gray-Scott reaction-diffusion cell update, Q4.12 fixed point.
// Pure combinational. Matches the Python golden (gray_scott_fx.py) bit-for-bit.
//
// 9-point Laplacian (Pearson kernel): diag weight 0.05, orth 0.20, center 1.0.
//   lap   = (diag*205 + orth*819 - center*4096) >> 12
//   uvv   = ((u*v)>>12 * v) >> 12
//   u'    = u + (655*lapU>>12) - uvv + (238*(ONE-u)>>12)
//   v'    = v + (328*lapV>>12) + uvv - (496*v>>12)      // 496 = F+k = 238+258
// clamp u',v' to [0, ONE].

module rd_cell (
    // U field 3x3 window (center + 8 neighbours), Q4.12 unsigned in [0,ONE]
    input  logic [15:0] u_c,
    input  logic [15:0] u_n_, input logic [15:0] u_s, input logic [15:0] u_e, input logic [15:0] u_w,
    input  logic [15:0] u_ne, input logic [15:0] u_nw, input logic [15:0] u_se, input logic [15:0] u_sw,
    // V field 3x3 window
    input  logic [15:0] v_c,
    input  logic [15:0] v_n_, input logic [15:0] v_s, input logic [15:0] v_e, input logic [15:0] v_w,
    input  logic [15:0] v_ne, input logic [15:0] v_nw, input logic [15:0] v_se, input logic [15:0] v_sw,
    output logic [15:0] u_o,
    output logic [15:0] v_o
);
    localparam int FRAC = 12;
    localparam int ONE  = 1 << FRAC;          // 4096
    localparam int W_D  = 205;                // 0.05
    localparam int W_O  = 819;                // 0.20
    localparam int W_C  = 4096;               // 1.0
    localparam int DU   = 655;                // 0.16
    localparam int DV   = 328;                // 0.08
    localparam int FF   = 238;                // 0.058
    localparam int FK   = 496;                // F+k = 0.058+0.063 -> 238+258

    // zero-extend fields to signed 32-bit for arithmetic
    function automatic logic signed [31:0] s(input logic [15:0] x);
        s = $signed({16'b0, x});
    endfunction

    logic signed [31:0] u_diag, u_orth, v_diag, v_orth;
    logic signed [31:0] lapU, lapV, uv, uvv, un, vn;

    always_comb begin
        u_diag = s(u_ne) + s(u_nw) + s(u_se) + s(u_sw);
        u_orth = s(u_n_) + s(u_s)  + s(u_e)  + s(u_w);
        v_diag = s(v_ne) + s(v_nw) + s(v_se) + s(v_sw);
        v_orth = s(v_n_) + s(v_s)  + s(v_e)  + s(v_w);

        lapU = (u_diag*W_D + u_orth*W_O - s(u_c)*W_C) >>> FRAC;
        lapV = (v_diag*W_D + v_orth*W_O - s(v_c)*W_C) >>> FRAC;

        uv  = (s(u_c) * s(v_c)) >>> FRAC;
        uvv = (uv     * s(v_c)) >>> FRAC;

        un = s(u_c) + ((DU*lapU) >>> FRAC) - uvv + ((FF*(ONE - s(u_c))) >>> FRAC);
        vn = s(v_c) + ((DV*lapV) >>> FRAC) + uvv - ((FK*s(v_c)) >>> FRAC);

        // clamp [0, ONE]
        if (un < 0)        u_o = 16'd0;
        else if (un > ONE) u_o = ONE[15:0];
        else               u_o = un[15:0];
        if (vn < 0)        v_o = 16'd0;
        else if (vn > ONE) v_o = ONE[15:0];
        else               v_o = vn[15:0];
    end
endmodule
