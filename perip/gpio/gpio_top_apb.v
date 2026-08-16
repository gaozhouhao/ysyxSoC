module gpio_top_apb(
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

  output [15:0] gpio_out,
  input  [15:0] gpio_in,
  output [7:0]  gpio_seg_0,
  output [7:0]  gpio_seg_1,
  output [7:0]  gpio_seg_2,
  output [7:0]  gpio_seg_3,
  output [7:0]  gpio_seg_4,
  output [7:0]  gpio_seg_5,
  output [7:0]  gpio_seg_6,
  output [7:0]  gpio_seg_7
);

  reg [15:0]  led;
  reg [15:0]  key;
  reg [31:0]  seg;

  wire [7:0] segs [9:0];
  assign segs[0] = 8'b11111101;
  assign segs[1] = 8'b01100000;
  assign segs[2] = 8'b11011010;
  assign segs[3] = 8'b11110010;
  assign segs[4] = 8'b01100110;
  assign segs[5] = 8'b10110110;
  assign segs[6] = 8'b10111110;
  assign segs[7] = 8'b11100000;
  assign segs[8] = 8'b11111110;
  assign segs[9] = 8'b11101110;

  wire [31:0] mask = {{8{in_pstrb[3]}}, {8{in_pstrb[2]}}, {8{in_pstrb[1]}}, {8{in_pstrb[0]}}};
  wire [31:0] addr = (in_paddr >= 32'h10002000 && in_paddr < 32'h1000200f) ? in_paddr & 32'hf : in_paddr;

  assign in_pready = 1'b1;
  assign in_pslverr = 1'b0;

  always @(posedge clock) begin
    if (in_psel) begin
      if (in_penable && in_pready) begin
        if (in_pwrite == 1'b1) begin // wirte
          if (addr == 32'h0) begin
            {16'b0, led} <= in_pwdata & mask;
          end
          else if (addr == 32'h8)
            seg <= in_pwdata & mask;
        end
        else begin // read
          if (addr == 32'h4) begin
            
          end
        end
      end
    end
  end




  // always @(posedge clock) begin
  //   if(reset == 1'b0) begin
  //     led <= 16'b0;
  //     key <= 16'b0;
  //   end
  //   else begin
  //     key <= gpio_in;
  //   end
    
  // end

  assign gpio_out = led;

  assign gpio_seg_0 = ~segs[seg[3:0]];
  assign gpio_seg_1 = ~segs[seg[7:4]];
  assign gpio_seg_2 = ~segs[seg[11:8]];
  assign gpio_seg_3 = ~segs[seg[15:12]];
  assign gpio_seg_4 = ~segs[seg[19:16]];
  assign gpio_seg_5 = ~segs[seg[23:20]];
  assign gpio_seg_6 = ~segs[seg[27:24]];
  assign gpio_seg_7 = ~segs[seg[31:28]];

endmodule
