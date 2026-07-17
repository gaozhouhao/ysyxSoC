// define this macro to enable fast behavior simulation
// for flash by skipping SPI transfers
//`define FAST_FLASH

module spi_top_apb #(
  parameter flash_addr_start = 32'h30000000,
  parameter flash_addr_end   = 32'h3fffffff,
  parameter spi_ss_num       = 8
) (
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

  output                  spi_sck,
  output [spi_ss_num-1:0] spi_ss,
  output                  spi_mosi,
  input                   spi_miso,
  output                  spi_irq_out
);

`ifdef FAST_FLASH

wire [31:0] data;
parameter invalid_cmd = 8'h0;
flash_cmd flash_cmd_i(
  .clock(clock),
  .valid(in_psel && !in_penable),
  .cmd(in_pwrite ? invalid_cmd : 8'h03),
  .addr({8'b0, in_paddr[23:2], 2'b0}),
  .data(data)
);
assign spi_sck    = 1'b0;
assign spi_ss     = 8'b0;
assign spi_mosi   = 1'b1;
assign spi_irq_out= 1'b0;
assign in_pslverr = 1'b0;
assign in_pready  = in_penable && in_psel && !in_pwrite;
assign in_prdata  = data[31:0];

`else // not FAST_FLASH

`define TX0     5'h0
`define TX1     5'h4
`define RX0     5'h0
`define RX1     5'h4
`define CTRL    5'h10
`define DIVIDER 5'h14
`define SS      5'h18

typedef enum logic [3:0] {
    RESET,                  //0
    WAIT_CTRL_INIT_ACK,//1
    WAIT_SS_INIT_ACK,//2
    WAIT_DIVIDER_INIT_ACK,//3
    IDLE,//4
    WAIT_TX1_ACK,//5
    WAIT_TX0_ACK,//6
    WAIT_CTRL_ACK,//7
    WAIT_BUSY_CLR,//8
    WAIT_RX0_ACK,//9
    DONE//A
} state_t;

state_t state;

wire [31:0] wb_adr_i;
wire [31:0] wb_dat_i;
wire [3:0]  wb_sel_i;
wire        wb_we_i;
wire        wb_stb_i;
wire        wb_cyc_i;
wire        wb_ack_o;
wire [31:0] wb_dat_o;

reg [31:0]  xip_addr;
reg [31:0]  xip_data;
reg         xip_we;
reg         xip_stb;
reg         xip_cyc;

reg [31:0]  init_addr;
reg [31:0]  init_data;
reg         init_we;
reg         init_stb;
reg         init_cyc;
    
reg [31:0]  xip_prdata;
reg         xip_pready;

wire is_flash;
reg init_done;
assign is_flash =   in_paddr >= flash_addr_start &&
                    in_paddr <= flash_addr_end &&
                    in_psel && in_penable;

localparam instruction = 32'h0000_2440;

always @(posedge clock) begin
    if (reset) begin
        state <= RESET;
        xip_addr <= 32'b0;
        xip_data <= 32'b0;
        xip_we <= 1'b0;
        xip_stb <= 1'b0;
        xip_cyc <= 1'b0;
        init_done <= 0;
    end
    else begin
            //$display("state:%x", state);
            //$display("wb_dta_o[8]:%x", wb_dat_o[8]);
            //$display("xip_data:%x\n", xip_data);
        case(state) 
            //**********
            // SPI Master Initialize
            //**********
            RESET: begin
                init_addr[4:0] <= `CTRL; 
                init_data <= instruction;
                init_we <= 1'b1;
                init_stb <= 1'b1;
                init_cyc <= 1'b1;
                state <= WAIT_CTRL_INIT_ACK; 
            end
            WAIT_CTRL_INIT_ACK: begin
                if (wb_ack_o) begin
                    init_addr[4:0] <= `SS;
                    init_data <= 32'h01;
                    state <= WAIT_SS_INIT_ACK;
                end
            end
            WAIT_SS_INIT_ACK: begin
                if (wb_ack_o) begin
                    init_addr[4:0] <= `DIVIDER;
                    init_data <= 32'h00;
                    state <= WAIT_DIVIDER_INIT_ACK;
                end
            end
            WAIT_DIVIDER_INIT_ACK: begin
                if (wb_ack_o) begin
                    init_we <= 1'b0;
                    init_stb <= 1'b0;
                    init_cyc <= 1'b0;
                    init_done <= 1;
                    state <= IDLE;
                end
            end
            //***********
            // Flash Read
            // *********
            IDLE: begin
                if (is_flash) begin
                    xip_addr[4:0] <= `TX1;
                    xip_data <= {8'h03, in_paddr[23:0]};
                    xip_pready <= 1'b0;
                    xip_we <= 1'b1;
                    xip_stb <= 1'b1;
                    xip_cyc <= 1'b1;
                    state <= WAIT_TX1_ACK;
                end
            end
            WAIT_TX1_ACK: begin
                if (wb_ack_o) begin
                    xip_addr[4:0] <= `TX0;
                    xip_data <= 32'h0;
                    state <= WAIT_TX0_ACK;
                end
            end
            WAIT_TX0_ACK: begin
                if (wb_ack_o) begin
                    xip_addr[4:0] <= `CTRL;
                    xip_data <= 32'h0000_2440 | (1 << 8);
                    state <= WAIT_CTRL_ACK;
                end
            end
            WAIT_CTRL_ACK: begin
                if (wb_ack_o) begin
                    xip_addr[4:0] <= `CTRL;
                    xip_we <= 1'b0;
                    state <= WAIT_BUSY_CLR;
                end
            end
            //while(*(volatile uint32_t*)CTRL & (0x1 << 8));
            WAIT_BUSY_CLR: begin
                if (wb_ack_o) begin
                    if (wb_dat_o[8]) begin
                        xip_addr[4:0] <= `CTRL;
                        xip_we <= 1'b0;
                    end
                    else begin
                        xip_addr[4:0] <= `RX0;
                        xip_we <= 1'b0;
                        state <= WAIT_RX0_ACK;
                    end
                end
            end
            WAIT_RX0_ACK: begin
                if(wb_ack_o) begin
                    xip_prdata <= {
                        wb_dat_o[7:0],
                        wb_dat_o[15:8],
                        wb_dat_o[23:16],
                        wb_dat_o[31:24]
                    };
                    xip_pready <= 1'b1;
                    xip_stb <= 1'b0;
                    xip_cyc <= 1'b0;
                    xip_we  <= 1'b0;
                    state <= DONE;
                end
            end
            DONE: begin
                xip_pready <= 1'b0;
                state <= IDLE;
            end
            default:;
        endcase
    end
end


assign  wb_adr_i =  !init_done  ?   init_addr   :
                    is_flash    ?   xip_addr    :
                                    in_paddr    ;

assign  wb_dat_i =  !init_done  ?   init_data   :
                    is_flash    ?   xip_data    :
                                    in_pwdata   ;

assign  wb_sel_i =  !init_done  ?   4'b1111     :
                    is_flash    ?   4'b1111     :
                                    in_pstrb    ;

assign  wb_we_i =   !init_done  ?   init_we     :
                    is_flash    ?   xip_we      :
                                    in_pwrite;

assign  wb_stb_i =  !init_done  ?   init_stb    :
                    is_flash    ?   xip_stb     :
                                    in_psel     ;

assign  wb_cyc_i =  !init_done  ?   init_cyc    :
                    is_flash    ?   xip_cyc     :
                                    in_penable  ;
assign  in_pready = is_flash ? xip_pready : wb_ack_o;
assign  in_prdata = is_flash ? xip_prdata : wb_dat_o;

spi_top u0_spi_top (
  .wb_clk_i(clock),
  .wb_rst_i(reset),
  .wb_adr_i(wb_adr_i[4:0]),
  .wb_dat_i(wb_dat_i),
  .wb_dat_o(wb_dat_o),
  .wb_sel_i(wb_sel_i),
  .wb_we_i (wb_we_i),
  .wb_stb_i(wb_stb_i),
  .wb_cyc_i(wb_cyc_i),
  .wb_ack_o(wb_ack_o),
  .wb_err_o(in_pslverr),
  .wb_int_o(spi_irq_out),

  .ss_pad_o(spi_ss),
  .sclk_pad_o(spi_sck),
  .mosi_pad_o(spi_mosi),
  .miso_pad_i(spi_miso)
);

`endif

endmodule
