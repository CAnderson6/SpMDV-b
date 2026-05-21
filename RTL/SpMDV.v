module SpMDV 
(
	input clk,
	input rst,

	// Input signals
	input start_init,
    input [7 : 0] raw_input,
    input raw_data_valid,
	input w_input_valid,

	// Output signals
    output reg raw_data_request,
	output reg ld_w_request,
	output reg [21 : 0] o_result,
	output reg o_valid
);

    //Counters
	reg [13:0] load_count; // weight/position: 0~12287, vector: 0~4095
    reg [8:0]  row_count; // 0~255
	reg [3:0]  vector_count; // 0~15

	//States
    localparam IDLE0         = 5'd0;
    localparam LOAD_WEIGHT   = 5'd1;
    localparam LOAD_POSITION = 5'd2;
    localparam LOAD_BIAS     = 5'd3;
    localparam IDLE1         = 5'd4;
    localparam LOAD_VECTOR   = 5'd5;
	localparam PRE_LOAD      = 5'd6;
	localparam WAIT_LOAD     = 5'd7;
    localparam READ_BIAS     = 5'd8;
    localparam WAIT_BIAS     = 5'd9;
    localparam INIT_MULT     = 5'd10;
	localparam COMPUTE_PIPE  = 5'd11;
	localparam OUTPUT        = 5'd12;

	reg [4:0] state;
	reg [4:0] nextstate;

	// weight SRAM lane0 (*3 4096*8)
	reg  [11:0] w0_A, w1_A, w2_A;
	reg  [7:0]  w0_D, w1_D, w2_D;
	wire [7:0]  w0_Q, w1_Q, w2_Q;
	reg  w0_CEN, w1_CEN, w2_CEN;
	reg  w0_WEN, w1_WEN, w2_WEN;

	// weight SRAM lane1 duplicated (*3 4096*8)
	reg  [11:0] w0b_A, w1b_A, w2b_A;
	reg  [7:0]  w0b_D, w1b_D, w2b_D;
	wire [7:0]  w0b_Q, w1b_Q, w2b_Q;
	reg  w0b_CEN, w1b_CEN, w2b_CEN;
	reg  w0b_WEN, w1b_WEN, w2b_WEN;

	// weight SRAM lane2 duplicated (*3 4096*8)
	reg  [11:0] w0c_A, w1c_A, w2c_A;
	reg  [7:0]  w0c_D, w1c_D, w2c_D;
	wire [7:0]  w0c_Q, w1c_Q, w2c_Q;
	reg  w0c_CEN, w1c_CEN, w2c_CEN;
	reg  w0c_WEN, w1c_WEN, w2c_WEN;

	// weight SRAM lane3 duplicated (*3 4096*8)
	reg  [11:0] w0d_A, w1d_A, w2d_A;
	reg  [7:0]  w0d_D, w1d_D, w2d_D;
	wire [7:0]  w0d_Q, w1d_Q, w2d_Q;
	reg  w0d_CEN, w1d_CEN, w2d_CEN;
	reg  w0d_WEN, w1d_WEN, w2d_WEN;

	// weight SRAM lane4 duplicated (*3 4096*8)
	reg  [11:0] w0e_A, w1e_A, w2e_A;
	reg  [7:0]  w0e_D, w1e_D, w2e_D;
	wire [7:0]  w0e_Q, w1e_Q, w2e_Q;
	reg  w0e_CEN, w1e_CEN, w2e_CEN;
	reg  w0e_WEN, w1e_WEN, w2e_WEN;

	// weight SRAM lane5 duplicated (*3 4096*8)
	reg  [11:0] w0f_A, w1f_A, w2f_A;
	reg  [7:0]  w0f_D, w1f_D, w2f_D;
	wire [7:0]  w0f_Q, w1f_Q, w2f_Q;
	reg  w0f_CEN, w1f_CEN, w2f_CEN;
	reg  w0f_WEN, w1f_WEN, w2f_WEN;

	// weight SRAM lane6 duplicated (*3 4096*8)
	reg  [11:0] w0g_A, w1g_A, w2g_A;
	reg  [7:0]  w0g_D, w1g_D, w2g_D;
	wire [7:0]  w0g_Q, w1g_Q, w2g_Q;
	reg  w0g_CEN, w1g_CEN, w2g_CEN;
	reg  w0g_WEN, w1g_WEN, w2g_WEN;

	// weight SRAM lane7 duplicated (*3 4096*8)
	reg  [11:0] w0h_A, w1h_A, w2h_A;
	reg  [7:0]  w0h_D, w1h_D, w2h_D;
	wire [7:0]  w0h_Q, w1h_Q, w2h_Q;
	reg  w0h_CEN, w1h_CEN, w2h_CEN;
	reg  w0h_WEN, w1h_WEN, w2h_WEN;

	// weight SRAM lane8 duplicated (*3 4096*8)
	reg  [11:0] w0i_A, w1i_A, w2i_A;
	reg  [7:0]  w0i_D, w1i_D, w2i_D;
	wire [7:0]  w0i_Q, w1i_Q, w2i_Q;
	reg  w0i_CEN, w1i_CEN, w2i_CEN;
	reg  w0i_WEN, w1i_WEN, w2i_WEN;

	// weight SRAM lane9 duplicated (*3 4096*8)
	reg  [11:0] w0j_A, w1j_A, w2j_A;
	reg  [7:0]  w0j_D, w1j_D, w2j_D;
	wire [7:0]  w0j_Q, w1j_Q, w2j_Q;
	reg  w0j_CEN, w1j_CEN, w2j_CEN;
	reg  w0j_WEN, w1j_WEN, w2j_WEN;

	// weight SRAM lane10 duplicated (*3 4096*8)
	reg  [11:0] w0k_A, w1k_A, w2k_A;
	reg  [7:0]  w0k_D, w1k_D, w2k_D;
	wire [7:0]  w0k_Q, w1k_Q, w2k_Q;
	reg  w0k_CEN, w1k_CEN, w2k_CEN;
	reg  w0k_WEN, w1k_WEN, w2k_WEN;

	// weight SRAM lane11 duplicated (*3 4096*8)
	reg  [11:0] w0l_A, w1l_A, w2l_A;
	reg  [7:0]  w0l_D, w1l_D, w2l_D;
	wire [7:0]  w0l_Q, w1l_Q, w2l_Q;
	reg  w0l_CEN, w1l_CEN, w2l_CEN;
	reg  w0l_WEN, w1l_WEN, w2l_WEN;

	// weight SRAM lane12 duplicated (*3 4096*8)
	reg  [11:0] w0m_A, w1m_A, w2m_A;
	reg  [7:0]  w0m_D, w1m_D, w2m_D;
	wire [7:0]  w0m_Q, w1m_Q, w2m_Q;
	reg  w0m_CEN, w1m_CEN, w2m_CEN;
	reg  w0m_WEN, w1m_WEN, w2m_WEN;

	// weight SRAM lane13 duplicated (*3 4096*8)
	reg  [11:0] w0n_A, w1n_A, w2n_A;
	reg  [7:0]  w0n_D, w1n_D, w2n_D;
	wire [7:0]  w0n_Q, w1n_Q, w2n_Q;
	reg  w0n_CEN, w1n_CEN, w2n_CEN;
	reg  w0n_WEN, w1n_WEN, w2n_WEN;

	// weight SRAM lane14 duplicated (*3 4096*8)
	reg  [11:0] w0o_A, w1o_A, w2o_A;
	reg  [7:0]  w0o_D, w1o_D, w2o_D;
	wire [7:0]  w0o_Q, w1o_Q, w2o_Q;
	reg  w0o_CEN, w1o_CEN, w2o_CEN;
	reg  w0o_WEN, w1o_WEN, w2o_WEN;

	// weight SRAM lane15 duplicated (*3 4096*8)
	reg  [11:0] w0p_A, w1p_A, w2p_A;
	reg  [7:0]  w0p_D, w1p_D, w2p_D;
	wire [7:0]  w0p_Q, w1p_Q, w2p_Q;
	reg  w0p_CEN, w1p_CEN, w2p_CEN;
	reg  w0p_WEN, w1p_WEN, w2p_WEN;

	// position SRAM lane0 (*3 4096*8)
	reg  [11:0] p0_A, p1_A, p2_A;
	reg  [7:0]  p0_D, p1_D, p2_D;
	wire [7:0]  p0_Q, p1_Q, p2_Q;
	reg  p0_CEN, p1_CEN, p2_CEN;
	reg  p0_WEN, p1_WEN, p2_WEN;

	// position SRAM lane1 duplicated (*3 4096*8)
	reg  [11:0] p0b_A, p1b_A, p2b_A;
	reg  [7:0]  p0b_D, p1b_D, p2b_D;
	wire [7:0]  p0b_Q, p1b_Q, p2b_Q;
	reg  p0b_CEN, p1b_CEN, p2b_CEN;
	reg  p0b_WEN, p1b_WEN, p2b_WEN;

	// position SRAM lane2 duplicated (*3 4096*8)
	reg  [11:0] p0c_A, p1c_A, p2c_A;
	reg  [7:0]  p0c_D, p1c_D, p2c_D;
	wire [7:0]  p0c_Q, p1c_Q, p2c_Q;
	reg  p0c_CEN, p1c_CEN, p2c_CEN;
	reg  p0c_WEN, p1c_WEN, p2c_WEN;

	// position SRAM lane3 duplicated (*3 4096*8)
	reg  [11:0] p0d_A, p1d_A, p2d_A;
	reg  [7:0]  p0d_D, p1d_D, p2d_D;
	wire [7:0]  p0d_Q, p1d_Q, p2d_Q;
	reg  p0d_CEN, p1d_CEN, p2d_CEN;
	reg  p0d_WEN, p1d_WEN, p2d_WEN;

	// position SRAM lane4 duplicated (*3 4096*8)
	reg  [11:0] p0e_A, p1e_A, p2e_A;
	reg  [7:0]  p0e_D, p1e_D, p2e_D;
	wire [7:0]  p0e_Q, p1e_Q, p2e_Q;
	reg  p0e_CEN, p1e_CEN, p2e_CEN;
	reg  p0e_WEN, p1e_WEN, p2e_WEN;

	// position SRAM lane5 duplicated (*3 4096*8)
	reg  [11:0] p0f_A, p1f_A, p2f_A;
	reg  [7:0]  p0f_D, p1f_D, p2f_D;
	wire [7:0]  p0f_Q, p1f_Q, p2f_Q;
	reg  p0f_CEN, p1f_CEN, p2f_CEN;
	reg  p0f_WEN, p1f_WEN, p2f_WEN;

	// position SRAM lane6 duplicated (*3 4096*8)
	reg  [11:0] p0g_A, p1g_A, p2g_A;
	reg  [7:0]  p0g_D, p1g_D, p2g_D;
	wire [7:0]  p0g_Q, p1g_Q, p2g_Q;
	reg  p0g_CEN, p1g_CEN, p2g_CEN;
	reg  p0g_WEN, p1g_WEN, p2g_WEN;

	// position SRAM lane7 duplicated (*3 4096*8)
	reg  [11:0] p0h_A, p1h_A, p2h_A;
	reg  [7:0]  p0h_D, p1h_D, p2h_D;
	wire [7:0]  p0h_Q, p1h_Q, p2h_Q;
	reg  p0h_CEN, p1h_CEN, p2h_CEN;
	reg  p0h_WEN, p1h_WEN, p2h_WEN;

	// position SRAM lane8 duplicated (*3 4096*8)
	reg  [11:0] p0i_A, p1i_A, p2i_A;
	reg  [7:0]  p0i_D, p1i_D, p2i_D;
	wire [7:0]  p0i_Q, p1i_Q, p2i_Q;
	reg  p0i_CEN, p1i_CEN, p2i_CEN;
	reg  p0i_WEN, p1i_WEN, p2i_WEN;

	// position SRAM lane9 duplicated (*3 4096*8)
	reg  [11:0] p0j_A, p1j_A, p2j_A;
	reg  [7:0]  p0j_D, p1j_D, p2j_D;
	wire [7:0]  p0j_Q, p1j_Q, p2j_Q;
	reg  p0j_CEN, p1j_CEN, p2j_CEN;
	reg  p0j_WEN, p1j_WEN, p2j_WEN;

	// position SRAM lane10 duplicated (*3 4096*8)
	reg  [11:0] p0k_A, p1k_A, p2k_A;
	reg  [7:0]  p0k_D, p1k_D, p2k_D;
	wire [7:0]  p0k_Q, p1k_Q, p2k_Q;
	reg  p0k_CEN, p1k_CEN, p2k_CEN;
	reg  p0k_WEN, p1k_WEN, p2k_WEN;

	// position SRAM lane11 duplicated (*3 4096*8)
	reg  [11:0] p0l_A, p1l_A, p2l_A;
	reg  [7:0]  p0l_D, p1l_D, p2l_D;
	wire [7:0]  p0l_Q, p1l_Q, p2l_Q;
	reg  p0l_CEN, p1l_CEN, p2l_CEN;
	reg  p0l_WEN, p1l_WEN, p2l_WEN;

	// position SRAM lane12 duplicated (*3 4096*8)
	reg  [11:0] p0m_A, p1m_A, p2m_A;
	reg  [7:0]  p0m_D, p1m_D, p2m_D;
	wire [7:0]  p0m_Q, p1m_Q, p2m_Q;
	reg  p0m_CEN, p1m_CEN, p2m_CEN;
	reg  p0m_WEN, p1m_WEN, p2m_WEN;

	// position SRAM lane13 duplicated (*3 4096*8)
	reg  [11:0] p0n_A, p1n_A, p2n_A;
	reg  [7:0]  p0n_D, p1n_D, p2n_D;
	wire [7:0]  p0n_Q, p1n_Q, p2n_Q;
	reg  p0n_CEN, p1n_CEN, p2n_CEN;
	reg  p0n_WEN, p1n_WEN, p2n_WEN;

	// position SRAM lane14 duplicated (*3 4096*8)
	reg  [11:0] p0o_A, p1o_A, p2o_A;
	reg  [7:0]  p0o_D, p1o_D, p2o_D;
	wire [7:0]  p0o_Q, p1o_Q, p2o_Q;
	reg  p0o_CEN, p1o_CEN, p2o_CEN;
	reg  p0o_WEN, p1o_WEN, p2o_WEN;

	// position SRAM lane15 duplicated (*3 4096*8)
	reg  [11:0] p0p_A, p1p_A, p2p_A;
	reg  [7:0]  p0p_D, p1p_D, p2p_D;
	wire [7:0]  p0p_Q, p1p_Q, p2p_Q;
	reg  p0p_CEN, p1p_CEN, p2p_CEN;
	reg  p0p_WEN, p1p_WEN, p2p_WEN;

	// bias SRAM (*1 256*8)
	reg  [7:0] b_A;
	reg  [7:0] b_D;
	wire [7:0] b_Q;
	reg  b_CEN;
	reg  b_WEN;

	// vector SRAM lane0 (*1 4096*8)
	reg  [11:0] x_A;
	reg  [7:0]  x_D;
	wire [7:0]  x_Q;
	reg  x_CEN;
	reg  x_WEN;

	// vector SRAM lane1 duplicated (*1 4096*8)
	reg  [11:0] xb_A;
	reg  [7:0]  xb_D;
	wire [7:0]  xb_Q;
	reg  xb_CEN;
	reg  xb_WEN;

	// vector SRAM lane2 duplicated (*1 4096*8)
	reg  [11:0] xc_A;
	reg  [7:0]  xc_D;
	wire [7:0]  xc_Q;
	reg  xc_CEN;
	reg  xc_WEN;

	// vector SRAM lane3 duplicated (*1 4096*8)
	reg  [11:0] xd_A;
	reg  [7:0]  xd_D;
	wire [7:0]  xd_Q;
	reg  xd_CEN;
	reg  xd_WEN;

	// vector SRAM lane4 duplicated (*1 4096*8)
	reg  [11:0] xe_A;
	reg  [7:0]  xe_D;
	wire [7:0]  xe_Q;
	reg  xe_CEN;
	reg  xe_WEN;

	// vector SRAM lane5 duplicated (*1 4096*8)
	reg  [11:0] xf_A;
	reg  [7:0]  xf_D;
	wire [7:0]  xf_Q;
	reg  xf_CEN;
	reg  xf_WEN;

	// vector SRAM lane6 duplicated (*1 4096*8)
	reg  [11:0] xg_A;
	reg  [7:0]  xg_D;
	wire [7:0]  xg_Q;
	reg  xg_CEN;
	reg  xg_WEN;

	// vector SRAM lane7 duplicated (*1 4096*8)
	reg  [11:0] xh_A;
	reg  [7:0]  xh_D;
	wire [7:0]  xh_Q;
	reg  xh_CEN;
	reg  xh_WEN;

	// vector SRAM lane8 duplicated (*1 4096*8)
	reg  [11:0] xi_A;
	reg  [7:0]  xi_D;
	wire [7:0]  xi_Q;
	reg  xi_CEN;
	reg  xi_WEN;

	// vector SRAM lane9 duplicated (*1 4096*8)
	reg  [11:0] xj_A;
	reg  [7:0]  xj_D;
	wire [7:0]  xj_Q;
	reg  xj_CEN;
	reg  xj_WEN;

	// vector SRAM lane10 duplicated (*1 4096*8)
	reg  [11:0] xk_A;
	reg  [7:0]  xk_D;
	wire [7:0]  xk_Q;
	reg  xk_CEN;
	reg  xk_WEN;

	// vector SRAM lane11 duplicated (*1 4096*8)
	reg  [11:0] xl_A;
	reg  [7:0]  xl_D;
	wire [7:0]  xl_Q;
	reg  xl_CEN;
	reg  xl_WEN;

	// vector SRAM lane12 duplicated (*1 4096*8)
	reg  [11:0] xm_A;
	reg  [7:0]  xm_D;
	wire [7:0]  xm_Q;
	reg  xm_CEN;
	reg  xm_WEN;

	// vector SRAM lane13 duplicated (*1 4096*8)
	reg  [11:0] xn_A;
	reg  [7:0]  xn_D;
	wire [7:0]  xn_Q;
	reg  xn_CEN;
	reg  xn_WEN;

	// vector SRAM lane14 duplicated (*1 4096*8)
	reg  [11:0] xo_A;
	reg  [7:0]  xo_D;
	wire [7:0]  xo_Q;
	reg  xo_CEN;
	reg  xo_WEN;

	// vector SRAM lane15 duplicated (*1 4096*8)
	reg  [11:0] xp_A;
	reg  [7:0]  xp_D;
	wire [7:0]  xp_Q;
	reg  xp_CEN;
	reg  xp_WEN;

	// SRAMs lane0
	sram_4096x8 W_0 (.A(w0_A), .D(w0_D), .Q(w0_Q),
					.CLK(clk), .CEN(w0_CEN), .WEN(w0_WEN));
	sram_4096x8 W_1 (.A(w1_A), .D(w1_D), .Q(w1_Q),
					.CLK(clk), .CEN(w1_CEN), .WEN(w1_WEN));
	sram_4096x8 W_2 (.A(w2_A), .D(w2_D), .Q(w2_Q),
					.CLK(clk), .CEN(w2_CEN), .WEN(w2_WEN));

	sram_4096x8 P_0 (.A(p0_A), .D(p0_D), .Q(p0_Q),
					.CLK(clk), .CEN(p0_CEN), .WEN(p0_WEN));
	sram_4096x8 P_1 (.A(p1_A), .D(p1_D), .Q(p1_Q),
					.CLK(clk), .CEN(p1_CEN), .WEN(p1_WEN));
	sram_4096x8 P_2 (.A(p2_A), .D(p2_D), .Q(p2_Q),
					.CLK(clk), .CEN(p2_CEN), .WEN(p2_WEN));

	// SRAMs lane1 duplicated
	sram_4096x8 W_0B (.A(w0b_A), .D(w0b_D), .Q(w0b_Q),
					.CLK(clk), .CEN(w0b_CEN), .WEN(w0b_WEN));
	sram_4096x8 W_1B (.A(w1b_A), .D(w1b_D), .Q(w1b_Q),
					.CLK(clk), .CEN(w1b_CEN), .WEN(w1b_WEN));
	sram_4096x8 W_2B (.A(w2b_A), .D(w2b_D), .Q(w2b_Q),
					.CLK(clk), .CEN(w2b_CEN), .WEN(w2b_WEN));

	sram_4096x8 P_0B (.A(p0b_A), .D(p0b_D), .Q(p0b_Q),
					.CLK(clk), .CEN(p0b_CEN), .WEN(p0b_WEN));
	sram_4096x8 P_1B (.A(p1b_A), .D(p1b_D), .Q(p1b_Q),
					.CLK(clk), .CEN(p1b_CEN), .WEN(p1b_WEN));
	sram_4096x8 P_2B (.A(p2b_A), .D(p2b_D), .Q(p2b_Q),
					.CLK(clk), .CEN(p2b_CEN), .WEN(p2b_WEN));

	// SRAMs lane2 duplicated
	sram_4096x8 W_0C (.A(w0c_A), .D(w0c_D), .Q(w0c_Q),
					.CLK(clk), .CEN(w0c_CEN), .WEN(w0c_WEN));
	sram_4096x8 W_1C (.A(w1c_A), .D(w1c_D), .Q(w1c_Q),
					.CLK(clk), .CEN(w1c_CEN), .WEN(w1c_WEN));
	sram_4096x8 W_2C (.A(w2c_A), .D(w2c_D), .Q(w2c_Q),
					.CLK(clk), .CEN(w2c_CEN), .WEN(w2c_WEN));

	sram_4096x8 P_0C (.A(p0c_A), .D(p0c_D), .Q(p0c_Q),
					.CLK(clk), .CEN(p0c_CEN), .WEN(p0c_WEN));
	sram_4096x8 P_1C (.A(p1c_A), .D(p1c_D), .Q(p1c_Q),
					.CLK(clk), .CEN(p1c_CEN), .WEN(p1c_WEN));
	sram_4096x8 P_2C (.A(p2c_A), .D(p2c_D), .Q(p2c_Q),
					.CLK(clk), .CEN(p2c_CEN), .WEN(p2c_WEN));

	// SRAMs lane3 duplicated
	sram_4096x8 W_0D (.A(w0d_A), .D(w0d_D), .Q(w0d_Q),
					.CLK(clk), .CEN(w0d_CEN), .WEN(w0d_WEN));
	sram_4096x8 W_1D (.A(w1d_A), .D(w1d_D), .Q(w1d_Q),
					.CLK(clk), .CEN(w1d_CEN), .WEN(w1d_WEN));
	sram_4096x8 W_2D (.A(w2d_A), .D(w2d_D), .Q(w2d_Q),
					.CLK(clk), .CEN(w2d_CEN), .WEN(w2d_WEN));

	sram_4096x8 P_0D (.A(p0d_A), .D(p0d_D), .Q(p0d_Q),
					.CLK(clk), .CEN(p0d_CEN), .WEN(p0d_WEN));
	sram_4096x8 P_1D (.A(p1d_A), .D(p1d_D), .Q(p1d_Q),
					.CLK(clk), .CEN(p1d_CEN), .WEN(p1d_WEN));
	sram_4096x8 P_2D (.A(p2d_A), .D(p2d_D), .Q(p2d_Q),
					.CLK(clk), .CEN(p2d_CEN), .WEN(p2d_WEN));

	// SRAMs lane4 duplicated
	sram_4096x8 W_0E (.A(w0e_A), .D(w0e_D), .Q(w0e_Q),
					.CLK(clk), .CEN(w0e_CEN), .WEN(w0e_WEN));
	sram_4096x8 W_1E (.A(w1e_A), .D(w1e_D), .Q(w1e_Q),
					.CLK(clk), .CEN(w1e_CEN), .WEN(w1e_WEN));
	sram_4096x8 W_2E (.A(w2e_A), .D(w2e_D), .Q(w2e_Q),
					.CLK(clk), .CEN(w2e_CEN), .WEN(w2e_WEN));

	sram_4096x8 P_0E (.A(p0e_A), .D(p0e_D), .Q(p0e_Q),
					.CLK(clk), .CEN(p0e_CEN), .WEN(p0e_WEN));
	sram_4096x8 P_1E (.A(p1e_A), .D(p1e_D), .Q(p1e_Q),
					.CLK(clk), .CEN(p1e_CEN), .WEN(p1e_WEN));
	sram_4096x8 P_2E (.A(p2e_A), .D(p2e_D), .Q(p2e_Q),
					.CLK(clk), .CEN(p2e_CEN), .WEN(p2e_WEN));

	// SRAMs lane5 duplicated
	sram_4096x8 W_0F (.A(w0f_A), .D(w0f_D), .Q(w0f_Q),
					.CLK(clk), .CEN(w0f_CEN), .WEN(w0f_WEN));
	sram_4096x8 W_1F (.A(w1f_A), .D(w1f_D), .Q(w1f_Q),
					.CLK(clk), .CEN(w1f_CEN), .WEN(w1f_WEN));
	sram_4096x8 W_2F (.A(w2f_A), .D(w2f_D), .Q(w2f_Q),
					.CLK(clk), .CEN(w2f_CEN), .WEN(w2f_WEN));

	sram_4096x8 P_0F (.A(p0f_A), .D(p0f_D), .Q(p0f_Q),
					.CLK(clk), .CEN(p0f_CEN), .WEN(p0f_WEN));
	sram_4096x8 P_1F (.A(p1f_A), .D(p1f_D), .Q(p1f_Q),
					.CLK(clk), .CEN(p1f_CEN), .WEN(p1f_WEN));
	sram_4096x8 P_2F (.A(p2f_A), .D(p2f_D), .Q(p2f_Q),
					.CLK(clk), .CEN(p2f_CEN), .WEN(p2f_WEN));

	// SRAMs lane6 duplicated
	sram_4096x8 W_0G (.A(w0g_A), .D(w0g_D), .Q(w0g_Q),
					.CLK(clk), .CEN(w0g_CEN), .WEN(w0g_WEN));
	sram_4096x8 W_1G (.A(w1g_A), .D(w1g_D), .Q(w1g_Q),
					.CLK(clk), .CEN(w1g_CEN), .WEN(w1g_WEN));
	sram_4096x8 W_2G (.A(w2g_A), .D(w2g_D), .Q(w2g_Q),
					.CLK(clk), .CEN(w2g_CEN), .WEN(w2g_WEN));

	sram_4096x8 P_0G (.A(p0g_A), .D(p0g_D), .Q(p0g_Q),
					.CLK(clk), .CEN(p0g_CEN), .WEN(p0g_WEN));
	sram_4096x8 P_1G (.A(p1g_A), .D(p1g_D), .Q(p1g_Q),
					.CLK(clk), .CEN(p1g_CEN), .WEN(p1g_WEN));
	sram_4096x8 P_2G (.A(p2g_A), .D(p2g_D), .Q(p2g_Q),
					.CLK(clk), .CEN(p2g_CEN), .WEN(p2g_WEN));

	// SRAMs lane7 duplicated
	sram_4096x8 W_0H (.A(w0h_A), .D(w0h_D), .Q(w0h_Q),
					.CLK(clk), .CEN(w0h_CEN), .WEN(w0h_WEN));
	sram_4096x8 W_1H (.A(w1h_A), .D(w1h_D), .Q(w1h_Q),
					.CLK(clk), .CEN(w1h_CEN), .WEN(w1h_WEN));
	sram_4096x8 W_2H (.A(w2h_A), .D(w2h_D), .Q(w2h_Q),
					.CLK(clk), .CEN(w2h_CEN), .WEN(w2h_WEN));

	sram_4096x8 P_0H (.A(p0h_A), .D(p0h_D), .Q(p0h_Q),
					.CLK(clk), .CEN(p0h_CEN), .WEN(p0h_WEN));
	sram_4096x8 P_1H (.A(p1h_A), .D(p1h_D), .Q(p1h_Q),
					.CLK(clk), .CEN(p1h_CEN), .WEN(p1h_WEN));
	sram_4096x8 P_2H (.A(p2h_A), .D(p2h_D), .Q(p2h_Q),
					.CLK(clk), .CEN(p2h_CEN), .WEN(p2h_WEN));

	// SRAMs lane8 duplicated
	sram_4096x8 W_0I (.A(w0i_A), .D(w0i_D), .Q(w0i_Q),
					.CLK(clk), .CEN(w0i_CEN), .WEN(w0i_WEN));
	sram_4096x8 W_1I (.A(w1i_A), .D(w1i_D), .Q(w1i_Q),
					.CLK(clk), .CEN(w1i_CEN), .WEN(w1i_WEN));
	sram_4096x8 W_2I (.A(w2i_A), .D(w2i_D), .Q(w2i_Q),
					.CLK(clk), .CEN(w2i_CEN), .WEN(w2i_WEN));

	sram_4096x8 P_0I (.A(p0i_A), .D(p0i_D), .Q(p0i_Q),
					.CLK(clk), .CEN(p0i_CEN), .WEN(p0i_WEN));
	sram_4096x8 P_1I (.A(p1i_A), .D(p1i_D), .Q(p1i_Q),
					.CLK(clk), .CEN(p1i_CEN), .WEN(p1i_WEN));
	sram_4096x8 P_2I (.A(p2i_A), .D(p2i_D), .Q(p2i_Q),
					.CLK(clk), .CEN(p2i_CEN), .WEN(p2i_WEN));

	// SRAMs lane9 duplicated
	sram_4096x8 W_0J (.A(w0j_A), .D(w0j_D), .Q(w0j_Q),
					.CLK(clk), .CEN(w0j_CEN), .WEN(w0j_WEN));
	sram_4096x8 W_1J (.A(w1j_A), .D(w1j_D), .Q(w1j_Q),
					.CLK(clk), .CEN(w1j_CEN), .WEN(w1j_WEN));
	sram_4096x8 W_2J (.A(w2j_A), .D(w2j_D), .Q(w2j_Q),
					.CLK(clk), .CEN(w2j_CEN), .WEN(w2j_WEN));

	sram_4096x8 P_0J (.A(p0j_A), .D(p0j_D), .Q(p0j_Q),
					.CLK(clk), .CEN(p0j_CEN), .WEN(p0j_WEN));
	sram_4096x8 P_1J (.A(p1j_A), .D(p1j_D), .Q(p1j_Q),
					.CLK(clk), .CEN(p1j_CEN), .WEN(p1j_WEN));
	sram_4096x8 P_2J (.A(p2j_A), .D(p2j_D), .Q(p2j_Q),
					.CLK(clk), .CEN(p2j_CEN), .WEN(p2j_WEN));

	// SRAMs lane10 duplicated
	sram_4096x8 W_0K (.A(w0k_A), .D(w0k_D), .Q(w0k_Q),
					.CLK(clk), .CEN(w0k_CEN), .WEN(w0k_WEN));
	sram_4096x8 W_1K (.A(w1k_A), .D(w1k_D), .Q(w1k_Q),
					.CLK(clk), .CEN(w1k_CEN), .WEN(w1k_WEN));
	sram_4096x8 W_2K (.A(w2k_A), .D(w2k_D), .Q(w2k_Q),
					.CLK(clk), .CEN(w2k_CEN), .WEN(w2k_WEN));

	sram_4096x8 P_0K (.A(p0k_A), .D(p0k_D), .Q(p0k_Q),
					.CLK(clk), .CEN(p0k_CEN), .WEN(p0k_WEN));
	sram_4096x8 P_1K (.A(p1k_A), .D(p1k_D), .Q(p1k_Q),
					.CLK(clk), .CEN(p1k_CEN), .WEN(p1k_WEN));
	sram_4096x8 P_2K (.A(p2k_A), .D(p2k_D), .Q(p2k_Q),
					.CLK(clk), .CEN(p2k_CEN), .WEN(p2k_WEN));

	// SRAMs lane11 duplicated
	sram_4096x8 W_0L (.A(w0l_A), .D(w0l_D), .Q(w0l_Q),
					.CLK(clk), .CEN(w0l_CEN), .WEN(w0l_WEN));
	sram_4096x8 W_1L (.A(w1l_A), .D(w1l_D), .Q(w1l_Q),
					.CLK(clk), .CEN(w1l_CEN), .WEN(w1l_WEN));
	sram_4096x8 W_2L (.A(w2l_A), .D(w2l_D), .Q(w2l_Q),
					.CLK(clk), .CEN(w2l_CEN), .WEN(w2l_WEN));

	sram_4096x8 P_0L (.A(p0l_A), .D(p0l_D), .Q(p0l_Q),
					.CLK(clk), .CEN(p0l_CEN), .WEN(p0l_WEN));
	sram_4096x8 P_1L (.A(p1l_A), .D(p1l_D), .Q(p1l_Q),
					.CLK(clk), .CEN(p1l_CEN), .WEN(p1l_WEN));
	sram_4096x8 P_2L (.A(p2l_A), .D(p2l_D), .Q(p2l_Q),
					.CLK(clk), .CEN(p2l_CEN), .WEN(p2l_WEN));

	// SRAMs lane12 duplicated
	sram_4096x8 W_0M (.A(w0m_A), .D(w0m_D), .Q(w0m_Q),
					.CLK(clk), .CEN(w0m_CEN), .WEN(w0m_WEN));
	sram_4096x8 W_1M (.A(w1m_A), .D(w1m_D), .Q(w1m_Q),
					.CLK(clk), .CEN(w1m_CEN), .WEN(w1m_WEN));
	sram_4096x8 W_2M (.A(w2m_A), .D(w2m_D), .Q(w2m_Q),
					.CLK(clk), .CEN(w2m_CEN), .WEN(w2m_WEN));

	sram_4096x8 P_0M (.A(p0m_A), .D(p0m_D), .Q(p0m_Q),
					.CLK(clk), .CEN(p0m_CEN), .WEN(p0m_WEN));
	sram_4096x8 P_1M (.A(p1m_A), .D(p1m_D), .Q(p1m_Q),
					.CLK(clk), .CEN(p1m_CEN), .WEN(p1m_WEN));
	sram_4096x8 P_2M (.A(p2m_A), .D(p2m_D), .Q(p2m_Q),
					.CLK(clk), .CEN(p2m_CEN), .WEN(p2m_WEN));

	// SRAMs lane13 duplicated
	sram_4096x8 W_0N (.A(w0n_A), .D(w0n_D), .Q(w0n_Q),
					.CLK(clk), .CEN(w0n_CEN), .WEN(w0n_WEN));
	sram_4096x8 W_1N (.A(w1n_A), .D(w1n_D), .Q(w1n_Q),
					.CLK(clk), .CEN(w1n_CEN), .WEN(w1n_WEN));
	sram_4096x8 W_2N (.A(w2n_A), .D(w2n_D), .Q(w2n_Q),
					.CLK(clk), .CEN(w2n_CEN), .WEN(w2n_WEN));

	sram_4096x8 P_0N (.A(p0n_A), .D(p0n_D), .Q(p0n_Q),
					.CLK(clk), .CEN(p0n_CEN), .WEN(p0n_WEN));
	sram_4096x8 P_1N (.A(p1n_A), .D(p1n_D), .Q(p1n_Q),
					.CLK(clk), .CEN(p1n_CEN), .WEN(p1n_WEN));
	sram_4096x8 P_2N (.A(p2n_A), .D(p2n_D), .Q(p2n_Q),
					.CLK(clk), .CEN(p2n_CEN), .WEN(p2n_WEN));

	// SRAMs lane14 duplicated
	sram_4096x8 W_0O (.A(w0o_A), .D(w0o_D), .Q(w0o_Q),
					.CLK(clk), .CEN(w0o_CEN), .WEN(w0o_WEN));
	sram_4096x8 W_1O (.A(w1o_A), .D(w1o_D), .Q(w1o_Q),
					.CLK(clk), .CEN(w1o_CEN), .WEN(w1o_WEN));
	sram_4096x8 W_2O (.A(w2o_A), .D(w2o_D), .Q(w2o_Q),
					.CLK(clk), .CEN(w2o_CEN), .WEN(w2o_WEN));

	sram_4096x8 P_0O (.A(p0o_A), .D(p0o_D), .Q(p0o_Q),
					.CLK(clk), .CEN(p0o_CEN), .WEN(p0o_WEN));
	sram_4096x8 P_1O (.A(p1o_A), .D(p1o_D), .Q(p1o_Q),
					.CLK(clk), .CEN(p1o_CEN), .WEN(p1o_WEN));
	sram_4096x8 P_2O (.A(p2o_A), .D(p2o_D), .Q(p2o_Q),
					.CLK(clk), .CEN(p2o_CEN), .WEN(p2o_WEN));

	// SRAMs lane15 duplicated
	sram_4096x8 W_0P (.A(w0p_A), .D(w0p_D), .Q(w0p_Q),
					.CLK(clk), .CEN(w0p_CEN), .WEN(w0p_WEN));
	sram_4096x8 W_1P (.A(w1p_A), .D(w1p_D), .Q(w1p_Q),
					.CLK(clk), .CEN(w1p_CEN), .WEN(w1p_WEN));
	sram_4096x8 W_2P (.A(w2p_A), .D(w2p_D), .Q(w2p_Q),
					.CLK(clk), .CEN(w2p_CEN), .WEN(w2p_WEN));

	sram_4096x8 P_0P (.A(p0p_A), .D(p0p_D), .Q(p0p_Q),
					.CLK(clk), .CEN(p0p_CEN), .WEN(p0p_WEN));
	sram_4096x8 P_1P (.A(p1p_A), .D(p1p_D), .Q(p1p_Q),
					.CLK(clk), .CEN(p1p_CEN), .WEN(p1p_WEN));
	sram_4096x8 P_2P (.A(p2p_A), .D(p2p_D), .Q(p2p_Q),
					.CLK(clk), .CEN(p2p_CEN), .WEN(p2p_WEN));

	sram_256x8  B_  (.A(b_A),  .D(b_D),  .Q(b_Q),
					.CLK(clk), .CEN(b_CEN),  .WEN(b_WEN));

	sram_4096x8 X_   (.A(x_A), .D(x_D), .Q(x_Q),
					.CLK(clk), .CEN(x_CEN), .WEN(x_WEN));
	sram_4096x8 X_B  (.A(xb_A), .D(xb_D), .Q(xb_Q),
					.CLK(clk), .CEN(xb_CEN), .WEN(xb_WEN));
	sram_4096x8 X_C  (.A(xc_A), .D(xc_D), .Q(xc_Q),
					.CLK(clk), .CEN(xc_CEN), .WEN(xc_WEN));
	sram_4096x8 X_D  (.A(xd_A), .D(xd_D), .Q(xd_Q),
					.CLK(clk), .CEN(xd_CEN), .WEN(xd_WEN));
	sram_4096x8 X_E  (.A(xe_A), .D(xe_D), .Q(xe_Q),
					.CLK(clk), .CEN(xe_CEN), .WEN(xe_WEN));
	sram_4096x8 X_F  (.A(xf_A), .D(xf_D), .Q(xf_Q),
					.CLK(clk), .CEN(xf_CEN), .WEN(xf_WEN));
	sram_4096x8 X_G  (.A(xg_A), .D(xg_D), .Q(xg_Q),
					.CLK(clk), .CEN(xg_CEN), .WEN(xg_WEN));
	sram_4096x8 X_H  (.A(xh_A), .D(xh_D), .Q(xh_Q),
					.CLK(clk), .CEN(xh_CEN), .WEN(xh_WEN));
	sram_4096x8 X_I  (.A(xi_A), .D(xi_D), .Q(xi_Q),
					.CLK(clk), .CEN(xi_CEN), .WEN(xi_WEN));
	sram_4096x8 X_J  (.A(xj_A), .D(xj_D), .Q(xj_Q),
					.CLK(clk), .CEN(xj_CEN), .WEN(xj_WEN));
	sram_4096x8 X_K  (.A(xk_A), .D(xk_D), .Q(xk_Q),
					.CLK(clk), .CEN(xk_CEN), .WEN(xk_WEN));
	sram_4096x8 X_L  (.A(xl_A), .D(xl_D), .Q(xl_Q),
					.CLK(clk), .CEN(xl_CEN), .WEN(xl_WEN));
	sram_4096x8 X_M  (.A(xm_A), .D(xm_D), .Q(xm_Q),
					.CLK(clk), .CEN(xm_CEN), .WEN(xm_WEN));
	sram_4096x8 X_N  (.A(xn_A), .D(xn_D), .Q(xn_Q),
					.CLK(clk), .CEN(xn_CEN), .WEN(xn_WEN));
	sram_4096x8 X_O  (.A(xo_A), .D(xo_D), .Q(xo_Q),
					.CLK(clk), .CEN(xo_CEN), .WEN(xo_WEN));
	sram_4096x8 X_P  (.A(xp_A), .D(xp_D), .Q(xp_Q),
					.CLK(clk), .CEN(xp_CEN), .WEN(xp_WEN));

	//Computing
	reg signed [21:0] sum;

	// pipeline registers
	reg [5:0] pipe_issue;   // issued W/P read count, 0~48, step by 16
	reg [5:0] pipe_done;    // finished MAC count, 0~48, step by 16

	reg pipe_wp_valid;
	reg pipe_x_valid;

	reg [1:0] pipe_wp_sram0;
	reg [1:0] pipe_wp_sram1;
	reg [1:0] pipe_wp_sram2;
	reg [1:0] pipe_wp_sram3;
	reg [1:0] pipe_wp_sram4;
	reg [1:0] pipe_wp_sram5;
	reg [1:0] pipe_wp_sram6;
	reg [1:0] pipe_wp_sram7;
	reg [1:0] pipe_wp_sram8;
	reg [1:0] pipe_wp_sram9;
	reg [1:0] pipe_wp_sram10;
	reg [1:0] pipe_wp_sram11;
	reg [1:0] pipe_wp_sram12;
	reg [1:0] pipe_wp_sram13;
	reg [1:0] pipe_wp_sram14;
	reg [1:0] pipe_wp_sram15;

	reg [1:0] pipe_bank0;
	reg [1:0] pipe_bank1;
	reg [1:0] pipe_bank2;
	reg [1:0] pipe_bank3;
	reg [1:0] pipe_bank4;
	reg [1:0] pipe_bank5;
	reg [1:0] pipe_bank6;
	reg [1:0] pipe_bank7;
	reg [1:0] pipe_bank8;
	reg [1:0] pipe_bank9;
	reg [1:0] pipe_bank10;
	reg [1:0] pipe_bank11;
	reg [1:0] pipe_bank12;
	reg [1:0] pipe_bank13;
	reg [1:0] pipe_bank14;
	reg [1:0] pipe_bank15;

	reg signed [7:0] pipe_weight0_r;
	reg signed [7:0] pipe_weight1_r;
	reg signed [7:0] pipe_weight2_r;
	reg signed [7:0] pipe_weight3_r;
	reg signed [7:0] pipe_weight4_r;
	reg signed [7:0] pipe_weight5_r;
	reg signed [7:0] pipe_weight6_r;
	reg signed [7:0] pipe_weight7_r;
	reg signed [7:0] pipe_weight8_r;
	reg signed [7:0] pipe_weight9_r;
	reg signed [7:0] pipe_weight10_r;
	reg signed [7:0] pipe_weight11_r;
	reg signed [7:0] pipe_weight12_r;
	reg signed [7:0] pipe_weight13_r;
	reg signed [7:0] pipe_weight14_r;
	reg signed [7:0] pipe_weight15_r;

	wire [5:0] pipe_issue_plus1;
	wire [5:0] pipe_issue_plus2;
	wire [5:0] pipe_issue_plus3;
	wire [5:0] pipe_issue_plus4;
	wire [5:0] pipe_issue_plus5;
	wire [5:0] pipe_issue_plus6;
	wire [5:0] pipe_issue_plus7;
	wire [5:0] pipe_issue_plus8;
	wire [5:0] pipe_issue_plus9;
	wire [5:0] pipe_issue_plus10;
	wire [5:0] pipe_issue_plus11;
	wire [5:0] pipe_issue_plus12;
	wire [5:0] pipe_issue_plus13;
	wire [5:0] pipe_issue_plus14;
	wire [5:0] pipe_issue_plus15;

	wire [1:0] pipe_issue_bank1;
	wire [1:0] pipe_issue_bank2;
	wire [1:0] pipe_issue_bank3;
	wire [1:0] pipe_issue_bank4;
	wire [1:0] pipe_issue_bank5;
	wire [1:0] pipe_issue_bank6;
	wire [1:0] pipe_issue_bank7;
	wire [1:0] pipe_issue_bank8;
	wire [1:0] pipe_issue_bank9;
	wire [1:0] pipe_issue_bank10;
	wire [1:0] pipe_issue_bank11;
	wire [1:0] pipe_issue_bank12;
	wire [1:0] pipe_issue_bank13;
	wire [1:0] pipe_issue_bank14;
	wire [1:0] pipe_issue_bank15;

	wire [13:0] pipe_base_index;
	wire [13:0] pipe_issue_index0;
	wire [13:0] pipe_issue_index1;
	wire [13:0] pipe_issue_index2;
	wire [13:0] pipe_issue_index3;
	wire [13:0] pipe_issue_index4;
	wire [13:0] pipe_issue_index5;
	wire [13:0] pipe_issue_index6;
	wire [13:0] pipe_issue_index7;
	wire [13:0] pipe_issue_index8;
	wire [13:0] pipe_issue_index9;
	wire [13:0] pipe_issue_index10;
	wire [13:0] pipe_issue_index11;
	wire [13:0] pipe_issue_index12;
	wire [13:0] pipe_issue_index13;
	wire [13:0] pipe_issue_index14;
	wire [13:0] pipe_issue_index15;

	wire [1:0] pipe_issue_sram0;
	wire [1:0] pipe_issue_sram1;
	wire [1:0] pipe_issue_sram2;
	wire [1:0] pipe_issue_sram3;
	wire [1:0] pipe_issue_sram4;
	wire [1:0] pipe_issue_sram5;
	wire [1:0] pipe_issue_sram6;
	wire [1:0] pipe_issue_sram7;
	wire [1:0] pipe_issue_sram8;
	wire [1:0] pipe_issue_sram9;
	wire [1:0] pipe_issue_sram10;
	wire [1:0] pipe_issue_sram11;
	wire [1:0] pipe_issue_sram12;
	wire [1:0] pipe_issue_sram13;
	wire [1:0] pipe_issue_sram14;
	wire [1:0] pipe_issue_sram15;

	assign pipe_issue_plus1 = pipe_issue + 6'd1;
	assign pipe_issue_plus2 = pipe_issue + 6'd2;
	assign pipe_issue_plus3 = pipe_issue + 6'd3;
	assign pipe_issue_plus4 = pipe_issue + 6'd4;
	assign pipe_issue_plus5 = pipe_issue + 6'd5;
	assign pipe_issue_plus6 = pipe_issue + 6'd6;
	assign pipe_issue_plus7 = pipe_issue + 6'd7;
	assign pipe_issue_plus8 = pipe_issue + 6'd8;
	assign pipe_issue_plus9 = pipe_issue + 6'd9;
	assign pipe_issue_plus10 = pipe_issue + 6'd10;
	assign pipe_issue_plus11 = pipe_issue + 6'd11;
	assign pipe_issue_plus12 = pipe_issue + 6'd12;
	assign pipe_issue_plus13 = pipe_issue + 6'd13;
	assign pipe_issue_plus14 = pipe_issue + 6'd14;
	assign pipe_issue_plus15 = pipe_issue + 6'd15;

	assign pipe_issue_bank1 = pipe_issue_plus1[1:0];
	assign pipe_issue_bank2 = pipe_issue_plus2[1:0];
	assign pipe_issue_bank3 = pipe_issue_plus3[1:0];
	assign pipe_issue_bank4 = pipe_issue_plus4[1:0];
	assign pipe_issue_bank5 = pipe_issue_plus5[1:0];
	assign pipe_issue_bank6 = pipe_issue_plus6[1:0];
	assign pipe_issue_bank7 = pipe_issue_plus7[1:0];
	assign pipe_issue_bank8 = pipe_issue_plus8[1:0];
	assign pipe_issue_bank9 = pipe_issue_plus9[1:0];
	assign pipe_issue_bank10 = pipe_issue_plus10[1:0];
	assign pipe_issue_bank11 = pipe_issue_plus11[1:0];
	assign pipe_issue_bank12 = pipe_issue_plus12[1:0];
	assign pipe_issue_bank13 = pipe_issue_plus13[1:0];
	assign pipe_issue_bank14 = pipe_issue_plus14[1:0];
	assign pipe_issue_bank15 = pipe_issue_plus15[1:0];

	assign pipe_base_index = ({5'd0, row_count} << 5) +
	                         ({5'd0, row_count} << 4);

	assign pipe_issue_index0 = pipe_base_index + {8'd0, pipe_issue};
	assign pipe_issue_index1 = pipe_base_index + {8'd0, pipe_issue_plus1};
	assign pipe_issue_index2 = pipe_base_index + {8'd0, pipe_issue_plus2};
	assign pipe_issue_index3 = pipe_base_index + {8'd0, pipe_issue_plus3};
	assign pipe_issue_index4 = pipe_base_index + {8'd0, pipe_issue_plus4};
	assign pipe_issue_index5 = pipe_base_index + {8'd0, pipe_issue_plus5};
	assign pipe_issue_index6 = pipe_base_index + {8'd0, pipe_issue_plus6};
	assign pipe_issue_index7 = pipe_base_index + {8'd0, pipe_issue_plus7};
	assign pipe_issue_index8 = pipe_base_index + {8'd0, pipe_issue_plus8};
	assign pipe_issue_index9 = pipe_base_index + {8'd0, pipe_issue_plus9};
	assign pipe_issue_index10 = pipe_base_index + {8'd0, pipe_issue_plus10};
	assign pipe_issue_index11 = pipe_base_index + {8'd0, pipe_issue_plus11};
	assign pipe_issue_index12 = pipe_base_index + {8'd0, pipe_issue_plus12};
	assign pipe_issue_index13 = pipe_base_index + {8'd0, pipe_issue_plus13};
	assign pipe_issue_index14 = pipe_base_index + {8'd0, pipe_issue_plus14};
	assign pipe_issue_index15 = pipe_base_index + {8'd0, pipe_issue_plus15};

	assign pipe_issue_sram0 = pipe_issue_index0[13:12];
	assign pipe_issue_sram1 = pipe_issue_index1[13:12];
	assign pipe_issue_sram2 = pipe_issue_index2[13:12];
	assign pipe_issue_sram3 = pipe_issue_index3[13:12];
	assign pipe_issue_sram4 = pipe_issue_index4[13:12];
	assign pipe_issue_sram5 = pipe_issue_index5[13:12];
	assign pipe_issue_sram6 = pipe_issue_index6[13:12];
	assign pipe_issue_sram7 = pipe_issue_index7[13:12];
	assign pipe_issue_sram8 = pipe_issue_index8[13:12];
	assign pipe_issue_sram9 = pipe_issue_index9[13:12];
	assign pipe_issue_sram10 = pipe_issue_index10[13:12];
	assign pipe_issue_sram11 = pipe_issue_index11[13:12];
	assign pipe_issue_sram12 = pipe_issue_index12[13:12];
	assign pipe_issue_sram13 = pipe_issue_index13[13:12];
	assign pipe_issue_sram14 = pipe_issue_index14[13:12];
	assign pipe_issue_sram15 = pipe_issue_index15[13:12];

	reg signed [7:0] pipe_weight0_q;
	reg signed [7:0] pipe_weight1_q;
	reg signed [7:0] pipe_weight2_q;
	reg signed [7:0] pipe_weight3_q;
	reg signed [7:0] pipe_weight4_q;
	reg signed [7:0] pipe_weight5_q;
	reg signed [7:0] pipe_weight6_q;
	reg signed [7:0] pipe_weight7_q;
	reg signed [7:0] pipe_weight8_q;
	reg signed [7:0] pipe_weight9_q;
	reg signed [7:0] pipe_weight10_q;
	reg signed [7:0] pipe_weight11_q;
	reg signed [7:0] pipe_weight12_q;
	reg signed [7:0] pipe_weight13_q;
	reg signed [7:0] pipe_weight14_q;
	reg signed [7:0] pipe_weight15_q;

	reg [5:0] pipe_position0_q;
	reg [5:0] pipe_position1_q;
	reg [5:0] pipe_position2_q;
	reg [5:0] pipe_position3_q;
	reg [5:0] pipe_position4_q;
	reg [5:0] pipe_position5_q;
	reg [5:0] pipe_position6_q;
	reg [5:0] pipe_position7_q;
	reg [5:0] pipe_position8_q;
	reg [5:0] pipe_position9_q;
	reg [5:0] pipe_position10_q;
	reg [5:0] pipe_position11_q;
	reg [5:0] pipe_position12_q;
	reg [5:0] pipe_position13_q;
	reg [5:0] pipe_position14_q;
	reg [5:0] pipe_position15_q;

	reg [7:0] pipe_vector_index0;
	reg [7:0] pipe_vector_index1;
	reg [7:0] pipe_vector_index2;
	reg [7:0] pipe_vector_index3;
	reg [7:0] pipe_vector_index4;
	reg [7:0] pipe_vector_index5;
	reg [7:0] pipe_vector_index6;
	reg [7:0] pipe_vector_index7;
	reg [7:0] pipe_vector_index8;
	reg [7:0] pipe_vector_index9;
	reg [7:0] pipe_vector_index10;
	reg [7:0] pipe_vector_index11;
	reg [7:0] pipe_vector_index12;
	reg [7:0] pipe_vector_index13;
	reg [7:0] pipe_vector_index14;
	reg [7:0] pipe_vector_index15;

	// lane0 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram0)
			2'd0: begin
				pipe_weight0_q = w0_Q;
				pipe_position0_q = p0_Q[5:0];
			end

			2'd1: begin
				pipe_weight0_q = w1_Q;
				pipe_position0_q = p1_Q[5:0];
			end

			2'd2: begin
				pipe_weight0_q = w2_Q;
				pipe_position0_q = p2_Q[5:0];
			end

			default: begin
				pipe_weight0_q = 8'd0;
				pipe_position0_q = 6'd0;
			end
		endcase
	end

	// lane1 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram1)
			2'd0: begin
				pipe_weight1_q = w0b_Q;
				pipe_position1_q = p0b_Q[5:0];
			end

			2'd1: begin
				pipe_weight1_q = w1b_Q;
				pipe_position1_q = p1b_Q[5:0];
			end

			2'd2: begin
				pipe_weight1_q = w2b_Q;
				pipe_position1_q = p2b_Q[5:0];
			end

			default: begin
				pipe_weight1_q = 8'd0;
				pipe_position1_q = 6'd0;
			end
		endcase
	end

	// lane2 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram2)
			2'd0: begin
				pipe_weight2_q = w0c_Q;
				pipe_position2_q = p0c_Q[5:0];
			end

			2'd1: begin
				pipe_weight2_q = w1c_Q;
				pipe_position2_q = p1c_Q[5:0];
			end

			2'd2: begin
				pipe_weight2_q = w2c_Q;
				pipe_position2_q = p2c_Q[5:0];
			end

			default: begin
				pipe_weight2_q = 8'd0;
				pipe_position2_q = 6'd0;
			end
		endcase
	end

	// lane3 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram3)
			2'd0: begin
				pipe_weight3_q = w0d_Q;
				pipe_position3_q = p0d_Q[5:0];
			end

			2'd1: begin
				pipe_weight3_q = w1d_Q;
				pipe_position3_q = p1d_Q[5:0];
			end

			2'd2: begin
				pipe_weight3_q = w2d_Q;
				pipe_position3_q = p2d_Q[5:0];
			end

			default: begin
				pipe_weight3_q = 8'd0;
				pipe_position3_q = 6'd0;
			end
		endcase
	end

	// lane4 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram4)
			2'd0: begin
				pipe_weight4_q = w0e_Q;
				pipe_position4_q = p0e_Q[5:0];
			end

			2'd1: begin
				pipe_weight4_q = w1e_Q;
				pipe_position4_q = p1e_Q[5:0];
			end

			2'd2: begin
				pipe_weight4_q = w2e_Q;
				pipe_position4_q = p2e_Q[5:0];
			end

			default: begin
				pipe_weight4_q = 8'd0;
				pipe_position4_q = 6'd0;
			end
		endcase
	end

	// lane5 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram5)
			2'd0: begin
				pipe_weight5_q = w0f_Q;
				pipe_position5_q = p0f_Q[5:0];
			end

			2'd1: begin
				pipe_weight5_q = w1f_Q;
				pipe_position5_q = p1f_Q[5:0];
			end

			2'd2: begin
				pipe_weight5_q = w2f_Q;
				pipe_position5_q = p2f_Q[5:0];
			end

			default: begin
				pipe_weight5_q = 8'd0;
				pipe_position5_q = 6'd0;
			end
		endcase
	end

	// lane6 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram6)
			2'd0: begin
				pipe_weight6_q = w0g_Q;
				pipe_position6_q = p0g_Q[5:0];
			end

			2'd1: begin
				pipe_weight6_q = w1g_Q;
				pipe_position6_q = p1g_Q[5:0];
			end

			2'd2: begin
				pipe_weight6_q = w2g_Q;
				pipe_position6_q = p2g_Q[5:0];
			end

			default: begin
				pipe_weight6_q = 8'd0;
				pipe_position6_q = 6'd0;
			end
		endcase
	end

	// lane7 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram7)
			2'd0: begin
				pipe_weight7_q = w0h_Q;
				pipe_position7_q = p0h_Q[5:0];
			end

			2'd1: begin
				pipe_weight7_q = w1h_Q;
				pipe_position7_q = p1h_Q[5:0];
			end

			2'd2: begin
				pipe_weight7_q = w2h_Q;
				pipe_position7_q = p2h_Q[5:0];
			end

			default: begin
				pipe_weight7_q = 8'd0;
				pipe_position7_q = 6'd0;
			end
		endcase
	end

	// lane8 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram8)
			2'd0: begin
				pipe_weight8_q = w0i_Q;
				pipe_position8_q = p0i_Q[5:0];
			end

			2'd1: begin
				pipe_weight8_q = w1i_Q;
				pipe_position8_q = p1i_Q[5:0];
			end

			2'd2: begin
				pipe_weight8_q = w2i_Q;
				pipe_position8_q = p2i_Q[5:0];
			end

			default: begin
				pipe_weight8_q = 8'd0;
				pipe_position8_q = 6'd0;
			end
		endcase
	end

	// lane9 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram9)
			2'd0: begin
				pipe_weight9_q = w0j_Q;
				pipe_position9_q = p0j_Q[5:0];
			end

			2'd1: begin
				pipe_weight9_q = w1j_Q;
				pipe_position9_q = p1j_Q[5:0];
			end

			2'd2: begin
				pipe_weight9_q = w2j_Q;
				pipe_position9_q = p2j_Q[5:0];
			end

			default: begin
				pipe_weight9_q = 8'd0;
				pipe_position9_q = 6'd0;
			end
		endcase
	end

	// lane10 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram10)
			2'd0: begin
				pipe_weight10_q = w0k_Q;
				pipe_position10_q = p0k_Q[5:0];
			end

			2'd1: begin
				pipe_weight10_q = w1k_Q;
				pipe_position10_q = p1k_Q[5:0];
			end

			2'd2: begin
				pipe_weight10_q = w2k_Q;
				pipe_position10_q = p2k_Q[5:0];
			end

			default: begin
				pipe_weight10_q = 8'd0;
				pipe_position10_q = 6'd0;
			end
		endcase
	end

	// lane11 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram11)
			2'd0: begin
				pipe_weight11_q = w0l_Q;
				pipe_position11_q = p0l_Q[5:0];
			end

			2'd1: begin
				pipe_weight11_q = w1l_Q;
				pipe_position11_q = p1l_Q[5:0];
			end

			2'd2: begin
				pipe_weight11_q = w2l_Q;
				pipe_position11_q = p2l_Q[5:0];
			end

			default: begin
				pipe_weight11_q = 8'd0;
				pipe_position11_q = 6'd0;
			end
		endcase
	end

	// lane12 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram12)
			2'd0: begin
				pipe_weight12_q = w0m_Q;
				pipe_position12_q = p0m_Q[5:0];
			end

			2'd1: begin
				pipe_weight12_q = w1m_Q;
				pipe_position12_q = p1m_Q[5:0];
			end

			2'd2: begin
				pipe_weight12_q = w2m_Q;
				pipe_position12_q = p2m_Q[5:0];
			end

			default: begin
				pipe_weight12_q = 8'd0;
				pipe_position12_q = 6'd0;
			end
		endcase
	end

	// lane13 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram13)
			2'd0: begin
				pipe_weight13_q = w0n_Q;
				pipe_position13_q = p0n_Q[5:0];
			end

			2'd1: begin
				pipe_weight13_q = w1n_Q;
				pipe_position13_q = p1n_Q[5:0];
			end

			2'd2: begin
				pipe_weight13_q = w2n_Q;
				pipe_position13_q = p2n_Q[5:0];
			end

			default: begin
				pipe_weight13_q = 8'd0;
				pipe_position13_q = 6'd0;
			end
		endcase
	end

	// lane14 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram14)
			2'd0: begin
				pipe_weight14_q = w0o_Q;
				pipe_position14_q = p0o_Q[5:0];
			end

			2'd1: begin
				pipe_weight14_q = w1o_Q;
				pipe_position14_q = p1o_Q[5:0];
			end

			2'd2: begin
				pipe_weight14_q = w2o_Q;
				pipe_position14_q = p2o_Q[5:0];
			end

			default: begin
				pipe_weight14_q = 8'd0;
				pipe_position14_q = 6'd0;
			end
		endcase
	end

	// lane15 W/P Q selector
	always @(*) begin
		case (pipe_wp_sram15)
			2'd0: begin
				pipe_weight15_q = w0p_Q;
				pipe_position15_q = p0p_Q[5:0];
			end

			2'd1: begin
				pipe_weight15_q = w1p_Q;
				pipe_position15_q = p1p_Q[5:0];
			end

			2'd2: begin
				pipe_weight15_q = w2p_Q;
				pipe_position15_q = p2p_Q[5:0];
			end

			default: begin
				pipe_weight15_q = 8'd0;
				pipe_position15_q = 6'd0;
			end
		endcase
	end

	// lane0 vector index
	always @(*) begin
		case (pipe_bank0)
			2'd0: pipe_vector_index0 = 8'd0   + {2'd0, pipe_position0_q};
			2'd1: pipe_vector_index0 = 8'd64  + {2'd0, pipe_position0_q};
			2'd2: pipe_vector_index0 = 8'd128 + {2'd0, pipe_position0_q};
			2'd3: pipe_vector_index0 = 8'd192 + {2'd0, pipe_position0_q};
			default: pipe_vector_index0 = 8'd0;
		endcase
	end

	// lane1 vector index
	always @(*) begin
		case (pipe_bank1)
			2'd0: pipe_vector_index1 = 8'd0   + {2'd0, pipe_position1_q};
			2'd1: pipe_vector_index1 = 8'd64  + {2'd0, pipe_position1_q};
			2'd2: pipe_vector_index1 = 8'd128 + {2'd0, pipe_position1_q};
			2'd3: pipe_vector_index1 = 8'd192 + {2'd0, pipe_position1_q};
			default: pipe_vector_index1 = 8'd0;
		endcase
	end

	// lane2 vector index
	always @(*) begin
		case (pipe_bank2)
			2'd0: pipe_vector_index2 = 8'd0   + {2'd0, pipe_position2_q};
			2'd1: pipe_vector_index2 = 8'd64  + {2'd0, pipe_position2_q};
			2'd2: pipe_vector_index2 = 8'd128 + {2'd0, pipe_position2_q};
			2'd3: pipe_vector_index2 = 8'd192 + {2'd0, pipe_position2_q};
			default: pipe_vector_index2 = 8'd0;
		endcase
	end

	// lane3 vector index
	always @(*) begin
		case (pipe_bank3)
			2'd0: pipe_vector_index3 = 8'd0   + {2'd0, pipe_position3_q};
			2'd1: pipe_vector_index3 = 8'd64  + {2'd0, pipe_position3_q};
			2'd2: pipe_vector_index3 = 8'd128 + {2'd0, pipe_position3_q};
			2'd3: pipe_vector_index3 = 8'd192 + {2'd0, pipe_position3_q};
			default: pipe_vector_index3 = 8'd0;
		endcase
	end

	// lane4 vector index
	always @(*) begin
		case (pipe_bank4)
			2'd0: pipe_vector_index4 = 8'd0   + {2'd0, pipe_position4_q};
			2'd1: pipe_vector_index4 = 8'd64  + {2'd0, pipe_position4_q};
			2'd2: pipe_vector_index4 = 8'd128 + {2'd0, pipe_position4_q};
			2'd3: pipe_vector_index4 = 8'd192 + {2'd0, pipe_position4_q};
			default: pipe_vector_index4 = 8'd0;
		endcase
	end

	// lane5 vector index
	always @(*) begin
		case (pipe_bank5)
			2'd0: pipe_vector_index5 = 8'd0   + {2'd0, pipe_position5_q};
			2'd1: pipe_vector_index5 = 8'd64  + {2'd0, pipe_position5_q};
			2'd2: pipe_vector_index5 = 8'd128 + {2'd0, pipe_position5_q};
			2'd3: pipe_vector_index5 = 8'd192 + {2'd0, pipe_position5_q};
			default: pipe_vector_index5 = 8'd0;
		endcase
	end

	// lane6 vector index
	always @(*) begin
		case (pipe_bank6)
			2'd0: pipe_vector_index6 = 8'd0   + {2'd0, pipe_position6_q};
			2'd1: pipe_vector_index6 = 8'd64  + {2'd0, pipe_position6_q};
			2'd2: pipe_vector_index6 = 8'd128 + {2'd0, pipe_position6_q};
			2'd3: pipe_vector_index6 = 8'd192 + {2'd0, pipe_position6_q};
			default: pipe_vector_index6 = 8'd0;
		endcase
	end

	// lane7 vector index
	always @(*) begin
		case (pipe_bank7)
			2'd0: pipe_vector_index7 = 8'd0   + {2'd0, pipe_position7_q};
			2'd1: pipe_vector_index7 = 8'd64  + {2'd0, pipe_position7_q};
			2'd2: pipe_vector_index7 = 8'd128 + {2'd0, pipe_position7_q};
			2'd3: pipe_vector_index7 = 8'd192 + {2'd0, pipe_position7_q};
			default: pipe_vector_index7 = 8'd0;
		endcase
	end

	// lane8 vector index
	always @(*) begin
		case (pipe_bank8)
			2'd0: pipe_vector_index8 = 8'd0   + {2'd0, pipe_position8_q};
			2'd1: pipe_vector_index8 = 8'd64  + {2'd0, pipe_position8_q};
			2'd2: pipe_vector_index8 = 8'd128 + {2'd0, pipe_position8_q};
			2'd3: pipe_vector_index8 = 8'd192 + {2'd0, pipe_position8_q};
			default: pipe_vector_index8 = 8'd0;
		endcase
	end

	// lane9 vector index
	always @(*) begin
		case (pipe_bank9)
			2'd0: pipe_vector_index9 = 8'd0   + {2'd0, pipe_position9_q};
			2'd1: pipe_vector_index9 = 8'd64  + {2'd0, pipe_position9_q};
			2'd2: pipe_vector_index9 = 8'd128 + {2'd0, pipe_position9_q};
			2'd3: pipe_vector_index9 = 8'd192 + {2'd0, pipe_position9_q};
			default: pipe_vector_index9 = 8'd0;
		endcase
	end

	// lane10 vector index
	always @(*) begin
		case (pipe_bank10)
			2'd0: pipe_vector_index10 = 8'd0   + {2'd0, pipe_position10_q};
			2'd1: pipe_vector_index10 = 8'd64  + {2'd0, pipe_position10_q};
			2'd2: pipe_vector_index10 = 8'd128 + {2'd0, pipe_position10_q};
			2'd3: pipe_vector_index10 = 8'd192 + {2'd0, pipe_position10_q};
			default: pipe_vector_index10 = 8'd0;
		endcase
	end

	// lane11 vector index
	always @(*) begin
		case (pipe_bank11)
			2'd0: pipe_vector_index11 = 8'd0   + {2'd0, pipe_position11_q};
			2'd1: pipe_vector_index11 = 8'd64  + {2'd0, pipe_position11_q};
			2'd2: pipe_vector_index11 = 8'd128 + {2'd0, pipe_position11_q};
			2'd3: pipe_vector_index11 = 8'd192 + {2'd0, pipe_position11_q};
			default: pipe_vector_index11 = 8'd0;
		endcase
	end

	// lane12 vector index
	always @(*) begin
		case (pipe_bank12)
			2'd0: pipe_vector_index12 = 8'd0   + {2'd0, pipe_position12_q};
			2'd1: pipe_vector_index12 = 8'd64  + {2'd0, pipe_position12_q};
			2'd2: pipe_vector_index12 = 8'd128 + {2'd0, pipe_position12_q};
			2'd3: pipe_vector_index12 = 8'd192 + {2'd0, pipe_position12_q};
			default: pipe_vector_index12 = 8'd0;
		endcase
	end

	// lane13 vector index
	always @(*) begin
		case (pipe_bank13)
			2'd0: pipe_vector_index13 = 8'd0   + {2'd0, pipe_position13_q};
			2'd1: pipe_vector_index13 = 8'd64  + {2'd0, pipe_position13_q};
			2'd2: pipe_vector_index13 = 8'd128 + {2'd0, pipe_position13_q};
			2'd3: pipe_vector_index13 = 8'd192 + {2'd0, pipe_position13_q};
			default: pipe_vector_index13 = 8'd0;
		endcase
	end

	// lane14 vector index
	always @(*) begin
		case (pipe_bank14)
			2'd0: pipe_vector_index14 = 8'd0   + {2'd0, pipe_position14_q};
			2'd1: pipe_vector_index14 = 8'd64  + {2'd0, pipe_position14_q};
			2'd2: pipe_vector_index14 = 8'd128 + {2'd0, pipe_position14_q};
			2'd3: pipe_vector_index14 = 8'd192 + {2'd0, pipe_position14_q};
			default: pipe_vector_index14 = 8'd0;
		endcase
	end

	// lane15 vector index
	always @(*) begin
		case (pipe_bank15)
			2'd0: pipe_vector_index15 = 8'd0   + {2'd0, pipe_position15_q};
			2'd1: pipe_vector_index15 = 8'd64  + {2'd0, pipe_position15_q};
			2'd2: pipe_vector_index15 = 8'd128 + {2'd0, pipe_position15_q};
			2'd3: pipe_vector_index15 = 8'd192 + {2'd0, pipe_position15_q};
			default: pipe_vector_index15 = 8'd0;
		endcase
	end

	wire signed [15:0] pipe_product0;
	wire signed [15:0] pipe_product1;
	wire signed [15:0] pipe_product2;
	wire signed [15:0] pipe_product3;
	wire signed [15:0] pipe_product4;
	wire signed [15:0] pipe_product5;
	wire signed [15:0] pipe_product6;
	wire signed [15:0] pipe_product7;
	wire signed [15:0] pipe_product8;
	wire signed [15:0] pipe_product9;
	wire signed [15:0] pipe_product10;
	wire signed [15:0] pipe_product11;
	wire signed [15:0] pipe_product12;
	wire signed [15:0] pipe_product13;
	wire signed [15:0] pipe_product14;
	wire signed [15:0] pipe_product15;

	wire signed [21:0] pipe_product0_ext;
	wire signed [21:0] pipe_product1_ext;
	wire signed [21:0] pipe_product2_ext;
	wire signed [21:0] pipe_product3_ext;
	wire signed [21:0] pipe_product4_ext;
	wire signed [21:0] pipe_product5_ext;
	wire signed [21:0] pipe_product6_ext;
	wire signed [21:0] pipe_product7_ext;
	wire signed [21:0] pipe_product8_ext;
	wire signed [21:0] pipe_product9_ext;
	wire signed [21:0] pipe_product10_ext;
	wire signed [21:0] pipe_product11_ext;
	wire signed [21:0] pipe_product12_ext;
	wire signed [21:0] pipe_product13_ext;
	wire signed [21:0] pipe_product14_ext;
	wire signed [21:0] pipe_product15_ext;

	wire signed [21:0] pipe_all_sum;

	assign pipe_product0 = $signed(pipe_weight0_r) * $signed(x_Q);
	assign pipe_product1 = $signed(pipe_weight1_r) * $signed(xb_Q);
	assign pipe_product2 = $signed(pipe_weight2_r) * $signed(xc_Q);
	assign pipe_product3 = $signed(pipe_weight3_r) * $signed(xd_Q);
	assign pipe_product4 = $signed(pipe_weight4_r) * $signed(xe_Q);
	assign pipe_product5 = $signed(pipe_weight5_r) * $signed(xf_Q);
	assign pipe_product6 = $signed(pipe_weight6_r) * $signed(xg_Q);
	assign pipe_product7 = $signed(pipe_weight7_r) * $signed(xh_Q);
	assign pipe_product8 = $signed(pipe_weight8_r) * $signed(xi_Q);
	assign pipe_product9 = $signed(pipe_weight9_r) * $signed(xj_Q);
	assign pipe_product10 = $signed(pipe_weight10_r) * $signed(xk_Q);
	assign pipe_product11 = $signed(pipe_weight11_r) * $signed(xl_Q);
	assign pipe_product12 = $signed(pipe_weight12_r) * $signed(xm_Q);
	assign pipe_product13 = $signed(pipe_weight13_r) * $signed(xn_Q);
	assign pipe_product14 = $signed(pipe_weight14_r) * $signed(xo_Q);
	assign pipe_product15 = $signed(pipe_weight15_r) * $signed(xp_Q);

	assign pipe_product0_ext = {{6{pipe_product0[15]}}, pipe_product0};
	assign pipe_product1_ext = {{6{pipe_product1[15]}}, pipe_product1};
	assign pipe_product2_ext = {{6{pipe_product2[15]}}, pipe_product2};
	assign pipe_product3_ext = {{6{pipe_product3[15]}}, pipe_product3};
	assign pipe_product4_ext = {{6{pipe_product4[15]}}, pipe_product4};
	assign pipe_product5_ext = {{6{pipe_product5[15]}}, pipe_product5};
	assign pipe_product6_ext = {{6{pipe_product6[15]}}, pipe_product6};
	assign pipe_product7_ext = {{6{pipe_product7[15]}}, pipe_product7};
	assign pipe_product8_ext = {{6{pipe_product8[15]}}, pipe_product8};
	assign pipe_product9_ext = {{6{pipe_product9[15]}}, pipe_product9};
	assign pipe_product10_ext = {{6{pipe_product10[15]}}, pipe_product10};
	assign pipe_product11_ext = {{6{pipe_product11[15]}}, pipe_product11};
	assign pipe_product12_ext = {{6{pipe_product12[15]}}, pipe_product12};
	assign pipe_product13_ext = {{6{pipe_product13[15]}}, pipe_product13};
	assign pipe_product14_ext = {{6{pipe_product14[15]}}, pipe_product14};
	assign pipe_product15_ext = {{6{pipe_product15[15]}}, pipe_product15};

	assign pipe_all_sum = pipe_product0_ext + pipe_product1_ext + pipe_product2_ext + pipe_product3_ext + pipe_product4_ext + pipe_product5_ext + pipe_product6_ext + pipe_product7_ext + pipe_product8_ext + pipe_product9_ext + pipe_product10_ext + pipe_product11_ext + pipe_product12_ext + pipe_product13_ext + pipe_product14_ext + pipe_product15_ext;

	// SRAM connecting
	always @(*) begin

		w0_CEN = 1'b1; w0_WEN = 1'b1; w0_A = 12'd0; w0_D = 8'd0;
		w1_CEN = 1'b1; w1_WEN = 1'b1; w1_A = 12'd0; w1_D = 8'd0;
		w2_CEN = 1'b1; w2_WEN = 1'b1; w2_A = 12'd0; w2_D = 8'd0;

		w0b_CEN = 1'b1; w0b_WEN = 1'b1; w0b_A = 12'd0; w0b_D = 8'd0;
		w1b_CEN = 1'b1; w1b_WEN = 1'b1; w1b_A = 12'd0; w1b_D = 8'd0;
		w2b_CEN = 1'b1; w2b_WEN = 1'b1; w2b_A = 12'd0; w2b_D = 8'd0;

		w0c_CEN = 1'b1; w0c_WEN = 1'b1; w0c_A = 12'd0; w0c_D = 8'd0;
		w1c_CEN = 1'b1; w1c_WEN = 1'b1; w1c_A = 12'd0; w1c_D = 8'd0;
		w2c_CEN = 1'b1; w2c_WEN = 1'b1; w2c_A = 12'd0; w2c_D = 8'd0;

		w0d_CEN = 1'b1; w0d_WEN = 1'b1; w0d_A = 12'd0; w0d_D = 8'd0;
		w1d_CEN = 1'b1; w1d_WEN = 1'b1; w1d_A = 12'd0; w1d_D = 8'd0;
		w2d_CEN = 1'b1; w2d_WEN = 1'b1; w2d_A = 12'd0; w2d_D = 8'd0;

		w0e_CEN = 1'b1; w0e_WEN = 1'b1; w0e_A = 12'd0; w0e_D = 8'd0;
		w1e_CEN = 1'b1; w1e_WEN = 1'b1; w1e_A = 12'd0; w1e_D = 8'd0;
		w2e_CEN = 1'b1; w2e_WEN = 1'b1; w2e_A = 12'd0; w2e_D = 8'd0;

		w0f_CEN = 1'b1; w0f_WEN = 1'b1; w0f_A = 12'd0; w0f_D = 8'd0;
		w1f_CEN = 1'b1; w1f_WEN = 1'b1; w1f_A = 12'd0; w1f_D = 8'd0;
		w2f_CEN = 1'b1; w2f_WEN = 1'b1; w2f_A = 12'd0; w2f_D = 8'd0;

		w0g_CEN = 1'b1; w0g_WEN = 1'b1; w0g_A = 12'd0; w0g_D = 8'd0;
		w1g_CEN = 1'b1; w1g_WEN = 1'b1; w1g_A = 12'd0; w1g_D = 8'd0;
		w2g_CEN = 1'b1; w2g_WEN = 1'b1; w2g_A = 12'd0; w2g_D = 8'd0;

		w0h_CEN = 1'b1; w0h_WEN = 1'b1; w0h_A = 12'd0; w0h_D = 8'd0;
		w1h_CEN = 1'b1; w1h_WEN = 1'b1; w1h_A = 12'd0; w1h_D = 8'd0;
		w2h_CEN = 1'b1; w2h_WEN = 1'b1; w2h_A = 12'd0; w2h_D = 8'd0;

		w0i_CEN = 1'b1; w0i_WEN = 1'b1; w0i_A = 12'd0; w0i_D = 8'd0;
		w1i_CEN = 1'b1; w1i_WEN = 1'b1; w1i_A = 12'd0; w1i_D = 8'd0;
		w2i_CEN = 1'b1; w2i_WEN = 1'b1; w2i_A = 12'd0; w2i_D = 8'd0;

		w0j_CEN = 1'b1; w0j_WEN = 1'b1; w0j_A = 12'd0; w0j_D = 8'd0;
		w1j_CEN = 1'b1; w1j_WEN = 1'b1; w1j_A = 12'd0; w1j_D = 8'd0;
		w2j_CEN = 1'b1; w2j_WEN = 1'b1; w2j_A = 12'd0; w2j_D = 8'd0;

		w0k_CEN = 1'b1; w0k_WEN = 1'b1; w0k_A = 12'd0; w0k_D = 8'd0;
		w1k_CEN = 1'b1; w1k_WEN = 1'b1; w1k_A = 12'd0; w1k_D = 8'd0;
		w2k_CEN = 1'b1; w2k_WEN = 1'b1; w2k_A = 12'd0; w2k_D = 8'd0;

		w0l_CEN = 1'b1; w0l_WEN = 1'b1; w0l_A = 12'd0; w0l_D = 8'd0;
		w1l_CEN = 1'b1; w1l_WEN = 1'b1; w1l_A = 12'd0; w1l_D = 8'd0;
		w2l_CEN = 1'b1; w2l_WEN = 1'b1; w2l_A = 12'd0; w2l_D = 8'd0;

		w0m_CEN = 1'b1; w0m_WEN = 1'b1; w0m_A = 12'd0; w0m_D = 8'd0;
		w1m_CEN = 1'b1; w1m_WEN = 1'b1; w1m_A = 12'd0; w1m_D = 8'd0;
		w2m_CEN = 1'b1; w2m_WEN = 1'b1; w2m_A = 12'd0; w2m_D = 8'd0;

		w0n_CEN = 1'b1; w0n_WEN = 1'b1; w0n_A = 12'd0; w0n_D = 8'd0;
		w1n_CEN = 1'b1; w1n_WEN = 1'b1; w1n_A = 12'd0; w1n_D = 8'd0;
		w2n_CEN = 1'b1; w2n_WEN = 1'b1; w2n_A = 12'd0; w2n_D = 8'd0;

		w0o_CEN = 1'b1; w0o_WEN = 1'b1; w0o_A = 12'd0; w0o_D = 8'd0;
		w1o_CEN = 1'b1; w1o_WEN = 1'b1; w1o_A = 12'd0; w1o_D = 8'd0;
		w2o_CEN = 1'b1; w2o_WEN = 1'b1; w2o_A = 12'd0; w2o_D = 8'd0;

		w0p_CEN = 1'b1; w0p_WEN = 1'b1; w0p_A = 12'd0; w0p_D = 8'd0;
		w1p_CEN = 1'b1; w1p_WEN = 1'b1; w1p_A = 12'd0; w1p_D = 8'd0;
		w2p_CEN = 1'b1; w2p_WEN = 1'b1; w2p_A = 12'd0; w2p_D = 8'd0;

		p0_CEN = 1'b1; p0_WEN = 1'b1; p0_A = 12'd0; p0_D = 8'd0;
		p1_CEN = 1'b1; p1_WEN = 1'b1; p1_A = 12'd0; p1_D = 8'd0;
		p2_CEN = 1'b1; p2_WEN = 1'b1; p2_A = 12'd0; p2_D = 8'd0;

		p0b_CEN = 1'b1; p0b_WEN = 1'b1; p0b_A = 12'd0; p0b_D = 8'd0;
		p1b_CEN = 1'b1; p1b_WEN = 1'b1; p1b_A = 12'd0; p1b_D = 8'd0;
		p2b_CEN = 1'b1; p2b_WEN = 1'b1; p2b_A = 12'd0; p2b_D = 8'd0;

		p0c_CEN = 1'b1; p0c_WEN = 1'b1; p0c_A = 12'd0; p0c_D = 8'd0;
		p1c_CEN = 1'b1; p1c_WEN = 1'b1; p1c_A = 12'd0; p1c_D = 8'd0;
		p2c_CEN = 1'b1; p2c_WEN = 1'b1; p2c_A = 12'd0; p2c_D = 8'd0;

		p0d_CEN = 1'b1; p0d_WEN = 1'b1; p0d_A = 12'd0; p0d_D = 8'd0;
		p1d_CEN = 1'b1; p1d_WEN = 1'b1; p1d_A = 12'd0; p1d_D = 8'd0;
		p2d_CEN = 1'b1; p2d_WEN = 1'b1; p2d_A = 12'd0; p2d_D = 8'd0;

		p0e_CEN = 1'b1; p0e_WEN = 1'b1; p0e_A = 12'd0; p0e_D = 8'd0;
		p1e_CEN = 1'b1; p1e_WEN = 1'b1; p1e_A = 12'd0; p1e_D = 8'd0;
		p2e_CEN = 1'b1; p2e_WEN = 1'b1; p2e_A = 12'd0; p2e_D = 8'd0;

		p0f_CEN = 1'b1; p0f_WEN = 1'b1; p0f_A = 12'd0; p0f_D = 8'd0;
		p1f_CEN = 1'b1; p1f_WEN = 1'b1; p1f_A = 12'd0; p1f_D = 8'd0;
		p2f_CEN = 1'b1; p2f_WEN = 1'b1; p2f_A = 12'd0; p2f_D = 8'd0;

		p0g_CEN = 1'b1; p0g_WEN = 1'b1; p0g_A = 12'd0; p0g_D = 8'd0;
		p1g_CEN = 1'b1; p1g_WEN = 1'b1; p1g_A = 12'd0; p1g_D = 8'd0;
		p2g_CEN = 1'b1; p2g_WEN = 1'b1; p2g_A = 12'd0; p2g_D = 8'd0;

		p0h_CEN = 1'b1; p0h_WEN = 1'b1; p0h_A = 12'd0; p0h_D = 8'd0;
		p1h_CEN = 1'b1; p1h_WEN = 1'b1; p1h_A = 12'd0; p1h_D = 8'd0;
		p2h_CEN = 1'b1; p2h_WEN = 1'b1; p2h_A = 12'd0; p2h_D = 8'd0;

		p0i_CEN = 1'b1; p0i_WEN = 1'b1; p0i_A = 12'd0; p0i_D = 8'd0;
		p1i_CEN = 1'b1; p1i_WEN = 1'b1; p1i_A = 12'd0; p1i_D = 8'd0;
		p2i_CEN = 1'b1; p2i_WEN = 1'b1; p2i_A = 12'd0; p2i_D = 8'd0;

		p0j_CEN = 1'b1; p0j_WEN = 1'b1; p0j_A = 12'd0; p0j_D = 8'd0;
		p1j_CEN = 1'b1; p1j_WEN = 1'b1; p1j_A = 12'd0; p1j_D = 8'd0;
		p2j_CEN = 1'b1; p2j_WEN = 1'b1; p2j_A = 12'd0; p2j_D = 8'd0;

		p0k_CEN = 1'b1; p0k_WEN = 1'b1; p0k_A = 12'd0; p0k_D = 8'd0;
		p1k_CEN = 1'b1; p1k_WEN = 1'b1; p1k_A = 12'd0; p1k_D = 8'd0;
		p2k_CEN = 1'b1; p2k_WEN = 1'b1; p2k_A = 12'd0; p2k_D = 8'd0;

		p0l_CEN = 1'b1; p0l_WEN = 1'b1; p0l_A = 12'd0; p0l_D = 8'd0;
		p1l_CEN = 1'b1; p1l_WEN = 1'b1; p1l_A = 12'd0; p1l_D = 8'd0;
		p2l_CEN = 1'b1; p2l_WEN = 1'b1; p2l_A = 12'd0; p2l_D = 8'd0;

		p0m_CEN = 1'b1; p0m_WEN = 1'b1; p0m_A = 12'd0; p0m_D = 8'd0;
		p1m_CEN = 1'b1; p1m_WEN = 1'b1; p1m_A = 12'd0; p1m_D = 8'd0;
		p2m_CEN = 1'b1; p2m_WEN = 1'b1; p2m_A = 12'd0; p2m_D = 8'd0;

		p0n_CEN = 1'b1; p0n_WEN = 1'b1; p0n_A = 12'd0; p0n_D = 8'd0;
		p1n_CEN = 1'b1; p1n_WEN = 1'b1; p1n_A = 12'd0; p1n_D = 8'd0;
		p2n_CEN = 1'b1; p2n_WEN = 1'b1; p2n_A = 12'd0; p2n_D = 8'd0;

		p0o_CEN = 1'b1; p0o_WEN = 1'b1; p0o_A = 12'd0; p0o_D = 8'd0;
		p1o_CEN = 1'b1; p1o_WEN = 1'b1; p1o_A = 12'd0; p1o_D = 8'd0;
		p2o_CEN = 1'b1; p2o_WEN = 1'b1; p2o_A = 12'd0; p2o_D = 8'd0;

		p0p_CEN = 1'b1; p0p_WEN = 1'b1; p0p_A = 12'd0; p0p_D = 8'd0;
		p1p_CEN = 1'b1; p1p_WEN = 1'b1; p1p_A = 12'd0; p1p_D = 8'd0;
		p2p_CEN = 1'b1; p2p_WEN = 1'b1; p2p_A = 12'd0; p2p_D = 8'd0;

		b_CEN  = 1'b1; b_WEN  = 1'b1; b_A  = 8'd0;  b_D  = 8'd0;

		x_CEN = 1'b1; x_WEN = 1'b1; x_A = 12'd0; x_D = 8'd0;
		xb_CEN = 1'b1; xb_WEN = 1'b1; xb_A = 12'd0; xb_D = 8'd0;
		xc_CEN = 1'b1; xc_WEN = 1'b1; xc_A = 12'd0; xc_D = 8'd0;
		xd_CEN = 1'b1; xd_WEN = 1'b1; xd_A = 12'd0; xd_D = 8'd0;
		xe_CEN = 1'b1; xe_WEN = 1'b1; xe_A = 12'd0; xe_D = 8'd0;
		xf_CEN = 1'b1; xf_WEN = 1'b1; xf_A = 12'd0; xf_D = 8'd0;
		xg_CEN = 1'b1; xg_WEN = 1'b1; xg_A = 12'd0; xg_D = 8'd0;
		xh_CEN = 1'b1; xh_WEN = 1'b1; xh_A = 12'd0; xh_D = 8'd0;
		xi_CEN = 1'b1; xi_WEN = 1'b1; xi_A = 12'd0; xi_D = 8'd0;
		xj_CEN = 1'b1; xj_WEN = 1'b1; xj_A = 12'd0; xj_D = 8'd0;
		xk_CEN = 1'b1; xk_WEN = 1'b1; xk_A = 12'd0; xk_D = 8'd0;
		xl_CEN = 1'b1; xl_WEN = 1'b1; xl_A = 12'd0; xl_D = 8'd0;
		xm_CEN = 1'b1; xm_WEN = 1'b1; xm_A = 12'd0; xm_D = 8'd0;
		xn_CEN = 1'b1; xn_WEN = 1'b1; xn_A = 12'd0; xn_D = 8'd0;
		xo_CEN = 1'b1; xo_WEN = 1'b1; xo_A = 12'd0; xo_D = 8'd0;
		xp_CEN = 1'b1; xp_WEN = 1'b1; xp_A = 12'd0; xp_D = 8'd0;

		case (state)

			LOAD_WEIGHT: begin
				if (w_input_valid) begin
					if (load_count < 14'd4096) begin
						w0_CEN = 1'b0;
						w0_WEN = 1'b0;
						w0_A = load_count[11:0];
						w0_D = raw_input;

						w0b_CEN = 1'b0;
						w0b_WEN = 1'b0;
						w0b_A = load_count[11:0];
						w0b_D = raw_input;

						w0c_CEN = 1'b0;
						w0c_WEN = 1'b0;
						w0c_A = load_count[11:0];
						w0c_D = raw_input;

						w0d_CEN = 1'b0;
						w0d_WEN = 1'b0;
						w0d_A = load_count[11:0];
						w0d_D = raw_input;

						w0e_CEN = 1'b0;
						w0e_WEN = 1'b0;
						w0e_A = load_count[11:0];
						w0e_D = raw_input;

						w0f_CEN = 1'b0;
						w0f_WEN = 1'b0;
						w0f_A = load_count[11:0];
						w0f_D = raw_input;

						w0g_CEN = 1'b0;
						w0g_WEN = 1'b0;
						w0g_A = load_count[11:0];
						w0g_D = raw_input;

						w0h_CEN = 1'b0;
						w0h_WEN = 1'b0;
						w0h_A = load_count[11:0];
						w0h_D = raw_input;

						w0i_CEN = 1'b0;
						w0i_WEN = 1'b0;
						w0i_A = load_count[11:0];
						w0i_D = raw_input;

						w0j_CEN = 1'b0;
						w0j_WEN = 1'b0;
						w0j_A = load_count[11:0];
						w0j_D = raw_input;

						w0k_CEN = 1'b0;
						w0k_WEN = 1'b0;
						w0k_A = load_count[11:0];
						w0k_D = raw_input;

						w0l_CEN = 1'b0;
						w0l_WEN = 1'b0;
						w0l_A = load_count[11:0];
						w0l_D = raw_input;

						w0m_CEN = 1'b0;
						w0m_WEN = 1'b0;
						w0m_A = load_count[11:0];
						w0m_D = raw_input;

						w0n_CEN = 1'b0;
						w0n_WEN = 1'b0;
						w0n_A = load_count[11:0];
						w0n_D = raw_input;

						w0o_CEN = 1'b0;
						w0o_WEN = 1'b0;
						w0o_A = load_count[11:0];
						w0o_D = raw_input;

						w0p_CEN = 1'b0;
						w0p_WEN = 1'b0;
						w0p_A = load_count[11:0];
						w0p_D = raw_input;

					end
					else if (load_count < 14'd8192) begin
						w1_CEN = 1'b0;
						w1_WEN = 1'b0;
						w1_A = load_count[11:0];
						w1_D = raw_input;

						w1b_CEN = 1'b0;
						w1b_WEN = 1'b0;
						w1b_A = load_count[11:0];
						w1b_D = raw_input;

						w1c_CEN = 1'b0;
						w1c_WEN = 1'b0;
						w1c_A = load_count[11:0];
						w1c_D = raw_input;

						w1d_CEN = 1'b0;
						w1d_WEN = 1'b0;
						w1d_A = load_count[11:0];
						w1d_D = raw_input;

						w1e_CEN = 1'b0;
						w1e_WEN = 1'b0;
						w1e_A = load_count[11:0];
						w1e_D = raw_input;

						w1f_CEN = 1'b0;
						w1f_WEN = 1'b0;
						w1f_A = load_count[11:0];
						w1f_D = raw_input;

						w1g_CEN = 1'b0;
						w1g_WEN = 1'b0;
						w1g_A = load_count[11:0];
						w1g_D = raw_input;

						w1h_CEN = 1'b0;
						w1h_WEN = 1'b0;
						w1h_A = load_count[11:0];
						w1h_D = raw_input;

						w1i_CEN = 1'b0;
						w1i_WEN = 1'b0;
						w1i_A = load_count[11:0];
						w1i_D = raw_input;

						w1j_CEN = 1'b0;
						w1j_WEN = 1'b0;
						w1j_A = load_count[11:0];
						w1j_D = raw_input;

						w1k_CEN = 1'b0;
						w1k_WEN = 1'b0;
						w1k_A = load_count[11:0];
						w1k_D = raw_input;

						w1l_CEN = 1'b0;
						w1l_WEN = 1'b0;
						w1l_A = load_count[11:0];
						w1l_D = raw_input;

						w1m_CEN = 1'b0;
						w1m_WEN = 1'b0;
						w1m_A = load_count[11:0];
						w1m_D = raw_input;

						w1n_CEN = 1'b0;
						w1n_WEN = 1'b0;
						w1n_A = load_count[11:0];
						w1n_D = raw_input;

						w1o_CEN = 1'b0;
						w1o_WEN = 1'b0;
						w1o_A = load_count[11:0];
						w1o_D = raw_input;

						w1p_CEN = 1'b0;
						w1p_WEN = 1'b0;
						w1p_A = load_count[11:0];
						w1p_D = raw_input;

					end
					else begin
						w2_CEN = 1'b0;
						w2_WEN = 1'b0;
						w2_A = load_count[11:0];
						w2_D = raw_input;

						w2b_CEN = 1'b0;
						w2b_WEN = 1'b0;
						w2b_A = load_count[11:0];
						w2b_D = raw_input;

						w2c_CEN = 1'b0;
						w2c_WEN = 1'b0;
						w2c_A = load_count[11:0];
						w2c_D = raw_input;

						w2d_CEN = 1'b0;
						w2d_WEN = 1'b0;
						w2d_A = load_count[11:0];
						w2d_D = raw_input;

						w2e_CEN = 1'b0;
						w2e_WEN = 1'b0;
						w2e_A = load_count[11:0];
						w2e_D = raw_input;

						w2f_CEN = 1'b0;
						w2f_WEN = 1'b0;
						w2f_A = load_count[11:0];
						w2f_D = raw_input;

						w2g_CEN = 1'b0;
						w2g_WEN = 1'b0;
						w2g_A = load_count[11:0];
						w2g_D = raw_input;

						w2h_CEN = 1'b0;
						w2h_WEN = 1'b0;
						w2h_A = load_count[11:0];
						w2h_D = raw_input;

						w2i_CEN = 1'b0;
						w2i_WEN = 1'b0;
						w2i_A = load_count[11:0];
						w2i_D = raw_input;

						w2j_CEN = 1'b0;
						w2j_WEN = 1'b0;
						w2j_A = load_count[11:0];
						w2j_D = raw_input;

						w2k_CEN = 1'b0;
						w2k_WEN = 1'b0;
						w2k_A = load_count[11:0];
						w2k_D = raw_input;

						w2l_CEN = 1'b0;
						w2l_WEN = 1'b0;
						w2l_A = load_count[11:0];
						w2l_D = raw_input;

						w2m_CEN = 1'b0;
						w2m_WEN = 1'b0;
						w2m_A = load_count[11:0];
						w2m_D = raw_input;

						w2n_CEN = 1'b0;
						w2n_WEN = 1'b0;
						w2n_A = load_count[11:0];
						w2n_D = raw_input;

						w2o_CEN = 1'b0;
						w2o_WEN = 1'b0;
						w2o_A = load_count[11:0];
						w2o_D = raw_input;

						w2p_CEN = 1'b0;
						w2p_WEN = 1'b0;
						w2p_A = load_count[11:0];
						w2p_D = raw_input;

					end
				end
			end

			LOAD_POSITION: begin
				if (w_input_valid) begin
					if (load_count < 14'd4096) begin
						p0_CEN = 1'b0;
						p0_WEN = 1'b0;
						p0_A = load_count[11:0];
						p0_D = raw_input;

						p0b_CEN = 1'b0;
						p0b_WEN = 1'b0;
						p0b_A = load_count[11:0];
						p0b_D = raw_input;

						p0c_CEN = 1'b0;
						p0c_WEN = 1'b0;
						p0c_A = load_count[11:0];
						p0c_D = raw_input;

						p0d_CEN = 1'b0;
						p0d_WEN = 1'b0;
						p0d_A = load_count[11:0];
						p0d_D = raw_input;

						p0e_CEN = 1'b0;
						p0e_WEN = 1'b0;
						p0e_A = load_count[11:0];
						p0e_D = raw_input;

						p0f_CEN = 1'b0;
						p0f_WEN = 1'b0;
						p0f_A = load_count[11:0];
						p0f_D = raw_input;

						p0g_CEN = 1'b0;
						p0g_WEN = 1'b0;
						p0g_A = load_count[11:0];
						p0g_D = raw_input;

						p0h_CEN = 1'b0;
						p0h_WEN = 1'b0;
						p0h_A = load_count[11:0];
						p0h_D = raw_input;

						p0i_CEN = 1'b0;
						p0i_WEN = 1'b0;
						p0i_A = load_count[11:0];
						p0i_D = raw_input;

						p0j_CEN = 1'b0;
						p0j_WEN = 1'b0;
						p0j_A = load_count[11:0];
						p0j_D = raw_input;

						p0k_CEN = 1'b0;
						p0k_WEN = 1'b0;
						p0k_A = load_count[11:0];
						p0k_D = raw_input;

						p0l_CEN = 1'b0;
						p0l_WEN = 1'b0;
						p0l_A = load_count[11:0];
						p0l_D = raw_input;

						p0m_CEN = 1'b0;
						p0m_WEN = 1'b0;
						p0m_A = load_count[11:0];
						p0m_D = raw_input;

						p0n_CEN = 1'b0;
						p0n_WEN = 1'b0;
						p0n_A = load_count[11:0];
						p0n_D = raw_input;

						p0o_CEN = 1'b0;
						p0o_WEN = 1'b0;
						p0o_A = load_count[11:0];
						p0o_D = raw_input;

						p0p_CEN = 1'b0;
						p0p_WEN = 1'b0;
						p0p_A = load_count[11:0];
						p0p_D = raw_input;

					end
					else if (load_count < 14'd8192) begin
						p1_CEN = 1'b0;
						p1_WEN = 1'b0;
						p1_A = load_count[11:0];
						p1_D = raw_input;

						p1b_CEN = 1'b0;
						p1b_WEN = 1'b0;
						p1b_A = load_count[11:0];
						p1b_D = raw_input;

						p1c_CEN = 1'b0;
						p1c_WEN = 1'b0;
						p1c_A = load_count[11:0];
						p1c_D = raw_input;

						p1d_CEN = 1'b0;
						p1d_WEN = 1'b0;
						p1d_A = load_count[11:0];
						p1d_D = raw_input;

						p1e_CEN = 1'b0;
						p1e_WEN = 1'b0;
						p1e_A = load_count[11:0];
						p1e_D = raw_input;

						p1f_CEN = 1'b0;
						p1f_WEN = 1'b0;
						p1f_A = load_count[11:0];
						p1f_D = raw_input;

						p1g_CEN = 1'b0;
						p1g_WEN = 1'b0;
						p1g_A = load_count[11:0];
						p1g_D = raw_input;

						p1h_CEN = 1'b0;
						p1h_WEN = 1'b0;
						p1h_A = load_count[11:0];
						p1h_D = raw_input;

						p1i_CEN = 1'b0;
						p1i_WEN = 1'b0;
						p1i_A = load_count[11:0];
						p1i_D = raw_input;

						p1j_CEN = 1'b0;
						p1j_WEN = 1'b0;
						p1j_A = load_count[11:0];
						p1j_D = raw_input;

						p1k_CEN = 1'b0;
						p1k_WEN = 1'b0;
						p1k_A = load_count[11:0];
						p1k_D = raw_input;

						p1l_CEN = 1'b0;
						p1l_WEN = 1'b0;
						p1l_A = load_count[11:0];
						p1l_D = raw_input;

						p1m_CEN = 1'b0;
						p1m_WEN = 1'b0;
						p1m_A = load_count[11:0];
						p1m_D = raw_input;

						p1n_CEN = 1'b0;
						p1n_WEN = 1'b0;
						p1n_A = load_count[11:0];
						p1n_D = raw_input;

						p1o_CEN = 1'b0;
						p1o_WEN = 1'b0;
						p1o_A = load_count[11:0];
						p1o_D = raw_input;

						p1p_CEN = 1'b0;
						p1p_WEN = 1'b0;
						p1p_A = load_count[11:0];
						p1p_D = raw_input;

					end
					else begin
						p2_CEN = 1'b0;
						p2_WEN = 1'b0;
						p2_A = load_count[11:0];
						p2_D = raw_input;

						p2b_CEN = 1'b0;
						p2b_WEN = 1'b0;
						p2b_A = load_count[11:0];
						p2b_D = raw_input;

						p2c_CEN = 1'b0;
						p2c_WEN = 1'b0;
						p2c_A = load_count[11:0];
						p2c_D = raw_input;

						p2d_CEN = 1'b0;
						p2d_WEN = 1'b0;
						p2d_A = load_count[11:0];
						p2d_D = raw_input;

						p2e_CEN = 1'b0;
						p2e_WEN = 1'b0;
						p2e_A = load_count[11:0];
						p2e_D = raw_input;

						p2f_CEN = 1'b0;
						p2f_WEN = 1'b0;
						p2f_A = load_count[11:0];
						p2f_D = raw_input;

						p2g_CEN = 1'b0;
						p2g_WEN = 1'b0;
						p2g_A = load_count[11:0];
						p2g_D = raw_input;

						p2h_CEN = 1'b0;
						p2h_WEN = 1'b0;
						p2h_A = load_count[11:0];
						p2h_D = raw_input;

						p2i_CEN = 1'b0;
						p2i_WEN = 1'b0;
						p2i_A = load_count[11:0];
						p2i_D = raw_input;

						p2j_CEN = 1'b0;
						p2j_WEN = 1'b0;
						p2j_A = load_count[11:0];
						p2j_D = raw_input;

						p2k_CEN = 1'b0;
						p2k_WEN = 1'b0;
						p2k_A = load_count[11:0];
						p2k_D = raw_input;

						p2l_CEN = 1'b0;
						p2l_WEN = 1'b0;
						p2l_A = load_count[11:0];
						p2l_D = raw_input;

						p2m_CEN = 1'b0;
						p2m_WEN = 1'b0;
						p2m_A = load_count[11:0];
						p2m_D = raw_input;

						p2n_CEN = 1'b0;
						p2n_WEN = 1'b0;
						p2n_A = load_count[11:0];
						p2n_D = raw_input;

						p2o_CEN = 1'b0;
						p2o_WEN = 1'b0;
						p2o_A = load_count[11:0];
						p2o_D = raw_input;

						p2p_CEN = 1'b0;
						p2p_WEN = 1'b0;
						p2p_A = load_count[11:0];
						p2p_D = raw_input;

					end
				end
			end

			LOAD_BIAS: begin
				if (w_input_valid) begin
					b_CEN = 1'b0;
					b_WEN = 1'b0;
					b_A = load_count[7:0];
					b_D = raw_input;
				end
			end

			LOAD_VECTOR: begin
				if (raw_data_valid) begin
					x_CEN = 1'b0;
					x_WEN = 1'b0;
					x_A = load_count[11:0];
					x_D = raw_input;

					xb_CEN = 1'b0;
					xb_WEN = 1'b0;
					xb_A = load_count[11:0];
					xb_D = raw_input;

					xc_CEN = 1'b0;
					xc_WEN = 1'b0;
					xc_A = load_count[11:0];
					xc_D = raw_input;

					xd_CEN = 1'b0;
					xd_WEN = 1'b0;
					xd_A = load_count[11:0];
					xd_D = raw_input;

					xe_CEN = 1'b0;
					xe_WEN = 1'b0;
					xe_A = load_count[11:0];
					xe_D = raw_input;

					xf_CEN = 1'b0;
					xf_WEN = 1'b0;
					xf_A = load_count[11:0];
					xf_D = raw_input;

					xg_CEN = 1'b0;
					xg_WEN = 1'b0;
					xg_A = load_count[11:0];
					xg_D = raw_input;

					xh_CEN = 1'b0;
					xh_WEN = 1'b0;
					xh_A = load_count[11:0];
					xh_D = raw_input;

					xi_CEN = 1'b0;
					xi_WEN = 1'b0;
					xi_A = load_count[11:0];
					xi_D = raw_input;

					xj_CEN = 1'b0;
					xj_WEN = 1'b0;
					xj_A = load_count[11:0];
					xj_D = raw_input;

					xk_CEN = 1'b0;
					xk_WEN = 1'b0;
					xk_A = load_count[11:0];
					xk_D = raw_input;

					xl_CEN = 1'b0;
					xl_WEN = 1'b0;
					xl_A = load_count[11:0];
					xl_D = raw_input;

					xm_CEN = 1'b0;
					xm_WEN = 1'b0;
					xm_A = load_count[11:0];
					xm_D = raw_input;

					xn_CEN = 1'b0;
					xn_WEN = 1'b0;
					xn_A = load_count[11:0];
					xn_D = raw_input;

					xo_CEN = 1'b0;
					xo_WEN = 1'b0;
					xo_A = load_count[11:0];
					xo_D = raw_input;

					xp_CEN = 1'b0;
					xp_WEN = 1'b0;
					xp_A = load_count[11:0];
					xp_D = raw_input;

				end
			end

			READ_BIAS: begin
				b_CEN = 1'b0;
				b_WEN = 1'b1;
				b_A = row_count[7:0];
			end

			COMPUTE_PIPE: begin
				// Lane0: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram0 == 2'd0) begin
						w0_CEN = 1'b0;
						w0_WEN = 1'b1;
						w0_A = pipe_issue_index0[11:0];

						p0_CEN = 1'b0;
						p0_WEN = 1'b1;
						p0_A = pipe_issue_index0[11:0];

					end
					else if (pipe_issue_sram0 == 2'd1) begin
						w1_CEN = 1'b0;
						w1_WEN = 1'b1;
						w1_A = pipe_issue_index0[11:0];

						p1_CEN = 1'b0;
						p1_WEN = 1'b1;
						p1_A = pipe_issue_index0[11:0];

					end
					else begin
						w2_CEN = 1'b0;
						w2_WEN = 1'b1;
						w2_A = pipe_issue_index0[11:0];

						p2_CEN = 1'b0;
						p2_WEN = 1'b1;
						p2_A = pipe_issue_index0[11:0];

					end
				end

				// Lane1: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram1 == 2'd0) begin
						w0b_CEN = 1'b0;
						w0b_WEN = 1'b1;
						w0b_A = pipe_issue_index1[11:0];

						p0b_CEN = 1'b0;
						p0b_WEN = 1'b1;
						p0b_A = pipe_issue_index1[11:0];

					end
					else if (pipe_issue_sram1 == 2'd1) begin
						w1b_CEN = 1'b0;
						w1b_WEN = 1'b1;
						w1b_A = pipe_issue_index1[11:0];

						p1b_CEN = 1'b0;
						p1b_WEN = 1'b1;
						p1b_A = pipe_issue_index1[11:0];

					end
					else begin
						w2b_CEN = 1'b0;
						w2b_WEN = 1'b1;
						w2b_A = pipe_issue_index1[11:0];

						p2b_CEN = 1'b0;
						p2b_WEN = 1'b1;
						p2b_A = pipe_issue_index1[11:0];

					end
				end

				// Lane2: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram2 == 2'd0) begin
						w0c_CEN = 1'b0;
						w0c_WEN = 1'b1;
						w0c_A = pipe_issue_index2[11:0];

						p0c_CEN = 1'b0;
						p0c_WEN = 1'b1;
						p0c_A = pipe_issue_index2[11:0];

					end
					else if (pipe_issue_sram2 == 2'd1) begin
						w1c_CEN = 1'b0;
						w1c_WEN = 1'b1;
						w1c_A = pipe_issue_index2[11:0];

						p1c_CEN = 1'b0;
						p1c_WEN = 1'b1;
						p1c_A = pipe_issue_index2[11:0];

					end
					else begin
						w2c_CEN = 1'b0;
						w2c_WEN = 1'b1;
						w2c_A = pipe_issue_index2[11:0];

						p2c_CEN = 1'b0;
						p2c_WEN = 1'b1;
						p2c_A = pipe_issue_index2[11:0];

					end
				end

				// Lane3: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram3 == 2'd0) begin
						w0d_CEN = 1'b0;
						w0d_WEN = 1'b1;
						w0d_A = pipe_issue_index3[11:0];

						p0d_CEN = 1'b0;
						p0d_WEN = 1'b1;
						p0d_A = pipe_issue_index3[11:0];

					end
					else if (pipe_issue_sram3 == 2'd1) begin
						w1d_CEN = 1'b0;
						w1d_WEN = 1'b1;
						w1d_A = pipe_issue_index3[11:0];

						p1d_CEN = 1'b0;
						p1d_WEN = 1'b1;
						p1d_A = pipe_issue_index3[11:0];

					end
					else begin
						w2d_CEN = 1'b0;
						w2d_WEN = 1'b1;
						w2d_A = pipe_issue_index3[11:0];

						p2d_CEN = 1'b0;
						p2d_WEN = 1'b1;
						p2d_A = pipe_issue_index3[11:0];

					end
				end

				// Lane4: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram4 == 2'd0) begin
						w0e_CEN = 1'b0;
						w0e_WEN = 1'b1;
						w0e_A = pipe_issue_index4[11:0];

						p0e_CEN = 1'b0;
						p0e_WEN = 1'b1;
						p0e_A = pipe_issue_index4[11:0];

					end
					else if (pipe_issue_sram4 == 2'd1) begin
						w1e_CEN = 1'b0;
						w1e_WEN = 1'b1;
						w1e_A = pipe_issue_index4[11:0];

						p1e_CEN = 1'b0;
						p1e_WEN = 1'b1;
						p1e_A = pipe_issue_index4[11:0];

					end
					else begin
						w2e_CEN = 1'b0;
						w2e_WEN = 1'b1;
						w2e_A = pipe_issue_index4[11:0];

						p2e_CEN = 1'b0;
						p2e_WEN = 1'b1;
						p2e_A = pipe_issue_index4[11:0];

					end
				end

				// Lane5: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram5 == 2'd0) begin
						w0f_CEN = 1'b0;
						w0f_WEN = 1'b1;
						w0f_A = pipe_issue_index5[11:0];

						p0f_CEN = 1'b0;
						p0f_WEN = 1'b1;
						p0f_A = pipe_issue_index5[11:0];

					end
					else if (pipe_issue_sram5 == 2'd1) begin
						w1f_CEN = 1'b0;
						w1f_WEN = 1'b1;
						w1f_A = pipe_issue_index5[11:0];

						p1f_CEN = 1'b0;
						p1f_WEN = 1'b1;
						p1f_A = pipe_issue_index5[11:0];

					end
					else begin
						w2f_CEN = 1'b0;
						w2f_WEN = 1'b1;
						w2f_A = pipe_issue_index5[11:0];

						p2f_CEN = 1'b0;
						p2f_WEN = 1'b1;
						p2f_A = pipe_issue_index5[11:0];

					end
				end

				// Lane6: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram6 == 2'd0) begin
						w0g_CEN = 1'b0;
						w0g_WEN = 1'b1;
						w0g_A = pipe_issue_index6[11:0];

						p0g_CEN = 1'b0;
						p0g_WEN = 1'b1;
						p0g_A = pipe_issue_index6[11:0];

					end
					else if (pipe_issue_sram6 == 2'd1) begin
						w1g_CEN = 1'b0;
						w1g_WEN = 1'b1;
						w1g_A = pipe_issue_index6[11:0];

						p1g_CEN = 1'b0;
						p1g_WEN = 1'b1;
						p1g_A = pipe_issue_index6[11:0];

					end
					else begin
						w2g_CEN = 1'b0;
						w2g_WEN = 1'b1;
						w2g_A = pipe_issue_index6[11:0];

						p2g_CEN = 1'b0;
						p2g_WEN = 1'b1;
						p2g_A = pipe_issue_index6[11:0];

					end
				end

				// Lane7: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram7 == 2'd0) begin
						w0h_CEN = 1'b0;
						w0h_WEN = 1'b1;
						w0h_A = pipe_issue_index7[11:0];

						p0h_CEN = 1'b0;
						p0h_WEN = 1'b1;
						p0h_A = pipe_issue_index7[11:0];

					end
					else if (pipe_issue_sram7 == 2'd1) begin
						w1h_CEN = 1'b0;
						w1h_WEN = 1'b1;
						w1h_A = pipe_issue_index7[11:0];

						p1h_CEN = 1'b0;
						p1h_WEN = 1'b1;
						p1h_A = pipe_issue_index7[11:0];

					end
					else begin
						w2h_CEN = 1'b0;
						w2h_WEN = 1'b1;
						w2h_A = pipe_issue_index7[11:0];

						p2h_CEN = 1'b0;
						p2h_WEN = 1'b1;
						p2h_A = pipe_issue_index7[11:0];

					end
				end

				// Lane8: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram8 == 2'd0) begin
						w0i_CEN = 1'b0;
						w0i_WEN = 1'b1;
						w0i_A = pipe_issue_index8[11:0];

						p0i_CEN = 1'b0;
						p0i_WEN = 1'b1;
						p0i_A = pipe_issue_index8[11:0];

					end
					else if (pipe_issue_sram8 == 2'd1) begin
						w1i_CEN = 1'b0;
						w1i_WEN = 1'b1;
						w1i_A = pipe_issue_index8[11:0];

						p1i_CEN = 1'b0;
						p1i_WEN = 1'b1;
						p1i_A = pipe_issue_index8[11:0];

					end
					else begin
						w2i_CEN = 1'b0;
						w2i_WEN = 1'b1;
						w2i_A = pipe_issue_index8[11:0];

						p2i_CEN = 1'b0;
						p2i_WEN = 1'b1;
						p2i_A = pipe_issue_index8[11:0];

					end
				end

				// Lane9: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram9 == 2'd0) begin
						w0j_CEN = 1'b0;
						w0j_WEN = 1'b1;
						w0j_A = pipe_issue_index9[11:0];

						p0j_CEN = 1'b0;
						p0j_WEN = 1'b1;
						p0j_A = pipe_issue_index9[11:0];

					end
					else if (pipe_issue_sram9 == 2'd1) begin
						w1j_CEN = 1'b0;
						w1j_WEN = 1'b1;
						w1j_A = pipe_issue_index9[11:0];

						p1j_CEN = 1'b0;
						p1j_WEN = 1'b1;
						p1j_A = pipe_issue_index9[11:0];

					end
					else begin
						w2j_CEN = 1'b0;
						w2j_WEN = 1'b1;
						w2j_A = pipe_issue_index9[11:0];

						p2j_CEN = 1'b0;
						p2j_WEN = 1'b1;
						p2j_A = pipe_issue_index9[11:0];

					end
				end

				// Lane10: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram10 == 2'd0) begin
						w0k_CEN = 1'b0;
						w0k_WEN = 1'b1;
						w0k_A = pipe_issue_index10[11:0];

						p0k_CEN = 1'b0;
						p0k_WEN = 1'b1;
						p0k_A = pipe_issue_index10[11:0];

					end
					else if (pipe_issue_sram10 == 2'd1) begin
						w1k_CEN = 1'b0;
						w1k_WEN = 1'b1;
						w1k_A = pipe_issue_index10[11:0];

						p1k_CEN = 1'b0;
						p1k_WEN = 1'b1;
						p1k_A = pipe_issue_index10[11:0];

					end
					else begin
						w2k_CEN = 1'b0;
						w2k_WEN = 1'b1;
						w2k_A = pipe_issue_index10[11:0];

						p2k_CEN = 1'b0;
						p2k_WEN = 1'b1;
						p2k_A = pipe_issue_index10[11:0];

					end
				end

				// Lane11: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram11 == 2'd0) begin
						w0l_CEN = 1'b0;
						w0l_WEN = 1'b1;
						w0l_A = pipe_issue_index11[11:0];

						p0l_CEN = 1'b0;
						p0l_WEN = 1'b1;
						p0l_A = pipe_issue_index11[11:0];

					end
					else if (pipe_issue_sram11 == 2'd1) begin
						w1l_CEN = 1'b0;
						w1l_WEN = 1'b1;
						w1l_A = pipe_issue_index11[11:0];

						p1l_CEN = 1'b0;
						p1l_WEN = 1'b1;
						p1l_A = pipe_issue_index11[11:0];

					end
					else begin
						w2l_CEN = 1'b0;
						w2l_WEN = 1'b1;
						w2l_A = pipe_issue_index11[11:0];

						p2l_CEN = 1'b0;
						p2l_WEN = 1'b1;
						p2l_A = pipe_issue_index11[11:0];

					end
				end

				// Lane12: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram12 == 2'd0) begin
						w0m_CEN = 1'b0;
						w0m_WEN = 1'b1;
						w0m_A = pipe_issue_index12[11:0];

						p0m_CEN = 1'b0;
						p0m_WEN = 1'b1;
						p0m_A = pipe_issue_index12[11:0];

					end
					else if (pipe_issue_sram12 == 2'd1) begin
						w1m_CEN = 1'b0;
						w1m_WEN = 1'b1;
						w1m_A = pipe_issue_index12[11:0];

						p1m_CEN = 1'b0;
						p1m_WEN = 1'b1;
						p1m_A = pipe_issue_index12[11:0];

					end
					else begin
						w2m_CEN = 1'b0;
						w2m_WEN = 1'b1;
						w2m_A = pipe_issue_index12[11:0];

						p2m_CEN = 1'b0;
						p2m_WEN = 1'b1;
						p2m_A = pipe_issue_index12[11:0];

					end
				end

				// Lane13: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram13 == 2'd0) begin
						w0n_CEN = 1'b0;
						w0n_WEN = 1'b1;
						w0n_A = pipe_issue_index13[11:0];

						p0n_CEN = 1'b0;
						p0n_WEN = 1'b1;
						p0n_A = pipe_issue_index13[11:0];

					end
					else if (pipe_issue_sram13 == 2'd1) begin
						w1n_CEN = 1'b0;
						w1n_WEN = 1'b1;
						w1n_A = pipe_issue_index13[11:0];

						p1n_CEN = 1'b0;
						p1n_WEN = 1'b1;
						p1n_A = pipe_issue_index13[11:0];

					end
					else begin
						w2n_CEN = 1'b0;
						w2n_WEN = 1'b1;
						w2n_A = pipe_issue_index13[11:0];

						p2n_CEN = 1'b0;
						p2n_WEN = 1'b1;
						p2n_A = pipe_issue_index13[11:0];

					end
				end

				// Lane14: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram14 == 2'd0) begin
						w0o_CEN = 1'b0;
						w0o_WEN = 1'b1;
						w0o_A = pipe_issue_index14[11:0];

						p0o_CEN = 1'b0;
						p0o_WEN = 1'b1;
						p0o_A = pipe_issue_index14[11:0];

					end
					else if (pipe_issue_sram14 == 2'd1) begin
						w1o_CEN = 1'b0;
						w1o_WEN = 1'b1;
						w1o_A = pipe_issue_index14[11:0];

						p1o_CEN = 1'b0;
						p1o_WEN = 1'b1;
						p1o_A = pipe_issue_index14[11:0];

					end
					else begin
						w2o_CEN = 1'b0;
						w2o_WEN = 1'b1;
						w2o_A = pipe_issue_index14[11:0];

						p2o_CEN = 1'b0;
						p2o_WEN = 1'b1;
						p2o_A = pipe_issue_index14[11:0];

					end
				end

				// Lane15: issue W/P read
				if (pipe_issue < 6'd48) begin
					if (pipe_issue_sram15 == 2'd0) begin
						w0p_CEN = 1'b0;
						w0p_WEN = 1'b1;
						w0p_A = pipe_issue_index15[11:0];

						p0p_CEN = 1'b0;
						p0p_WEN = 1'b1;
						p0p_A = pipe_issue_index15[11:0];

					end
					else if (pipe_issue_sram15 == 2'd1) begin
						w1p_CEN = 1'b0;
						w1p_WEN = 1'b1;
						w1p_A = pipe_issue_index15[11:0];

						p1p_CEN = 1'b0;
						p1p_WEN = 1'b1;
						p1p_A = pipe_issue_index15[11:0];

					end
					else begin
						w2p_CEN = 1'b0;
						w2p_WEN = 1'b1;
						w2p_A = pipe_issue_index15[11:0];

						p2p_CEN = 1'b0;
						p2p_WEN = 1'b1;
						p2p_A = pipe_issue_index15[11:0];

					end
				end

				// W/P Q valid, issue vector reads
				if (pipe_wp_valid) begin
					x_CEN = 1'b0;
					x_WEN = 1'b1;
					x_A = {vector_count, pipe_vector_index0};

					xb_CEN = 1'b0;
					xb_WEN = 1'b1;
					xb_A = {vector_count, pipe_vector_index1};

					xc_CEN = 1'b0;
					xc_WEN = 1'b1;
					xc_A = {vector_count, pipe_vector_index2};

					xd_CEN = 1'b0;
					xd_WEN = 1'b1;
					xd_A = {vector_count, pipe_vector_index3};

					xe_CEN = 1'b0;
					xe_WEN = 1'b1;
					xe_A = {vector_count, pipe_vector_index4};

					xf_CEN = 1'b0;
					xf_WEN = 1'b1;
					xf_A = {vector_count, pipe_vector_index5};

					xg_CEN = 1'b0;
					xg_WEN = 1'b1;
					xg_A = {vector_count, pipe_vector_index6};

					xh_CEN = 1'b0;
					xh_WEN = 1'b1;
					xh_A = {vector_count, pipe_vector_index7};

					xi_CEN = 1'b0;
					xi_WEN = 1'b1;
					xi_A = {vector_count, pipe_vector_index8};

					xj_CEN = 1'b0;
					xj_WEN = 1'b1;
					xj_A = {vector_count, pipe_vector_index9};

					xk_CEN = 1'b0;
					xk_WEN = 1'b1;
					xk_A = {vector_count, pipe_vector_index10};

					xl_CEN = 1'b0;
					xl_WEN = 1'b1;
					xl_A = {vector_count, pipe_vector_index11};

					xm_CEN = 1'b0;
					xm_WEN = 1'b1;
					xm_A = {vector_count, pipe_vector_index12};

					xn_CEN = 1'b0;
					xn_WEN = 1'b1;
					xn_A = {vector_count, pipe_vector_index13};

					xo_CEN = 1'b0;
					xo_WEN = 1'b1;
					xo_A = {vector_count, pipe_vector_index14};

					xp_CEN = 1'b0;
					xp_WEN = 1'b1;
					xp_A = {vector_count, pipe_vector_index15};

				end
			end

		endcase
	end

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			state <= IDLE0;

			o_result <= 22'd0;
			o_valid <= 1'b0;

			load_count <= 14'd0;
			row_count <= 9'd0;
			vector_count <= 4'd0;

			sum <= 22'd0;

			pipe_issue <= 6'd0;
			pipe_done <= 6'd0;
			pipe_wp_valid <= 1'b0;
			pipe_x_valid <= 1'b0;

			pipe_wp_sram0 <= 2'd0;
			pipe_wp_sram1 <= 2'd0;
			pipe_wp_sram2 <= 2'd0;
			pipe_wp_sram3 <= 2'd0;
			pipe_wp_sram4 <= 2'd0;
			pipe_wp_sram5 <= 2'd0;
			pipe_wp_sram6 <= 2'd0;
			pipe_wp_sram7 <= 2'd0;
			pipe_wp_sram8 <= 2'd0;
			pipe_wp_sram9 <= 2'd0;
			pipe_wp_sram10 <= 2'd0;
			pipe_wp_sram11 <= 2'd0;
			pipe_wp_sram12 <= 2'd0;
			pipe_wp_sram13 <= 2'd0;
			pipe_wp_sram14 <= 2'd0;
			pipe_wp_sram15 <= 2'd0;

			pipe_bank0 <= 2'd0;
			pipe_bank1 <= 2'd0;
			pipe_bank2 <= 2'd0;
			pipe_bank3 <= 2'd0;
			pipe_bank4 <= 2'd0;
			pipe_bank5 <= 2'd0;
			pipe_bank6 <= 2'd0;
			pipe_bank7 <= 2'd0;
			pipe_bank8 <= 2'd0;
			pipe_bank9 <= 2'd0;
			pipe_bank10 <= 2'd0;
			pipe_bank11 <= 2'd0;
			pipe_bank12 <= 2'd0;
			pipe_bank13 <= 2'd0;
			pipe_bank14 <= 2'd0;
			pipe_bank15 <= 2'd0;

			pipe_weight0_r <= 8'd0;
			pipe_weight1_r <= 8'd0;
			pipe_weight2_r <= 8'd0;
			pipe_weight3_r <= 8'd0;
			pipe_weight4_r <= 8'd0;
			pipe_weight5_r <= 8'd0;
			pipe_weight6_r <= 8'd0;
			pipe_weight7_r <= 8'd0;
			pipe_weight8_r <= 8'd0;
			pipe_weight9_r <= 8'd0;
			pipe_weight10_r <= 8'd0;
			pipe_weight11_r <= 8'd0;
			pipe_weight12_r <= 8'd0;
			pipe_weight13_r <= 8'd0;
			pipe_weight14_r <= 8'd0;
			pipe_weight15_r <= 8'd0;
		end

		else begin
			state <= nextstate;

			o_valid <= 1'b0;

			case (state)

				IDLE0: begin
					load_count <= 14'd0;
					row_count  <= 9'd0;
					vector_count <= 4'd0;
					sum <= 22'd0;
				end

				LOAD_WEIGHT: begin
					if (w_input_valid) begin
						if (load_count == 14'd12287)
							load_count <= 14'd0;
						else
							load_count <= load_count + 14'd1;
					end
				end

				LOAD_POSITION: begin
					if (w_input_valid) begin
						if (load_count == 14'd12287)
							load_count <= 14'd0;
						else
							load_count <= load_count + 14'd1;
					end
				end

				LOAD_BIAS: begin
					if (w_input_valid) begin
						if (load_count == 14'd255)
							load_count <= 14'd0;
						else
							load_count <= load_count + 14'd1;
					end
				end

				IDLE1: begin
					load_count <= 14'd0;
					row_count  <= 9'd0;
					vector_count <= 4'd0;
					sum <= 22'd0;
				end

				PRE_LOAD: begin
				end
				
				LOAD_VECTOR: begin
					if (raw_data_valid) begin
						if (load_count == 14'd4095)
							load_count <= 14'd0;
						else
							load_count <= load_count + 14'd1;
					end
				end

				WAIT_LOAD: begin
				end

				READ_BIAS: begin
				end

				WAIT_BIAS: begin
				end

				INIT_MULT: begin
					sum <= {{10{b_Q[7]}}, b_Q, 4'b0000}; //S0.7 -> S10.11

					pipe_issue <= 6'd0;
					pipe_done <= 6'd0;

					pipe_wp_valid <= 1'b0;
					pipe_x_valid <= 1'b0;

					pipe_wp_sram0 <= 2'd0;
					pipe_wp_sram1 <= 2'd0;
					pipe_wp_sram2 <= 2'd0;
					pipe_wp_sram3 <= 2'd0;
					pipe_wp_sram4 <= 2'd0;
					pipe_wp_sram5 <= 2'd0;
					pipe_wp_sram6 <= 2'd0;
					pipe_wp_sram7 <= 2'd0;
					pipe_wp_sram8 <= 2'd0;
					pipe_wp_sram9 <= 2'd0;
					pipe_wp_sram10 <= 2'd0;
					pipe_wp_sram11 <= 2'd0;
					pipe_wp_sram12 <= 2'd0;
					pipe_wp_sram13 <= 2'd0;
					pipe_wp_sram14 <= 2'd0;
					pipe_wp_sram15 <= 2'd0;

					pipe_bank0 <= 2'd0;
					pipe_bank1 <= 2'd0;
					pipe_bank2 <= 2'd0;
					pipe_bank3 <= 2'd0;
					pipe_bank4 <= 2'd0;
					pipe_bank5 <= 2'd0;
					pipe_bank6 <= 2'd0;
					pipe_bank7 <= 2'd0;
					pipe_bank8 <= 2'd0;
					pipe_bank9 <= 2'd0;
					pipe_bank10 <= 2'd0;
					pipe_bank11 <= 2'd0;
					pipe_bank12 <= 2'd0;
					pipe_bank13 <= 2'd0;
					pipe_bank14 <= 2'd0;
					pipe_bank15 <= 2'd0;

					pipe_weight0_r <= 8'd0;
					pipe_weight1_r <= 8'd0;
					pipe_weight2_r <= 8'd0;
					pipe_weight3_r <= 8'd0;
					pipe_weight4_r <= 8'd0;
					pipe_weight5_r <= 8'd0;
					pipe_weight6_r <= 8'd0;
					pipe_weight7_r <= 8'd0;
					pipe_weight8_r <= 8'd0;
					pipe_weight9_r <= 8'd0;
					pipe_weight10_r <= 8'd0;
					pipe_weight11_r <= 8'd0;
					pipe_weight12_r <= 8'd0;
					pipe_weight13_r <= 8'd0;
					pipe_weight14_r <= 8'd0;
					pipe_weight15_r <= 8'd0;
				end

				COMPUTE_PIPE: begin

					// X_Q valid, do 16 MACs
					if (pipe_x_valid) begin
						sum <= sum + pipe_all_sum;

						if (pipe_done <= 6'd32)
							pipe_done <= pipe_done + 6'd16;
					end

					if (pipe_wp_valid) begin
						pipe_weight0_r <= pipe_weight0_q;
						pipe_weight1_r <= pipe_weight1_q;
						pipe_weight2_r <= pipe_weight2_q;
						pipe_weight3_r <= pipe_weight3_q;
						pipe_weight4_r <= pipe_weight4_q;
						pipe_weight5_r <= pipe_weight5_q;
						pipe_weight6_r <= pipe_weight6_q;
						pipe_weight7_r <= pipe_weight7_q;
						pipe_weight8_r <= pipe_weight8_q;
						pipe_weight9_r <= pipe_weight9_q;
						pipe_weight10_r <= pipe_weight10_q;
						pipe_weight11_r <= pipe_weight11_q;
						pipe_weight12_r <= pipe_weight12_q;
						pipe_weight13_r <= pipe_weight13_q;
						pipe_weight14_r <= pipe_weight14_q;
						pipe_weight15_r <= pipe_weight15_q;
					end

					pipe_x_valid <= pipe_wp_valid;

					// Issue 16 W/P reads per cycle
					if (pipe_issue < 6'd48) begin
						pipe_wp_valid <= 1'b1;

						pipe_wp_sram0 <= pipe_issue_sram0;
						pipe_wp_sram1 <= pipe_issue_sram1;
						pipe_wp_sram2 <= pipe_issue_sram2;
						pipe_wp_sram3 <= pipe_issue_sram3;
						pipe_wp_sram4 <= pipe_issue_sram4;
						pipe_wp_sram5 <= pipe_issue_sram5;
						pipe_wp_sram6 <= pipe_issue_sram6;
						pipe_wp_sram7 <= pipe_issue_sram7;
						pipe_wp_sram8 <= pipe_issue_sram8;
						pipe_wp_sram9 <= pipe_issue_sram9;
						pipe_wp_sram10 <= pipe_issue_sram10;
						pipe_wp_sram11 <= pipe_issue_sram11;
						pipe_wp_sram12 <= pipe_issue_sram12;
						pipe_wp_sram13 <= pipe_issue_sram13;
						pipe_wp_sram14 <= pipe_issue_sram14;
						pipe_wp_sram15 <= pipe_issue_sram15;

						pipe_bank0 <= pipe_issue[1:0];
						pipe_bank1 <= pipe_issue_bank1;
						pipe_bank2 <= pipe_issue_bank2;
						pipe_bank3 <= pipe_issue_bank3;
						pipe_bank4 <= pipe_issue_bank4;
						pipe_bank5 <= pipe_issue_bank5;
						pipe_bank6 <= pipe_issue_bank6;
						pipe_bank7 <= pipe_issue_bank7;
						pipe_bank8 <= pipe_issue_bank8;
						pipe_bank9 <= pipe_issue_bank9;
						pipe_bank10 <= pipe_issue_bank10;
						pipe_bank11 <= pipe_issue_bank11;
						pipe_bank12 <= pipe_issue_bank12;
						pipe_bank13 <= pipe_issue_bank13;
						pipe_bank14 <= pipe_issue_bank14;
						pipe_bank15 <= pipe_issue_bank15;

						pipe_issue <= pipe_issue + 6'd16;
					end
					else begin
						pipe_wp_valid <= 1'b0;
					end

				end

				OUTPUT: begin
					o_result <= sum;
					o_valid  <= 1'b1;

					if (row_count == 9'd255) begin
						row_count <= 9'd0;

						if (vector_count == 4'd15)
							vector_count <= 4'd0;
						else
							vector_count <= vector_count + 4'd1;
					end
					else begin
						row_count <= row_count + 9'd1;
					end
				end

			endcase
		end
	end

	always @(*) begin
		nextstate = state;

		case (state)

			IDLE0: begin
				if (start_init)
					nextstate = LOAD_WEIGHT;
				else
					nextstate = IDLE0;
			end

			LOAD_WEIGHT: begin
				if (w_input_valid && load_count == 14'd12287)
					nextstate = LOAD_POSITION;
				else
					nextstate = LOAD_WEIGHT;
			end

			LOAD_POSITION: begin
				if (w_input_valid && load_count == 14'd12287)
					nextstate = LOAD_BIAS;
				else
					nextstate = LOAD_POSITION;
			end

			LOAD_BIAS: begin
				if (w_input_valid && load_count == 14'd255)
					nextstate = IDLE1;
				else
					nextstate = LOAD_BIAS;
			end

			IDLE1: begin
				nextstate = PRE_LOAD;
			end

			PRE_LOAD: begin
				nextstate = LOAD_VECTOR;
			end

			LOAD_VECTOR: begin
				if (raw_data_valid && load_count == 14'd4095)
					nextstate = WAIT_LOAD;
				else
					nextstate = LOAD_VECTOR;
			end

			WAIT_LOAD: begin
				nextstate = READ_BIAS;
			end

			READ_BIAS: begin
				nextstate = WAIT_BIAS;
			end

			WAIT_BIAS: begin
				nextstate = INIT_MULT;
			end

			INIT_MULT: begin
				nextstate = COMPUTE_PIPE;
			end

			COMPUTE_PIPE: begin
				if (pipe_x_valid && pipe_done == 6'd32)
					nextstate = OUTPUT;
				else
					nextstate = COMPUTE_PIPE;
			end

			OUTPUT: begin
				if (row_count == 9'd255 && vector_count == 4'd15)
					nextstate = IDLE1;
				else
					nextstate = READ_BIAS;
			end

			default: begin
				nextstate = IDLE0;
			end

		endcase
	end

	// Combinational Request 
	always @(*) begin
		raw_data_request = 1'b0;
		ld_w_request = 1'b0;

		case (state)

			LOAD_WEIGHT: begin
				ld_w_request = 1'b1;
			end

			LOAD_POSITION: begin
				ld_w_request = 1'b1;
			end

			LOAD_BIAS: begin
				ld_w_request = 1'b1;
			end

			PRE_LOAD: begin
				raw_data_request = 1'b1;
			end

			LOAD_VECTOR: begin
				if (!(raw_data_valid && load_count == 14'd4095))
					raw_data_request = 1'b1;
			end

		endcase
	end

endmodule
