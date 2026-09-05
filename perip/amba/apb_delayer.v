module apb_delayer(
  input         clock,
  input         reset,
  input  [31:0] in_paddr,
  input         in_psel,
  input         in_penable,
  input  [2:0]  in_pprot,
  input         in_pwrite,
  input  [31:0] in_pwdata,
  input  [3:0]  in_pstrb,
  output        in_pready,
  output [31:0] in_prdata,
  output        in_pslverr,

  output [31:0] out_paddr,
  output        out_psel,
  output        out_penable,
  output [2:0]  out_pprot,
  output        out_pwrite,
  output [31:0] out_pwdata,
  output [3:0]  out_pstrb,
  input         out_pready,
  input  [31:0] out_prdata,
  input         out_pslverr
);

  parameter ratio = 3;
  parameter scale = 5;

  typedef enum [1:0]{
    idle_t,
    wait_t,
    delay_t
  } state_t;
  state_t state;
  reg [31:0]  delay_cycle;
  reg [31:0]  latency_count;

  reg         pready;
  reg [31:0]  prdata;
  reg         pslverr;   
  reg         delay_done;

  always @(posedge clock) begin
    if (reset == 1'b1) begin
      delay_cycle <= 32'b0;
      delay_done <= 1'b0;
      latency_count <= 32'b0;
      state <= idle_t;
    end
    else begin
      case (state) 
        idle_t: begin
            if (delay_done) delay_done <= 1'b0;
            if (in_penable && in_psel) begin
                state <= wait_t;
                delay_done <= 1'b0;
                latency_count <= 32'b0;
                delay_cycle <= 32'b0;
            end
        end
        wait_t: begin
          latency_count <= latency_count + 32'b1;
          if (out_pready) begin
            pready <= out_pready;
            prdata <= out_prdata;
            pslverr <= out_pslverr;
            state <= delay_t;
            delay_cycle <= delay_cycle / scale;
          end
          else begin
            delay_cycle <= delay_cycle + ratio * scale;
          end
        end
        delay_t: begin
          if (delay_cycle > latency_count) delay_cycle <= delay_cycle - 32'b1;
          else begin
            state <= idle_t;
            delay_done <= 1'b1;
          end
        end
        default:;
      endcase
    end
  end


  assign out_paddr   = in_paddr;
  assign out_psel    = (state == wait_t) ? in_psel : 1'b0; 
  assign out_penable = (state == wait_t) ? in_penable : 1'b0;
  assign out_pprot   = in_pprot;
  assign out_pwrite  = in_pwrite;
  assign out_pwdata  = in_pwdata;
  assign out_pstrb   = in_pstrb;
  assign in_pready   = delay_done ? pready : 1'b0;
  assign in_prdata   = delay_done ? prdata : 32'b0;
  assign in_pslverr  = delay_done ? pslverr : 1'b0;

endmodule
