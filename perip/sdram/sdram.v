module sdram(
  input        clk,
  input        cke,
  input        cs,
  input        ras,
  input        cas,
  input        we,
  input [12:0] a,
  input [ 1:0] ba,
  input [ 1:0] dqm,
  inout [15:0] dq
);

  reg [15:0] bank[0:3][0:8191][0:511];

  typedef enum logic [2:0] {
    CMD_LOAD_MODE,
    CMD_AUTO_REFRESH,
    CMD_PRECHARGE,
    CMD_ACTIVE,
    CMD_WRITE,
    CMD_READ,
    CMD_BURST_TERM,
    CMD_NOP
  } cmd_t;

  wire [2:0] cmd;
  assign cmd = {ras, cas, we};

  typedef enum logic [1:0] {
    WR_IDLE,
    WRITE
  } wr_state_t;
  wr_state_t wr_state;

  typedef enum logic [1:0] {
    RD_IDLE,
    WAIT,
    READ
  } rd_state_t;
  rd_state_t rd_state;

  // Burst Length (A2:A0)
  localparam MR_BL_1         = 3'b000;
  localparam MR_BL_2         = 3'b001;
  localparam MR_BL_4         = 3'b010;
  localparam MR_BL_8         = 3'b011;
  localparam MR_BL_FULL_PAGE = 3'b111;

  // CAS Latency (A6:A4)
  localparam MR_CL_1         = 3'b001;
  localparam MR_CL_2         = 3'b010;
  localparam MR_CL_3         = 3'b011;

  reg [3:0] BL_NUM;
  reg [3:0] wr_cnt, rd_cnt;
  reg [2:0] wait_cnt;
  always @(*) begin
    case (Mode[2:0])
      MR_BL_1: BL_NUM = 4'd1;
      MR_BL_2: BL_NUM = 4'd2;
      MR_BL_4: BL_NUM = 4'd4;
      MR_BL_8: BL_NUM = 4'd8;
      MR_BL_FULL_PAGE: BL_NUM = 4'hf;
      default: BL_NUM = 4'd0;
    endcase
  end

  reg [2:0] CL_NUM;
  always @(*) begin
    case (Mode[6:4])
      MR_CL_1: CL_NUM = 3'd1;
      MR_CL_2: CL_NUM = 3'd2;
      MR_CL_3: CL_NUM = 3'd3;
      default: CL_NUM = 3'd0;
    endcase
  end

  reg [11:0] Mode;
  reg [ 1:0] rd_ba_r;
  reg [12:0] active_row_r[0:3];
  reg [ 8:0] wr_col_r, rd_col_r;

  wire [15:0] din;
  reg [15:0] dout;
  reg [ 1:0] douten;

  always @(posedge clk) begin
    if(cs == 1'b0) begin
      case (cmd)
        CMD_NOP:;
        CMD_LOAD_MODE: Mode <= a[11:0];
        CMD_ACTIVE: begin
          active_row_r[ba] <= a;
          //wr_ba_r <= ba;
          //rd_row_r <= a;
          //rd_ba_r <= ba;
        end
        CMD_READ: begin
          rd_ba_r <= ba;
        end
        // CMD_WRITE: begin
        //   wr_ba_r <= ba;
        // end
        default;
      endcase
    end
  end

  //////////////
  // WRITE
  /////////////
  always @(posedge clk) begin
    //if (cs == 1'b0) begin
      case (wr_state)
        WR_IDLE: begin
          if (cmd == CMD_WRITE && cs == 1'b0) begin
            wr_col_r <= a[8:0] + 1'b1;
            wr_cnt <= wr_cnt + 4'b1;
            bank[ba][active_row_r[ba]][a[8:0]][7:0] <= dqm[0] ? bank[ba][active_row_r[ba]][a[8:0]][7:0] : din[7:0];
            bank[ba][active_row_r[ba]][a[8:0]][15:8] <= dqm[1] ? bank[ba][active_row_r[ba]][a[8:0]][15:8] : din[15:8];
            wr_state <= WRITE;
          end
          else begin
            wr_state <= WR_IDLE;
            wr_cnt <= 4'b0;
          end
        end
        WRITE: begin
          if (wr_cnt == BL_NUM) begin
            wr_cnt <= 0;
            wr_state <= WR_IDLE;
          end
          else begin
            wr_cnt <= wr_cnt + 1;
            wr_col_r <= wr_col_r + 1'b1;
            bank[ba][active_row_r[ba]][wr_col_r][7:0] <= dqm[0] ? bank[ba][active_row_r[ba]][wr_col_r][7:0] : din[7:0];
            bank[ba][active_row_r[ba]][wr_col_r][15:8] <= dqm[1] ? bank[ba][active_row_r[ba]][wr_col_r][15:8] : din[15:8];
            wr_state <= WRITE;
          end
        end
        default: ;
      endcase
    //end

  end

  ///////////
  // READ
  ////////////
  always @(posedge clk) begin
    //if (cs == 1'b0) begin
      case (rd_state)
        RD_IDLE: begin
          rd_cnt <= 4'd0;
          if (cmd == CMD_READ && cs == 1'b0) begin
            rd_col_r <= a[8:0];
            wait_cnt <= wait_cnt + 3'b1;
            rd_state <= WAIT;
          end
          else begin
            douten <= 2'b11;
            wait_cnt <= 3'd0;
            rd_state <= RD_IDLE;
          end
        end
        WAIT: begin
          if (wait_cnt + 1'b1 < CL_NUM) begin
            wait_cnt <= wait_cnt + 1'b1;
            rd_state <= WAIT;
          end
          else begin
            douten <= dqm;
            dout <= bank[rd_ba_r][active_row_r[rd_ba_r]][rd_col_r];
            rd_cnt <= rd_cnt + 1'b1;
            rd_col_r <= rd_col_r + 1'b1;
            if (BL_NUM == 1)
              rd_state <= RD_IDLE;
            else
              rd_state <= READ;
          end
        end
        READ: begin
          if (rd_cnt < BL_NUM) begin
            dout <= bank[rd_ba_r][active_row_r[rd_ba_r]][rd_col_r];
            rd_cnt <= rd_cnt + 1'b1;
            rd_col_r <= rd_col_r + 1'b1;
            rd_state <= READ;
          end
          else begin
            douten <= 2'b11;
            rd_state <= RD_IDLE;
          end
        end
        default: ;
      endcase
    //end

  end


  assign dq[7:0] = douten[0] ? 8'bz : dout[7:0];
  assign dq[15:8] = douten[1] ? 8'bz : dout[15:8];
  assign din = dq;

endmodule
