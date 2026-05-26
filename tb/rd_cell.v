module rd_cell (
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
	localparam signed [31:0] W_D = 205;
	localparam signed [31:0] W_O = 819;
	localparam signed [31:0] W_C = 4096;
	localparam signed [31:0] DU = 655;
	localparam signed [31:0] DV = 328;
	localparam signed [31:0] FF = 238;
	localparam signed [31:0] FK = 496;
	function automatic signed [31:0] s;
		input reg [15:0] x;
		s = $signed({16'b0000000000000000, x});
	endfunction
	reg signed [31:0] u_diag;
	reg signed [31:0] u_orth;
	reg signed [31:0] v_diag;
	reg signed [31:0] v_orth;
	reg signed [31:0] lapU;
	reg signed [31:0] lapV;
	reg signed [31:0] uv;
	reg signed [31:0] uvv;
	reg signed [31:0] un;
	reg signed [31:0] vn;
	always @(*) begin
		if (_sv2v_0)
			;
		u_diag = ((s(u_ne) + s(u_nw)) + s(u_se)) + s(u_sw);
		u_orth = ((s(u_n_) + s(u_s)) + s(u_e)) + s(u_w);
		v_diag = ((s(v_ne) + s(v_nw)) + s(v_se)) + s(v_sw);
		v_orth = ((s(v_n_) + s(v_s)) + s(v_e)) + s(v_w);
		lapU = (((u_diag * W_D) + (u_orth * W_O)) - (s(u_c) * W_C)) >>> FRAC;
		lapV = (((v_diag * W_D) + (v_orth * W_O)) - (s(v_c) * W_C)) >>> FRAC;
		uv = (s(u_c) * s(v_c)) >>> FRAC;
		uvv = (uv * s(v_c)) >>> FRAC;
		un = ((s(u_c) + ((DU * lapU) >>> FRAC)) - uvv) + ((FF * (ONE - s(u_c))) >>> FRAC);
		vn = ((s(v_c) + ((DV * lapV) >>> FRAC)) + uvv) - ((FK * s(v_c)) >>> FRAC);
		if (un < 0)
			u_o = 16'd0;
		else if (un > ONE)
			u_o = ONE[15:0];
		else
			u_o = un[15:0];
		if (vn < 0)
			v_o = 16'd0;
		else if (vn > ONE)
			v_o = ONE[15:0];
		else
			v_o = vn[15:0];
	end
	initial _sv2v_0 = 0;
endmodule