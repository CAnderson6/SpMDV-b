module SpMDV 
(
    input clk,
    input rst,
    input start_init,
    input [7 : 0] raw_input,
    input raw_data_valid,
    input w_input_valid,
    output reg raw_data_request,
    output reg ld_w_request,
    output reg [21 : 0] o_result,
    output reg o_valid
);

    // ============================================================
    // 1. 暫存器與狀態定義 [cite: 222, 281]
    // ============================================================
    reg [13:0] load_count; 
    reg [8:0]  row_count; 
    reg [5:0]  nonzero_count; 
    reg [3:0]  vector_count; 

    localparam IDLE0         = 4'd0;
    localparam LOAD_WEIGHT   = 4'd1;
    localparam LOAD_POSITION = 4'd2;
    localparam LOAD_BIAS     = 4'd3;
    localparam IDLE1         = 4'd4; // 每輪 16 個向量的緩衝狀態
    localparam LOAD_VECTOR   = 4'd5;
    localparam READ_BIAS     = 4'd6;
    localparam WAIT_BIAS     = 4'd7;
    localparam INIT_MULT     = 4'd8;
    localparam READ_WP       = 4'd9;
    localparam WAIT_WP       = 4'd10;
    localparam LATCH_WP      = 4'd11;
    localparam READ_VECTOR   = 4'd12;
    localparam WAIT_VECTOR   = 4'd13;
    localparam CALCULATION   = 4'd14;
    localparam OUTPUT        = 4'd15;

    reg [3:0] state, nextstate;

    // SRAM 介面 [cite: 1290, 1297]
    reg [11:0] w0_A, w1_A, w2_A, p0_A, p1_A, p2_A, x_A;
    reg [7:0]  w0_D, w1_D, w2_D, p0_D, p1_D, p2_D, b_A, b_D, x_D;
    wire [7:0] w0_Q, w1_Q, w2_Q, p0_Q, p1_Q, p2_Q, b_Q, x_Q;
    reg w0_CEN, w0_WEN, w1_CEN, w1_WEN, w2_CEN, w2_WEN;
    reg p0_CEN, p0_WEN, p1_CEN, p1_WEN, p2_CEN, p2_WEN;
    reg b_CEN, b_WEN, x_CEN, x_WEN;

    // ============================================================
    // 2. 核心計算邏輯 [cite: 1255, 1265]
    // ============================================================
    reg signed [21:0] sum;
    reg signed [7:0] weight_r, vector_r;
    reg [5:0] position_r;
    wire signed [15:0] product = $signed(weight_r) * $signed(vector_r);
    wire signed [21:0] product_ext = {{6{product[15]}}, product};

    reg [1:0] wp_bank;
    wire [13:0] nonzero_index = row_count * 14'd48 + nonzero_count;

    // BBS 索引計算：確保正確映射到 4 個 Bank [cite: 331, 426]
    reg [7:0] vector_index;
    always @(*) begin
        case (nonzero_count[1:0])
            2'd0: vector_index = {2'd0, position_r};
            2'd1: vector_index = 8'd64  + {2'd0, position_r};
            2'd2: vector_index = 8'd128 + {2'd0, position_r};
            2'd3: vector_index = 8'd192 + {2'd0, position_r};
            default: vector_index = 8'd0;
        endcase
    end

    // ============================================================
    // 3. SRAM 控制電路 (修正位址同步) [cite: 1302, 1308]
    // ============================================================
    always @(*) begin
        // 預設關閉所有 SRAM
        {w0_CEN, w1_CEN, w2_CEN, p0_CEN, p1_CEN, p2_CEN, b_CEN, x_CEN} = 8'hFF;
        {w0_WEN, w1_WEN, w2_WEN, p0_WEN, p1_WEN, p2_WEN, b_WEN, x_WEN} = 8'hFF;
        {w0_A, w1_A, w2_A, p0_A, p1_A, p2_A, x_A, b_A} = 92'd0;
        {w0_D, w1_D, w2_D, p0_D, p1_D, p2_D, x_D, b_D} = 64'd0;

        case (state)
            LOAD_WEIGHT: if(w_input_valid) begin
                if(load_count < 4096) begin w0_CEN=0; w0_WEN=0; w0_A=load_count[11:0]; w0_D=raw_input; end
                else if(load_count < 8192) begin w1_CEN=0; w1_WEN=0; w1_A=load_count[11:0]; w1_D=raw_input; end
                else begin w2_CEN=0; w2_WEN=0; w2_A=load_count[11:0]; w2_D=raw_input; end
            end
            LOAD_POSITION: if(w_input_valid) begin
                if(load_count < 4096) begin p0_CEN=0; p0_WEN=0; p0_A=load_count[11:0]; p0_D=raw_input; end
                else if(load_count < 8192) begin p1_CEN=0; p1_WEN=0; p1_A=load_count[11:0]; p1_D=raw_input; end
                else begin p2_CEN=0; p2_WEN=0; p2_A=load_count[11:0]; p2_D=raw_input; end
            end
            LOAD_BIAS: if(w_input_valid) begin b_CEN=0; b_WEN=0; b_A=load_count[7:0]; b_D=raw_input; end
            LOAD_VECTOR: if(raw_data_valid) begin x_CEN=0; x_WEN=0; x_A=load_count[11:0]; x_D=raw_input; end
            READ_BIAS: begin b_CEN=0; b_WEN=1; b_A=row_count[7:0]; end
            READ_WP: begin
                if(nonzero_index < 4096) begin w0_CEN=0; w0_WEN=1; w0_A=nonzero_index[11:0]; p0_CEN=0; p0_WEN=1; p0_A=nonzero_index[11:0]; end
                else if(nonzero_index < 8192) begin w1_CEN=0; w1_WEN=1; w1_A=nonzero_index[11:0]; p1_CEN=0; p1_WEN=1; p1_A=nonzero_index[11:0]; end
                else begin w2_CEN=0; w2_WEN=1; w2_A=nonzero_index[11:0]; p2_CEN=0; p2_WEN=1; p2_A=nonzero_index[11:0]; end
            end
            READ_VECTOR: begin x_CEN=0; x_WEN=1; x_A={vector_count, vector_index}; end
        endcase
    end

    // ============================================================
    // 4. 有限狀態機與數據路徑 (核心修正)
    // ============================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE0; load_count <= 0; row_count <= 0; nonzero_count <= 0; vector_count <= 0;
            o_valid <= 0; o_result <= 0;
        end else begin
            state <= nextstate;
            raw_data_request <= 0; ld_w_request <= 0; o_valid <= 0;

            case (state)
                IDLE0: load_count <= 0;
                LOAD_WEIGHT, LOAD_POSITION, LOAD_BIAS: begin
                    ld_w_request <= 1;
                    if (w_input_valid) load_count <= (load_count == (state==LOAD_BIAS ? 255 : 12287)) ? 0 : load_count + 1;
                end
                IDLE1: load_count <= 0; // 重置下一輪 Vector 載入計數
                LOAD_VECTOR: begin
                    raw_data_request <= 1;
                    if (raw_data_valid) load_count <= (load_count == 4095) ? 0 : load_count + 1;
                end
                INIT_MULT: begin 
                    sum <= {{10{b_Q[7]}}, b_Q, 4'b0000}; 
                    nonzero_count <= 0; 
                end
                READ_WP: wp_bank <= (nonzero_index < 4096) ? 0 : (nonzero_index < 8192) ? 1 : 2;
                LATCH_WP: begin
                    case(wp_bank)
                        0: begin weight_r <= w0_Q; position_r <= p0_Q[5:0]; end
                        1: begin weight_r <= w1_Q; position_r <= p1_Q[5:0]; end
                        2: begin weight_r <= w2_Q; position_r <= p2_Q[5:0]; end
                    endcase
                end
                WAIT_VECTOR: vector_r <= x_Q;
                CALCULATION: begin
                    sum <= sum + product_ext;
                    nonzero_count <= (nonzero_count == 47) ? 0 : nonzero_count + 1;
                end
                OUTPUT: begin
                    o_result <= sum; o_valid <= 1;
                    if (row_count == 255) begin
                        row_count <= 0;
                        vector_count <= vector_count + 1; // 這裡不判斷 15，交給 nextstate 判斷跳轉
                    end else begin
                        row_count <= row_count + 1;
                    end
                end
            endcase
        end
    end

    // 狀態轉移：修正第二組開始前的數據清除 [cite: 1249, 1289]
    always @(*) begin
        nextstate = state;
        case (state)
            IDLE0: if(start_init) nextstate = LOAD_WEIGHT;
            LOAD_WEIGHT: if(w_input_valid && load_count == 12287) nextstate = LOAD_POSITION;
            LOAD_POSITION: if(w_input_valid && load_count == 12287) nextstate = LOAD_BIAS;
            LOAD_BIAS: if(w_input_valid && load_count == 255) nextstate = IDLE1;
            IDLE1: nextstate = LOAD_VECTOR; // 這裡重置了 load_count 為 0
            LOAD_VECTOR: if(raw_data_valid && load_count == 4095) nextstate = READ_BIAS;
            READ_BIAS: nextstate = WAIT_BIAS;
            WAIT_BIAS: nextstate = INIT_MULT;
            INIT_MULT: nextstate = READ_WP;
            READ_WP: nextstate = WAIT_WP;
            WAIT_WP: nextstate = LATCH_WP;
            LATCH_WP: nextstate = READ_VECTOR;
            READ_VECTOR: nextstate = WAIT_VECTOR;
            WAIT_VECTOR: nextstate = CALCULATION;
            CALCULATION: nextstate = (nonzero_count == 47) ? OUTPUT : READ_WP;
            // 修正：確保 16 個 Token 算完後，歸零 vector_count 並回到 IDLE1 讀取下 16 個
            OUTPUT: if(row_count == 255 && vector_count == 15) nextstate = IDLE1;
                    else if(row_count == 255) nextstate = READ_BIAS;
                    else nextstate = READ_BIAS;
            default: nextstate = IDLE0;
        endcase
    end
endmodule