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

    // Counters
	reg [13:0] load_count;      // weight/position: 0~12287, vector: 0~4095
    reg [8:0]  row_count;       // 0~255
	reg [3:0]  token_count;     // 0~15, used inside reuse compute
	reg [11:0] out_count;       // 0~4095, output buffer address

	// States
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
    localparam INIT_ROW      = 5'd10;

	localparam LOAD_WP_BUF   = 5'd11;
	localparam INIT_TOKEN    = 5'd12;
	localparam COMPUTE_PIPE  = 5'd13;
	localparam STORE_RESULT  = 5'd14;
    localparam OUTPUT_BUF    = 5'd15;

	reg [4:0] state;
	reg [4:0] nextstate;


	// weight SRAM (*3 4096*8)
	reg  [11:0] w0_A, w1_A, w2_A;
	reg  [7:0]  w0_D, w1_D, w2_D;
	wire [7:0]  w0_Q, w1_Q, w2_Q;
	reg  w0_CEN, w1_CEN, w2_CEN;
	reg  w0_WEN, w1_WEN, w2_WEN;

	// position SRAM (*3 4096*8)
	reg  [11:0] p0_A, p1_A, p2_A;
	reg  [7:0]  p0_D, p1_D, p2_D;
	wire [7:0]  p0_Q, p1_Q, p2_Q;
	reg  p0_CEN, p1_CEN, p2_CEN;
	reg  p0_WEN, p1_WEN, p2_WEN;

	// bias SRAM (*1 256*8)
	reg  [7:0] b_A;
	reg  [7:0] b_D;
	wire [7:0] b_Q;
	reg  b_CEN;
	reg  b_WEN;

	// vector SRAM lane0~3 (*4 4096*8)
	reg  [11:0] x_A, xb_A, xc_A, xd_A;
	reg  [7:0]  x_D, xb_D, xc_D, xd_D;
	wire [7:0]  x_Q, xb_Q, xc_Q, xd_Q;
	reg  x_CEN, xb_CEN, xc_CEN, xd_CEN;
	reg  x_WEN, xb_WEN, xc_WEN, xd_WEN;


	// SRAM instances
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

	sram_256x8  B_  (.A(b_A),  .D(b_D),  .Q(b_Q),  
					.CLK(clk), .CEN(b_CEN),  .WEN(b_WEN));

	sram_4096x8 X_  (.A(x_A),  .D(x_D),  .Q(x_Q),  
					.CLK(clk), .CEN(x_CEN),  .WEN(x_WEN));
	sram_4096x8 X_B (.A(xb_A), .D(xb_D), .Q(xb_Q),  
					.CLK(clk), .CEN(xb_CEN), .WEN(xb_WEN));
	sram_4096x8 X_C (.A(xc_A), .D(xc_D), .Q(xc_Q),  
					.CLK(clk), .CEN(xc_CEN), .WEN(xc_WEN));
	sram_4096x8 X_D (.A(xd_A), .D(xd_D), .Q(xd_Q),  
					.CLK(clk), .CEN(xd_CEN), .WEN(xd_WEN));


	// Row-level W/P buffer and output reorder buffer
	reg signed [7:0]  w_buf [0:47];
	reg        [5:0]  p_buf [0:47];
	reg signed [21:0] out_buf [0:4095];

	// Computing
	reg signed [21:0] sum;
	reg signed [21:0] bias_ext;

	// Load W/P buffer pipeline
	reg [5:0] wp_issue;      // 0~48
	reg [5:0] wp_capture;    // captured buffer index
	reg       wp_valid;
	reg [1:0] wp_sram_r;

	wire [13:0] wp_base_index;
	wire [13:0] wp_issue_index;
	wire [1:0]  wp_issue_sram;

	assign wp_base_index = ({5'd0, row_count} << 5) +
	                       ({5'd0, row_count} << 4);
	assign wp_issue_index = wp_base_index + {8'd0, wp_issue};
	assign wp_issue_sram  = wp_issue_index[13:12];

	reg signed [7:0] wp_weight_q;
	reg [5:0]        wp_position_q;

	always @(*) begin
		case (wp_sram_r)
			2'd0: begin
				wp_weight_q = w0_Q;
				wp_position_q = p0_Q[5:0];
			end
			2'd1: begin
				wp_weight_q = w1_Q;
				wp_position_q = p1_Q[5:0];
			end
			2'd2: begin
				wp_weight_q = w2_Q;
				wp_position_q = p2_Q[5:0];
			end
			default: begin
				wp_weight_q = 8'd0;
				wp_position_q = 6'd0;
			end
		endcase
	end


	// 4-MAC compute pipeline from W/P buffer
	reg [5:0] pipe_issue;   // 0~48, step by 4
	reg [5:0] pipe_done;    // 0~48, step by 4
	reg pipe_x_valid;

	wire [5:0] pipe_issue_plus1;
	wire [5:0] pipe_issue_plus2;
	wire [5:0] pipe_issue_plus3;

	assign pipe_issue_plus1 = pipe_issue + 6'd1;
	assign pipe_issue_plus2 = pipe_issue + 6'd2;
	assign pipe_issue_plus3 = pipe_issue + 6'd3;

	reg signed [7:0] pipe_weight0_r;
	reg signed [7:0] pipe_weight1_r;
	reg signed [7:0] pipe_weight2_r;
	reg signed [7:0] pipe_weight3_r;

	reg [7:0] pipe_vector_index0;
	reg [7:0] pipe_vector_index1;
	reg [7:0] pipe_vector_index2;
	reg [7:0] pipe_vector_index3;

	// vector index from buffer index: 0->bank0, 1->bank1, 2->bank2, 3->bank3
	always @(*) begin
		case (pipe_issue[1:0])
			2'd0: pipe_vector_index0 = 8'd0   + {2'd0, p_buf[pipe_issue]};
			2'd1: pipe_vector_index0 = 8'd64  + {2'd0, p_buf[pipe_issue]};
			2'd2: pipe_vector_index0 = 8'd128 + {2'd0, p_buf[pipe_issue]};
			2'd3: pipe_vector_index0 = 8'd192 + {2'd0, p_buf[pipe_issue]};
			default: pipe_vector_index0 = 8'd0;
		endcase
	end

	always @(*) begin
		case (pipe_issue_plus1[1:0])
			2'd0: pipe_vector_index1 = 8'd0   + {2'd0, p_buf[pipe_issue_plus1]};
			2'd1: pipe_vector_index1 = 8'd64  + {2'd0, p_buf[pipe_issue_plus1]};
			2'd2: pipe_vector_index1 = 8'd128 + {2'd0, p_buf[pipe_issue_plus1]};
			2'd3: pipe_vector_index1 = 8'd192 + {2'd0, p_buf[pipe_issue_plus1]};
			default: pipe_vector_index1 = 8'd0;
		endcase
	end

	always @(*) begin
		case (pipe_issue_plus2[1:0])
			2'd0: pipe_vector_index2 = 8'd0   + {2'd0, p_buf[pipe_issue_plus2]};
			2'd1: pipe_vector_index2 = 8'd64  + {2'd0, p_buf[pipe_issue_plus2]};
			2'd2: pipe_vector_index2 = 8'd128 + {2'd0, p_buf[pipe_issue_plus2]};
			2'd3: pipe_vector_index2 = 8'd192 + {2'd0, p_buf[pipe_issue_plus2]};
			default: pipe_vector_index2 = 8'd0;
		endcase
	end

	always @(*) begin
		case (pipe_issue_plus3[1:0])
			2'd0: pipe_vector_index3 = 8'd0   + {2'd0, p_buf[pipe_issue_plus3]};
			2'd1: pipe_vector_index3 = 8'd64  + {2'd0, p_buf[pipe_issue_plus3]};
			2'd2: pipe_vector_index3 = 8'd128 + {2'd0, p_buf[pipe_issue_plus3]};
			2'd3: pipe_vector_index3 = 8'd192 + {2'd0, p_buf[pipe_issue_plus3]};
			default: pipe_vector_index3 = 8'd0;
		endcase
	end

	wire signed [15:0] pipe_product0;
	wire signed [15:0] pipe_product1;
	wire signed [15:0] pipe_product2;
	wire signed [15:0] pipe_product3;

	wire signed [21:0] pipe_product0_ext;
	wire signed [21:0] pipe_product1_ext;
	wire signed [21:0] pipe_product2_ext;
	wire signed [21:0] pipe_product3_ext;

	wire signed [21:0] pipe_pair_sum01;
	wire signed [21:0] pipe_pair_sum23;
	wire signed [21:0] pipe_four_sum;

	assign pipe_product0 = $signed(pipe_weight0_r) * $signed(x_Q);
	assign pipe_product1 = $signed(pipe_weight1_r) * $signed(xb_Q);
	assign pipe_product2 = $signed(pipe_weight2_r) * $signed(xc_Q);
	assign pipe_product3 = $signed(pipe_weight3_r) * $signed(xd_Q);

	assign pipe_product0_ext = {{6{pipe_product0[15]}}, pipe_product0};
	assign pipe_product1_ext = {{6{pipe_product1[15]}}, pipe_product1};
	assign pipe_product2_ext = {{6{pipe_product2[15]}}, pipe_product2};
	assign pipe_product3_ext = {{6{pipe_product3[15]}}, pipe_product3};

	assign pipe_pair_sum01 = pipe_product0_ext + pipe_product1_ext;
	assign pipe_pair_sum23 = pipe_product2_ext + pipe_product3_ext;
	assign pipe_four_sum   = pipe_pair_sum01 + pipe_pair_sum23;


	// SRAM connecting
	always @(*) begin

		w0_CEN = 1'b1; w0_WEN = 1'b1; w0_A = 12'd0; w0_D = 8'd0;
		w1_CEN = 1'b1; w1_WEN = 1'b1; w1_A = 12'd0; w1_D = 8'd0;
		w2_CEN = 1'b1; w2_WEN = 1'b1; w2_A = 12'd0; w2_D = 8'd0;

		p0_CEN = 1'b1; p0_WEN = 1'b1; p0_A = 12'd0; p0_D = 8'd0;
		p1_CEN = 1'b1; p1_WEN = 1'b1; p1_A = 12'd0; p1_D = 8'd0;
		p2_CEN = 1'b1; p2_WEN = 1'b1; p2_A = 12'd0; p2_D = 8'd0;

		b_CEN  = 1'b1; b_WEN  = 1'b1; b_A  = 8'd0;  b_D  = 8'd0;

		x_CEN  = 1'b1; x_WEN  = 1'b1; x_A  = 12'd0; x_D  = 8'd0;
		xb_CEN = 1'b1; xb_WEN = 1'b1; xb_A = 12'd0; xb_D = 8'd0;
		xc_CEN = 1'b1; xc_WEN = 1'b1; xc_A = 12'd0; xc_D = 8'd0;
		xd_CEN = 1'b1; xd_WEN = 1'b1; xd_A = 12'd0; xd_D = 8'd0;

		case (state)

			LOAD_WEIGHT: begin
				if (w_input_valid) begin
					if (load_count < 14'd4096) begin
						w0_CEN = 1'b0;
						w0_WEN = 1'b0;
						w0_A = load_count[11:0];
						w0_D = raw_input;
					end
					else if (load_count < 14'd8192) begin
						w1_CEN = 1'b0;
						w1_WEN = 1'b0;
						w1_A = load_count[11:0];
						w1_D = raw_input;
					end
					else begin
						w2_CEN = 1'b0;
						w2_WEN = 1'b0;
						w2_A = load_count[11:0];
						w2_D = raw_input;
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
					end
					else if (load_count < 14'd8192) begin
						p1_CEN = 1'b0;
						p1_WEN = 1'b0;
						p1_A = load_count[11:0];
						p1_D = raw_input;
					end
					else begin
						p2_CEN = 1'b0;
						p2_WEN = 1'b0;
						p2_A = load_count[11:0];
						p2_D = raw_input;
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
				end
			end

			READ_BIAS: begin
				b_CEN = 1'b0;
				b_WEN = 1'b1;
				b_A = row_count[7:0];
			end

			LOAD_WP_BUF: begin
				if (wp_issue < 6'd48) begin
					if (wp_issue_sram == 2'd0) begin
						w0_CEN = 1'b0;
						w0_WEN = 1'b1;
						w0_A = wp_issue_index[11:0];

						p0_CEN = 1'b0;
						p0_WEN = 1'b1;
						p0_A = wp_issue_index[11:0];
					end
					else if (wp_issue_sram == 2'd1) begin
						w1_CEN = 1'b0;
						w1_WEN = 1'b1;
						w1_A = wp_issue_index[11:0];

						p1_CEN = 1'b0;
						p1_WEN = 1'b1;
						p1_A = wp_issue_index[11:0];
					end
					else begin
						w2_CEN = 1'b0;
						w2_WEN = 1'b1;
						w2_A = wp_issue_index[11:0];

						p2_CEN = 1'b0;
						p2_WEN = 1'b1;
						p2_A = wp_issue_index[11:0];
					end
				end
			end

			COMPUTE_PIPE: begin
				if (pipe_issue < 6'd48) begin
					x_CEN = 1'b0;
					x_WEN = 1'b1;
					x_A = {token_count, pipe_vector_index0};

					xb_CEN = 1'b0;
					xb_WEN = 1'b1;
					xb_A = {token_count, pipe_vector_index1};

					xc_CEN = 1'b0;
					xc_WEN = 1'b1;
					xc_A = {token_count, pipe_vector_index2};

					xd_CEN = 1'b0;
					xd_WEN = 1'b1;
					xd_A = {token_count, pipe_vector_index3};
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
			token_count <= 4'd0;
			out_count <= 12'd0;

			sum <= 22'd0;
			bias_ext <= 22'd0;

			wp_issue <= 6'd0;
			wp_capture <= 6'd0;
			wp_valid <= 1'b0;
			wp_sram_r <= 2'd0;

			pipe_issue <= 6'd0;
			pipe_done <= 6'd0;
			pipe_x_valid <= 1'b0;

			pipe_weight0_r <= 8'd0;
			pipe_weight1_r <= 8'd0;
			pipe_weight2_r <= 8'd0;
			pipe_weight3_r <= 8'd0;
		end

		else begin
			state <= nextstate;

			o_valid <= 1'b0;

			case (state)

				IDLE0: begin
					load_count <= 14'd0;
					row_count  <= 9'd0;
					token_count <= 4'd0;
					out_count <= 12'd0;
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
					token_count <= 4'd0;
					out_count <= 12'd0;
					sum <= 22'd0;
				end

				LOAD_VECTOR: begin
					if (raw_data_valid) begin
						if (load_count == 14'd4095)
							load_count <= 14'd0;
						else
							load_count <= load_count + 14'd1;
					end
				end

				WAIT_BIAS: begin
					bias_ext <= {{10{b_Q[7]}}, b_Q, 4'b0000}; // S0.7 -> S10.11
				end

				INIT_ROW: begin
					wp_issue <= 6'd0;
					wp_capture <= 6'd0;
					wp_valid <= 1'b0;
					wp_sram_r <= 2'd0;
					token_count <= 4'd0;
				end

				LOAD_WP_BUF: begin
					if (wp_valid) begin
						w_buf[wp_capture] <= wp_weight_q;
						p_buf[wp_capture] <= wp_position_q;
					end

					if (wp_issue < 6'd48) begin
						wp_sram_r <= wp_issue_sram;
						wp_capture <= wp_issue;
						wp_issue <= wp_issue + 6'd1;
						wp_valid <= 1'b1;
					end
					else begin
						wp_valid <= 1'b0;
					end
				end

				INIT_TOKEN: begin
					sum <= bias_ext;
					pipe_issue <= 6'd0;
					pipe_done <= 6'd0;
					pipe_x_valid <= 1'b0;
					pipe_weight0_r <= 8'd0;
					pipe_weight1_r <= 8'd0;
					pipe_weight2_r <= 8'd0;
					pipe_weight3_r <= 8'd0;
				end

				COMPUTE_PIPE: begin
					// X_Q valid, do four MACs
					if (pipe_x_valid) begin
						sum <= sum + pipe_four_sum;

						if (pipe_done <= 6'd44)
							pipe_done <= pipe_done + 6'd4;
					end

					// Issue X reads from four duplicated vector SRAMs
					if (pipe_issue < 6'd48) begin
						pipe_weight0_r <= w_buf[pipe_issue];
						pipe_weight1_r <= w_buf[pipe_issue_plus1];
						pipe_weight2_r <= w_buf[pipe_issue_plus2];
						pipe_weight3_r <= w_buf[pipe_issue_plus3];

						pipe_issue <= pipe_issue + 6'd4;
						pipe_x_valid <= 1'b1;
					end
					else begin
						pipe_x_valid <= 1'b0;
					end
				end

				STORE_RESULT: begin
					out_buf[{token_count, row_count[7:0]}] <= sum;

					if (token_count == 4'd15) begin
						token_count <= 4'd0;

						if (row_count == 9'd255)
							row_count <= 9'd0;
						else
							row_count <= row_count + 9'd1;
					end
					else begin
						token_count <= token_count + 4'd1;
					end
				end

				OUTPUT_BUF: begin
					o_result <= out_buf[out_count];
					o_valid  <= 1'b1;

					if (out_count == 12'd4095)
						out_count <= 12'd0;
					else
						out_count <= out_count + 12'd1;
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
				nextstate = INIT_ROW;
			end

			INIT_ROW: begin
				nextstate = LOAD_WP_BUF;
			end

			LOAD_WP_BUF: begin
				if (wp_valid && wp_capture == 6'd47)
					nextstate = INIT_TOKEN;
				else
					nextstate = LOAD_WP_BUF;
			end

			INIT_TOKEN: begin
				nextstate = COMPUTE_PIPE;
			end

			COMPUTE_PIPE: begin
				if (pipe_x_valid && pipe_done == 6'd44)
					nextstate = STORE_RESULT;
				else
					nextstate = COMPUTE_PIPE;
			end

			STORE_RESULT: begin
				if (row_count == 9'd255 && token_count == 4'd15)
					nextstate = OUTPUT_BUF;
				else if (token_count == 4'd15)
					nextstate = READ_BIAS;
				else
					nextstate = INIT_TOKEN;
			end

			OUTPUT_BUF: begin
				if (out_count == 12'd4095)
					nextstate = IDLE1;
				else
					nextstate = OUTPUT_BUF;
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
