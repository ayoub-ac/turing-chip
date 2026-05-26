module rd_cell_pipe (
	clk_i,
	rst_ni,
	u_c,
	u_n_,
	u_s,
	u_e,
	u_w,
	u_ne,
	u_nw,
	u_se,
	u_sw,
	v_c,
	v_n_,
	v_s,
	v_e,
	v_w,
	v_ne,
	v_nw,
	v_se,
	v_sw,
	u_o,
	v_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire [15:0] u_c;
	input wire [15:0] u_n_;
	input wire [15:0] u_s;
	input wire [15:0] u_e;
	input wire [15:0] u_w;
	input wire [15:0] u_ne;
	input wire [15:0] u_nw;
	input wire [15:0] u_se;
	input wire [15:0] u_sw;
	input wire [15:0] v_c;
	input wire [15:0] v_n_;
	input wire [15:0] v_s;
	input wire [15:0] v_e;
	input wire [15:0] v_w;
	input wire [15:0] v_ne;
	input wire [15:0] v_nw;
	input wire [15:0] v_se;
	input wire [15:0] v_sw;
	output reg [15:0] u_o;
	output reg [15:0] v_o;
	localparam signed [31:0] FRAC = 12;
	localparam signed [31:0] ONE = 4096;
	function automatic [12:0] f13;
		input reg [15:0] x;
		f13 = x[12:0];
	endfunction
	reg [14:0] c1_udiag;
	reg [14:0] c1_uorth;
	reg [14:0] c1_vdiag;
	reg [14:0] c1_vorth;
	reg [13:0] c1_uv;
	reg [25:0] uv_full;
	always @(*) begin
		if (_sv2v_0)
			;
		c1_udiag = (({2'b00, f13(u_ne)} + {2'b00, f13(u_nw)}) + {2'b00, f13(u_se)}) + {2'b00, f13(u_sw)};
		c1_uorth = (({2'b00, f13(u_n_)} + {2'b00, f13(u_s)}) + {2'b00, f13(u_e)}) + {2'b00, f13(u_w)};
		c1_vdiag = (({2'b00, f13(v_ne)} + {2'b00, f13(v_nw)}) + {2'b00, f13(v_se)}) + {2'b00, f13(v_sw)};
		c1_vorth = (({2'b00, f13(v_n_)} + {2'b00, f13(v_s)}) + {2'b00, f13(v_e)}) + {2'b00, f13(v_w)};
		uv_full = f13(u_c) * f13(v_c);
		c1_uv = uv_full[25:12];
	end
	reg [14:0] r1_udiag;
	reg [14:0] r1_uorth;
	reg [14:0] r1_vdiag;
	reg [14:0] r1_vorth;
	reg [13:0] r1_uv;
	reg [12:0] r1_uc;
	reg [12:0] r1_vc;
	reg signed [27:0] lapU_acc;
	reg signed [27:0] lapV_acc;
	reg signed [15:0] c2_lapU;
	reg signed [15:0] c2_lapV;
	reg [26:0] uvv_full;
	reg [13:0] c2_uvv;
	always @(*) begin
		if (_sv2v_0)
			;
		lapU_acc = (($signed({13'b0000000000000, r1_udiag}) * 28'sd205) + ($signed({13'b0000000000000, r1_uorth}) * 28'sd819)) - ($signed({15'b000000000000000, r1_uc}) <<< 12);
		lapV_acc = (($signed({13'b0000000000000, r1_vdiag}) * 28'sd205) + ($signed({13'b0000000000000, r1_vorth}) * 28'sd819)) - ($signed({15'b000000000000000, r1_vc}) <<< 12);
		c2_lapU = lapU_acc >>> 12;
		c2_lapV = lapV_acc >>> 12;
		uvv_full = r1_uv * {1'b0, r1_vc};
		c2_uvv = uvv_full[26:12];
	end
	reg signed [15:0] r2_lapU;
	reg signed [15:0] r2_lapV;
	reg [13:0] r2_uvv;
	reg [12:0] r2_uc;
	reg [12:0] r2_vc;
	reg signed [27:0] du_term;
	reg signed [27:0] dv_term;
	reg signed [27:0] ff_term;
	reg signed [27:0] fk_term;
	reg signed [17:0] c3_un;
	reg signed [17:0] c3_vn;
	function automatic signed [12:0] sv2v_cast_13_signed;
		input reg signed [12:0] inp;
		sv2v_cast_13_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		du_term = (28'sd655 * r2_lapU) >>> 12;
		dv_term = (28'sd328 * r2_lapV) >>> 12;
		ff_term = (28'sd238 * $signed({15'b000000000000000, sv2v_cast_13_signed(ONE) - r2_uc})) >>> 12;
		fk_term = (28'sd496 * $signed({15'b000000000000000, r2_vc})) >>> 12;
		c3_un = (($signed({5'b00000, r2_uc}) + du_term[17:0]) - $signed({4'b0000, r2_uvv})) + ff_term[17:0];
		c3_vn = (($signed({5'b00000, r2_vc}) + dv_term[17:0]) + $signed({4'b0000, r2_uvv})) - fk_term[17:0];
	end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			r1_udiag <= 0;
			r1_uorth <= 0;
			r1_vdiag <= 0;
			r1_vorth <= 0;
			r1_uv <= 0;
			r1_uc <= 0;
			r1_vc <= 0;
			r2_lapU <= 0;
			r2_lapV <= 0;
			r2_uvv <= 0;
			r2_uc <= 0;
			r2_vc <= 0;
			u_o <= 16'd0;
			v_o <= 16'd0;
		end
		else begin
			r1_udiag <= c1_udiag;
			r1_uorth <= c1_uorth;
			r1_vdiag <= c1_vdiag;
			r1_vorth <= c1_vorth;
			r1_uv <= c1_uv;
			r1_uc <= f13(u_c);
			r1_vc <= f13(v_c);
			r2_lapU <= c2_lapU;
			r2_lapV <= c2_lapV;
			r2_uvv <= c2_uvv;
			r2_uc <= r1_uc;
			r2_vc <= r1_vc;
			if (c3_un < 0)
				u_o <= 16'd0;
			else if (c3_un > ONE)
				u_o <= ONE[15:0];
			else
				u_o <= {2'b00, c3_un[13:0]};
			if (c3_vn < 0)
				v_o <= 16'd0;
			else if (c3_vn > ONE)
				v_o <= ONE[15:0];
			else
				v_o <= {2'b00, c3_vn[13:0]};
		end
	initial _sv2v_0 = 0;
endmodule
module rd_engine (
	clk_i,
	rst_ni,
	start_i,
	buf_sel_o,
	frame_o,
	rd_addr_o,
	rd_en_o,
	rd_data_i,
	wr_addr_o,
	wr_data_o,
	wr_en_o
);
	reg _sv2v_0;
	parameter signed [31:0] GRID_W = 128;
	parameter signed [31:0] GRID_H = 128;
	parameter signed [31:0] CW = 7;
	parameter signed [31:0] RW = 7;
	parameter signed [31:0] AW = CW + RW;
	input wire clk_i;
	input wire rst_ni;
	input wire start_i;
	output reg buf_sel_o;
	output wire frame_o;
	output wire [AW - 1:0] rd_addr_o;
	output wire rd_en_o;
	input wire [31:0] rd_data_i;
	output wire [AW - 1:0] wr_addr_o;
	output wire [31:0] wr_data_o;
	output wire wr_en_o;
	function automatic signed [1:0] dr_of;
		input reg [31:0] i;
		case (i)
			0: dr_of = 2'sd0;
			1: dr_of = -2'sd1;
			2: dr_of = 2'sd1;
			3: dr_of = 2'sd0;
			4: dr_of = 2'sd0;
			5: dr_of = -2'sd1;
			6: dr_of = -2'sd1;
			7: dr_of = 2'sd1;
			8: dr_of = 2'sd1;
			default: dr_of = 2'sd0;
		endcase
	endfunction
	function automatic signed [1:0] dc_of;
		input reg [31:0] i;
		case (i)
			0: dc_of = 2'sd0;
			1: dc_of = 2'sd0;
			2: dc_of = 2'sd0;
			3: dc_of = 2'sd1;
			4: dc_of = -2'sd1;
			5: dc_of = 2'sd1;
			6: dc_of = -2'sd1;
			7: dc_of = 2'sd1;
			8: dc_of = -2'sd1;
			default: dc_of = 2'sd0;
		endcase
	endfunction
	reg [2:0] state;
	reg [RW - 1:0] row;
	reg [CW - 1:0] col;
	reg [3:0] cnt;
	wire [3:0] aidx;
	assign aidx = (cnt <= 4'd8 ? cnt : 4'd8);
	reg signed [RW + 1:0] nr;
	reg signed [CW + 1:0] nc;
	reg [RW - 1:0] nrw;
	reg [CW - 1:0] ncw;
	always @(*) begin
		if (_sv2v_0)
			;
		nr = $signed({1'b0, row}) + dr_of(aidx);
		nc = $signed({1'b0, col}) + dc_of(aidx);
		if (nr < 0)
			nrw = GRID_H - 1;
		else if (nr >= GRID_H)
			nrw = 1'sb0;
		else
			nrw = nr[RW - 1:0];
		if (nc < 0)
			ncw = GRID_W - 1;
		else if (nc >= GRID_W)
			ncw = 1'sb0;
		else
			ncw = nc[CW - 1:0];
	end
	assign rd_addr_o = (nrw * GRID_W) + ncw;
	reg [15:0] uw [0:8];
	reg [15:0] vw [0:8];
	wire [15:0] u_o;
	wire [15:0] v_o;
	rd_cell_pipe u_cell(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.u_c(uw[0]),
		.u_n_(uw[1]),
		.u_s(uw[2]),
		.u_e(uw[3]),
		.u_w(uw[4]),
		.u_ne(uw[5]),
		.u_nw(uw[6]),
		.u_se(uw[7]),
		.u_sw(uw[8]),
		.v_c(vw[0]),
		.v_n_(vw[1]),
		.v_s(vw[2]),
		.v_e(vw[3]),
		.v_w(vw[4]),
		.v_ne(vw[5]),
		.v_nw(vw[6]),
		.v_se(vw[7]),
		.v_sw(vw[8]),
		.u_o(u_o),
		.v_o(v_o)
	);
	reg [2:0] pcnt;
	reg [AW - 1:0] wr_addr_q;
	reg [15:0] wr_u_q;
	reg [15:0] wr_v_q;
	assign wr_addr_o = wr_addr_q;
	assign wr_data_o = {wr_v_q, wr_u_q};
	assign rd_en_o = (state == 3'd1) && (cnt <= 4'd8);
	assign wr_en_o = state == 3'd3;
	assign frame_o = state == 3'd4;
	integer j;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			state <= 3'd0;
			row <= 1'sb0;
			col <= 1'sb0;
			cnt <= 1'sb0;
			pcnt <= 1'sb0;
			buf_sel_o <= 1'b0;
			wr_addr_q <= 1'sb0;
			wr_u_q <= 16'd0;
			wr_v_q <= 16'd0;
			for (j = 0; j < 9; j = j + 1)
				begin
					uw[j] <= 16'd0;
					vw[j] <= 16'd0;
				end
		end
		else
			case (state)
				3'd0:
					if (start_i) begin
						row <= 1'sb0;
						col <= 1'sb0;
						cnt <= 1'sb0;
						state <= 3'd1;
					end
				3'd1: begin
					if (cnt >= 4'd1) begin
						uw[cnt - 4'd1] <= rd_data_i[15:0];
						vw[cnt - 4'd1] <= rd_data_i[31:16];
					end
					if (cnt == 4'd9) begin
						cnt <= 1'sb0;
						pcnt <= 1'sb0;
						state <= 3'd2;
					end
					else
						cnt <= cnt + 4'd1;
				end
				3'd2:
					if (pcnt == 3'd3) begin
						wr_u_q <= u_o;
						wr_v_q <= v_o;
						wr_addr_q <= (row * GRID_W) + col;
						state <= 3'd3;
					end
					else
						pcnt <= pcnt + 3'd1;
				3'd3: begin
					cnt <= 1'sb0;
					if (col == (GRID_W - 1)) begin
						col <= 1'sb0;
						if (row == (GRID_H - 1)) begin
							row <= 1'sb0;
							state <= 3'd4;
						end
						else begin
							row <= row + 1'b1;
							state <= 3'd1;
						end
					end
					else begin
						col <= col + 1'b1;
						state <= 3'd1;
					end
				end
				3'd4: begin
					buf_sel_o <= ~buf_sel_o;
					state <= 3'd1;
					row <= 1'sb0;
					col <= 1'sb0;
					cnt <= 1'sb0;
				end
				default: state <= 3'd0;
			endcase
	initial _sv2v_0 = 0;
endmodule