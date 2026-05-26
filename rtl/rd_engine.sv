// SPDX-License-Identifier: Apache-2.0
//
// rd_engine — Gray-Scott reaction-diffusion engine over an external dual-buffer
// framebuffer. Sweeps the GRID_W x GRID_H torus one cell per ~11 cycles:
// fetches the 9 toroidal neighbours of each cell, runs rd_cell, writes the
// next-state cell into the opposite buffer, then ping-pongs and repeats.
//
// Framebuffer is external SRAM: each cell is a 32-bit word {v[15:0], u[15:0]}.
// Two buffers selected by buf_sel_o (read) / ~buf_sel_o (write); the host maps
// {buf, row, col} -> address. Pure logic + small state -> hardens clean.

module rd_engine #(
    parameter int GRID_W = 128,
    parameter int GRID_H = 128,
    parameter int CW     = 7,            // clog2(GRID_W)
    parameter int RW     = 7,            // clog2(GRID_H)
    parameter int AW     = CW + RW       // cell address width within a buffer
) (
    input  logic              clk_i,
    input  logic              rst_ni,
    input  logic              start_i,    // pulse: begin running frames
    output logic              buf_sel_o,  // current read buffer (write = ~)
    output logic              frame_o,    // pulse at end of each full sweep

    // framebuffer read port (combinational or 1-cycle; we sample next cycle)
    output logic [AW-1:0]     rd_addr_o,
    output logic              rd_en_o,
    input  logic [31:0]       rd_data_i,  // {v[15:0], u[15:0]}

    // framebuffer write port
    output logic [AW-1:0]     wr_addr_o,
    output logic [31:0]       wr_data_o,
    output logic              wr_en_o
);
    // 9 neighbour order: 0=C 1=N 2=S 3=E 4=W 5=NE 6=NW 7=SE 8=SW
    // (dr,dc) per index
    function automatic logic signed [1:0] dr_of(input int unsigned i);
        case (i)
            0: dr_of = 2'sd0;  1: dr_of = -2'sd1; 2: dr_of = 2'sd1;
            3: dr_of = 2'sd0;  4: dr_of = 2'sd0;  5: dr_of = -2'sd1;
            6: dr_of = -2'sd1; 7: dr_of = 2'sd1;  8: dr_of = 2'sd1;
            default: dr_of = 2'sd0;
        endcase
    endfunction
    function automatic logic signed [1:0] dc_of(input int unsigned i);
        case (i)
            0: dc_of = 2'sd0;  1: dc_of = 2'sd0;  2: dc_of = 2'sd0;
            3: dc_of = 2'sd1;  4: dc_of = -2'sd1; 5: dc_of = 2'sd1;
            6: dc_of = -2'sd1; 7: dc_of = 2'sd1;  8: dc_of = -2'sd1;
            default: dc_of = 2'sd0;
        endcase
    endfunction

    typedef enum logic [2:0] {S_IDLE, S_READ, S_COMPUTE, S_WRITE, S_DONE} state_t;
    state_t state;

    logic [RW-1:0] row;
    logic [CW-1:0] col;
    logic [3:0]    cnt;         // 0..9: read pipeline counter
    logic [3:0]    aidx;        // address neighbour index this cycle = min(cnt,8)

    assign aidx = (cnt <= 4'd8) ? cnt : 4'd8;

    // toroidal neighbour coordinates for current (row,col) and aidx
    logic signed [RW+1:0] nr;
    logic signed [CW+1:0] nc;
    logic [RW-1:0]        nrw;
    logic [CW-1:0]        ncw;
    always_comb begin
        nr = $signed({1'b0, row}) + dr_of(aidx);
        nc = $signed({1'b0, col}) + dc_of(aidx);
        if (nr < 0)               nrw = GRID_H - 1;
        else if (nr >= GRID_H)    nrw = '0;
        else                      nrw = nr[RW-1:0];
        if (nc < 0)               ncw = GRID_W - 1;
        else if (nc >= GRID_W)    ncw = '0;
        else                      ncw = nc[CW-1:0];
    end
    assign rd_addr_o = nrw * GRID_W + ncw;

    // window registers (Q4.12)
    logic [15:0] uw [0:8];
    logic [15:0] vw [0:8];

    // pipelined rd_cell kernel (3-cycle latency)
    logic [15:0] u_o, v_o;
    rd_cell_pipe u_cell (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .u_c(uw[0]), .u_n_(uw[1]), .u_s(uw[2]), .u_e(uw[3]), .u_w(uw[4]),
        .u_ne(uw[5]), .u_nw(uw[6]), .u_se(uw[7]), .u_sw(uw[8]),
        .v_c(vw[0]), .v_n_(vw[1]), .v_s(vw[2]), .v_e(vw[3]), .v_w(vw[4]),
        .v_ne(vw[5]), .v_nw(vw[6]), .v_se(vw[7]), .v_sw(vw[8]),
        .u_o(u_o), .v_o(v_o)
    );
    logic [2:0] pcnt;            // pipeline-latency wait counter

    // registered write outputs (breaks long rd_cell -> output path)
    logic [AW-1:0] wr_addr_q;
    logic [15:0]   wr_u_q, wr_v_q;
    assign wr_addr_o = wr_addr_q;
    assign wr_data_o = {wr_v_q, wr_u_q};

    // combinational request/strobe outputs (aligned with combinational rd_addr_o)
    assign rd_en_o  = (state == S_READ) && (cnt <= 4'd8);
    assign wr_en_o  = (state == S_WRITE);
    assign frame_o  = (state == S_DONE);

    integer j;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state <= S_IDLE; row <= '0; col <= '0; cnt <= '0; pcnt <= '0;
            buf_sel_o <= 1'b0; wr_addr_q <= '0; wr_u_q <= 16'd0; wr_v_q <= 16'd0;
            for (j = 0; j < 9; j = j + 1) begin uw[j] <= 16'd0; vw[j] <= 16'd0; end
        end else begin
            case (state)
                S_IDLE: begin
                    if (start_i) begin
                        row <= '0; col <= '0; cnt <= '0;
                        state <= S_READ;
                    end
                end
                S_READ: begin
                    // addr=neighbour(min(cnt,8)) driven combinationally; data for
                    // neighbour (cnt-1) arrives this cycle (1-cycle SRAM latency)
                    if (cnt >= 4'd1) begin
                        uw[cnt - 4'd1] <= rd_data_i[15:0];
                        vw[cnt - 4'd1] <= rd_data_i[31:16];
                    end
                    if (cnt == 4'd9) begin
                        cnt   <= '0;
                        pcnt  <= '0;
                        state <= S_COMPUTE;        // all 9 neighbours latched
                    end else begin
                        cnt <= cnt + 4'd1;
                    end
                end
                S_COMPUTE: begin
                    // wait for 3-cycle pipeline latency with the stable window,
                    // then register the valid result before driving outputs
                    if (pcnt == 3'd3) begin
                        wr_u_q    <= u_o;
                        wr_v_q    <= v_o;
                        wr_addr_q <= row * GRID_W + col;
                        state     <= S_WRITE;
                    end else begin
                        pcnt <= pcnt + 3'd1;
                    end
                end
                S_WRITE: begin
                    cnt <= '0;
                    if (col == GRID_W-1) begin
                        col <= '0;
                        if (row == GRID_H-1) begin
                            row <= '0;
                            state <= S_DONE;
                        end else begin
                            row <= row + 1'b1;
                            state <= S_READ;
                        end
                    end else begin
                        col <= col + 1'b1;
                        state <= S_READ;
                    end
                end
                S_DONE: begin
                    buf_sel_o <= ~buf_sel_o;        // ping-pong
                    state     <= S_READ;            // next frame (continuous)
                    row <= '0; col <= '0; cnt <= '0;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
