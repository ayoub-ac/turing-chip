// SPDX-License-Identifier: Apache-2.0
//
// rd_cell_pipe — 3-stage pipelined Gray-Scott cell, Q4.12, WIDTH-OPTIMIZED.
// Field values are in [0,4096] = 13 bits, so all multiplies use 13-15 bit
// operands (13x13 .. 15x10), NOT 32x32. This shrinks the multipliers ~5x in
// area and shortens the critical path while staying bit-exact vs the golden
// (values provably fit: u,v,uv,uvv <= 4096; laplacian in [-8192,8192]).
//
//   stage 1: neighbour sums + uv = u*v
//   stage 2: Laplacians (weighted) + uvv = uv*v
//   stage 3: diffusion/feed/kill + clamp

module rd_cell_pipe (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic [15:0] u_c,
    input  logic [15:0] u_n_, input logic [15:0] u_s, input logic [15:0] u_e, input logic [15:0] u_w,
    input  logic [15:0] u_ne, input logic [15:0] u_nw, input logic [15:0] u_se, input logic [15:0] u_sw,
    input  logic [15:0] v_c,
    input  logic [15:0] v_n_, input logic [15:0] v_s, input logic [15:0] v_e, input logic [15:0] v_w,
    input  logic [15:0] v_ne, input logic [15:0] v_nw, input logic [15:0] v_se, input logic [15:0] v_sw,
    output logic [15:0] u_o,
    output logic [15:0] v_o
);
    localparam int FRAC = 12;
    localparam int ONE  = 1 << FRAC;

    // 13-bit field operands (value <= 4096)
    function automatic logic [12:0] f13(input logic [15:0] x); f13 = x[12:0]; endfunction

    // ---- stage 1 comb ----
    logic [14:0] c1_udiag, c1_uorth, c1_vdiag, c1_vorth;  // 4*4096 = 16384 -> 15b
    logic [13:0] c1_uv;                                   // (u*v)>>12 <= 4096 -> 14b
    logic [25:0] uv_full;
    always_comb begin
        c1_udiag = {2'b0,f13(u_ne)} + {2'b0,f13(u_nw)} + {2'b0,f13(u_se)} + {2'b0,f13(u_sw)};
        c1_uorth = {2'b0,f13(u_n_)} + {2'b0,f13(u_s)}  + {2'b0,f13(u_e)}  + {2'b0,f13(u_w)};
        c1_vdiag = {2'b0,f13(v_ne)} + {2'b0,f13(v_nw)} + {2'b0,f13(v_se)} + {2'b0,f13(v_sw)};
        c1_vorth = {2'b0,f13(v_n_)} + {2'b0,f13(v_s)}  + {2'b0,f13(v_e)}  + {2'b0,f13(v_w)};
        uv_full  = f13(u_c) * f13(v_c);          // 13x13 = 26b
        c1_uv    = uv_full[25:12];               // >>12
    end
    logic [14:0] r1_udiag, r1_uorth, r1_vdiag, r1_vorth;
    logic [13:0] r1_uv;
    logic [12:0] r1_uc, r1_vc;

    // ---- stage 2 comb ----
    // lap = (diag*205 + orth*819 - center*4096) >>> 12   (signed)
    logic signed [27:0] lapU_acc, lapV_acc;
    logic signed [15:0] c2_lapU, c2_lapV;
    logic [26:0]        uvv_full;
    logic [13:0]        c2_uvv;
    always_comb begin
        lapU_acc = $signed({13'b0, r1_udiag}) * 28'sd205
                 + $signed({13'b0, r1_uorth}) * 28'sd819
                 - ($signed({15'b0, r1_uc}) <<< 12);
        lapV_acc = $signed({13'b0, r1_vdiag}) * 28'sd205
                 + $signed({13'b0, r1_vorth}) * 28'sd819
                 - ($signed({15'b0, r1_vc}) <<< 12);
        c2_lapU  = lapU_acc >>> 12;
        c2_lapV  = lapV_acc >>> 12;
        uvv_full = r1_uv * {1'b0, r1_vc};        // 14x13 = 27b
        c2_uvv   = uvv_full[26:12];
    end
    logic signed [15:0] r2_lapU, r2_lapV;
    logic [13:0]        r2_uvv;
    logic [12:0]        r2_uc, r2_vc;

    // ---- stage 3 comb ----
    logic signed [27:0] du_term, dv_term, ff_term, fk_term;
    logic signed [17:0] c3_un, c3_vn;
    always_comb begin
        du_term = (28'sd655 * r2_lapU) >>> 12;                       // 0.16*lapU
        dv_term = (28'sd328 * r2_lapV) >>> 12;                       // 0.08*lapV
        ff_term = (28'sd238 * $signed({15'b0, (13'(ONE) - r2_uc)})) >>> 12;
        fk_term = (28'sd496 * $signed({15'b0, r2_vc})) >>> 12;
        c3_un = $signed({5'b0, r2_uc}) + du_term[17:0] - $signed({4'b0, r2_uvv}) + ff_term[17:0];
        c3_vn = $signed({5'b0, r2_vc}) + dv_term[17:0] + $signed({4'b0, r2_uvv}) - fk_term[17:0];
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            r1_udiag<=0; r1_uorth<=0; r1_vdiag<=0; r1_vorth<=0; r1_uv<=0; r1_uc<=0; r1_vc<=0;
            r2_lapU<=0; r2_lapV<=0; r2_uvv<=0; r2_uc<=0; r2_vc<=0;
            u_o<=16'd0; v_o<=16'd0;
        end else begin
            r1_udiag<=c1_udiag; r1_uorth<=c1_uorth; r1_vdiag<=c1_vdiag; r1_vorth<=c1_vorth;
            r1_uv<=c1_uv; r1_uc<=f13(u_c); r1_vc<=f13(v_c);
            r2_lapU<=c2_lapU; r2_lapV<=c2_lapV; r2_uvv<=c2_uvv; r2_uc<=r1_uc; r2_vc<=r1_vc;
            if (c3_un < 0)              u_o <= 16'd0;
            else if (c3_un > ONE)       u_o <= ONE[15:0];
            else                        u_o <= {2'b0, c3_un[13:0]};
            if (c3_vn < 0)              v_o <= 16'd0;
            else if (c3_vn > ONE)       v_o <= ONE[15:0];
            else                        v_o <= {2'b0, c3_vn[13:0]};
        end
    end
endmodule
