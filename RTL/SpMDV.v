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


	sram_256x8  B_  (.A(b_A),  .D(b_D),  .Q(b_Q),  
					.CLK(clk), .CEN(b_CEN),  .WEN(b_WEN));

	sram_4096x8 X_  (.A(x_A),  .D(x_D),  .Q(x_Q),  
					.CLK(clk), .CEN(x_CEN),  .WEN(x_WEN));

	sram_4096x8 X_B (.A(xb_A), .D(xb_D), .Q(xb_Q),  
					.CLK(clk), .CEN(xb_CEN), .WEN(xb_WEN));


	//Computing
	reg signed [21:0] sum;

	// pipeline registers
	reg [5:0] pipe_issue;   // issued W/P read count, 0~48, step by 2
	reg [5:0] pipe_done;    // finished MAC count, 0~48, step by 2

	reg pipe_wp_valid;      // W/P Q valid in this cycle
	reg pipe_x_valid;       // X Q valid in this cycle

	reg [1:0] pipe_wp_sram0;
	reg [1:0] pipe_wp_sram1;

	reg [1:0] pipe_bank0;
	reg [1:0] pipe_bank1;

	reg signed [7:0] pipe_weight0_r;
	reg signed [7:0] pipe_weight1_r;


	wire [5:0] pipe_issue_plus1;
	wire [1:0] pipe_issue_bank1;

	wire [13:0] pipe_base_index;
	wire [13:0] pipe_issue_index0;
	wire [13:0] pipe_issue_index1;

	wire [1:0] pipe_issue_sram0;
	wire [1:0] pipe_issue_sram1;

	assign pipe_issue_plus1 = pipe_issue + 6'd1;
	assign pipe_issue_bank1 = pipe_issue_plus1[1:0];

	assign pipe_base_index = ({5'd0, row_count} << 5) +
	                         ({5'd0, row_count} << 4);

	assign pipe_issue_index0 = pipe_base_index + {8'd0, pipe_issue};
	assign pipe_issue_index1 = pipe_base_index + {8'd0, pipe_issue_plus1};

	assign pipe_issue_sram0 = pipe_issue_index0[13:12];
	assign pipe_issue_sram1 = pipe_issue_index1[13:12];


	reg signed [7:0] pipe_weight0_q;
	reg signed [7:0] pipe_weight1_q;

	reg [5:0] pipe_position0_q;
	reg [5:0] pipe_position1_q;

	reg [7:0] pipe_vector_index0;
	reg [7:0] pipe_vector_index1;


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


	wire signed [15:0] pipe_product0;
	wire signed [15:0] pipe_product1;

	wire signed [21:0] pipe_product0_ext;
	wire signed [21:0] pipe_product1_ext;

	wire signed [21:0] pipe_pair_sum;

	assign pipe_product0 = $signed(pipe_weight0_r) * $signed(x_Q);
	assign pipe_product1 = $signed(pipe_weight1_r) * $signed(xb_Q);

	assign pipe_product0_ext = {{6{pipe_product0[15]}}, pipe_product0};
	assign pipe_product1_ext = {{6{pipe_product1[15]}}, pipe_product1};

	assign pipe_pair_sum = pipe_product0_ext + pipe_product1_ext;


	// SRAM connecting
	always @(*) begin

		w0_CEN = 1'b1; w0_WEN = 1'b1; w0_A = 12'd0; w0_D = 8'd0;
		w1_CEN = 1'b1; w1_WEN = 1'b1; w1_A = 12'd0; w1_D = 8'd0;
		w2_CEN = 1'b1; w2_WEN = 1'b1; w2_A = 12'd0; w2_D = 8'd0;

		w0b_CEN = 1'b1; w0b_WEN = 1'b1; w0b_A = 12'd0; w0b_D = 8'd0;
		w1b_CEN = 1'b1; w1b_WEN = 1'b1; w1b_A = 12'd0; w1b_D = 8'd0;
		w2b_CEN = 1'b1; w2b_WEN = 1'b1; w2b_A = 12'd0; w2b_D = 8'd0;

		p0_CEN = 1'b1; p0_WEN = 1'b1; p0_A = 12'd0; p0_D = 8'd0;
		p1_CEN = 1'b1; p1_WEN = 1'b1; p1_A = 12'd0; p1_D = 8'd0;
		p2_CEN = 1'b1; p2_WEN = 1'b1; p2_A = 12'd0; p2_D = 8'd0;

		p0b_CEN = 1'b1; p0b_WEN = 1'b1; p0b_A = 12'd0; p0b_D = 8'd0;
		p1b_CEN = 1'b1; p1b_WEN = 1'b1; p1b_A = 12'd0; p1b_D = 8'd0;
		p2b_CEN = 1'b1; p2b_WEN = 1'b1; p2b_A = 12'd0; p2b_D = 8'd0;

		b_CEN  = 1'b1; b_WEN  = 1'b1; b_A  = 8'd0;  b_D  = 8'd0;

		x_CEN  = 1'b1; x_WEN  = 1'b1; x_A  = 12'd0; x_D  = 8'd0;
		xb_CEN = 1'b1; xb_WEN = 1'b1; xb_A = 12'd0; xb_D = 8'd0;


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
				end
			end


			READ_BIAS: begin
				b_CEN = 1'b0;
				b_WEN = 1'b1;
				b_A = row_count[7:0];
			end


			COMPUTE_PIPE: begin

				// Lane0: issue first W/P read
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


				// Lane1: issue second W/P read
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


				// W/P Q valid, issue two vector reads
				if (pipe_wp_valid) begin
					x_CEN = 1'b0;
					x_WEN = 1'b1;
					x_A = {vector_count, pipe_vector_index0};

					xb_CEN = 1'b0;
					xb_WEN = 1'b1;
					xb_A = {vector_count, pipe_vector_index1};
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

			pipe_bank0 <= 2'd0;
			pipe_bank1 <= 2'd0;

			pipe_weight0_r <= 8'd0;
			pipe_weight1_r <= 8'd0;
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

					pipe_bank0 <= 2'd0;
					pipe_bank1 <= 2'd0;

					pipe_weight0_r <= 8'd0;
					pipe_weight1_r <= 8'd0;
				end


				COMPUTE_PIPE: begin

					// X_Q valid, do two MACs
					if (pipe_x_valid) begin
						sum <= sum + pipe_pair_sum;

						if (pipe_done <= 6'd46)
							pipe_done <= pipe_done + 6'd2;
					end


					// W/P Q valid this cycle.
					// Vector read is issued by SRAM control block.
					// Latch two weights for next cycle's MAC.
					if (pipe_wp_valid) begin
						pipe_weight0_r <= pipe_weight0_q;
						pipe_weight1_r <= pipe_weight1_q;
					end

					pipe_x_valid <= pipe_wp_valid;


					// Issue two W/P reads per cycle
					if (pipe_issue < 6'd48) begin
						pipe_wp_valid <= 1'b1;

						pipe_wp_sram0 <= pipe_issue_sram0;
						pipe_wp_sram1 <= pipe_issue_sram1;

						pipe_bank0 <= pipe_issue[1:0];
						pipe_bank1 <= pipe_issue_bank1;

						pipe_issue <= pipe_issue + 6'd2;
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
				if (pipe_x_valid && pipe_done == 6'd46)
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