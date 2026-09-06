module axi4_delayer(
  input         clock,
  input         reset,

  output        in_arready,
  input         in_arvalid,
  input  [3:0]  in_arid,
  input  [31:0] in_araddr,
  input  [7:0]  in_arlen,
  input  [2:0]  in_arsize,
  input  [1:0]  in_arburst,
  input         in_rready,
  output        in_rvalid,
  output [3:0]  in_rid,
  output [31:0] in_rdata,
  output [1:0]  in_rresp,
  output        in_rlast,
  output        in_awready,
  input         in_awvalid,
  input  [3:0]  in_awid,
  input  [31:0] in_awaddr,
  input  [7:0]  in_awlen,
  input  [2:0]  in_awsize,
  input  [1:0]  in_awburst,
  output        in_wready,
  input         in_wvalid,
  input  [31:0] in_wdata,
  input  [3:0]  in_wstrb,
  input         in_wlast,
                in_bready,
  output        in_bvalid,
  output [3:0]  in_bid,
  output [1:0]  in_bresp,

  input         out_arready,
  output        out_arvalid,
  output [3:0]  out_arid,
  output [31:0] out_araddr,
  output [7:0]  out_arlen,
  output [2:0]  out_arsize,
  output [1:0]  out_arburst,
  output        out_rready,
  input         out_rvalid,
  input  [3:0]  out_rid,
  input  [31:0] out_rdata,
  input  [1:0]  out_rresp,
  input         out_rlast,
  input         out_awready,
  output        out_awvalid,
  output [3:0]  out_awid,
  output [31:0] out_awaddr,
  output [7:0]  out_awlen,
  output [2:0]  out_awsize,
  output [1:0]  out_awburst,
  input         out_wready,
  output        out_wvalid,
  output [31:0] out_wdata,
  output [3:0]  out_wstrb,
  output        out_wlast,
                out_bready,
  input         out_bvalid,
  input  [3:0]  out_bid,
  input  [1:0]  out_bresp
);

    parameter ratio = 3; 
    parameter scale = 5; 


    typedef enum [1:0] {
        read_idle,
        wait_arready,
        delay_arready,
        read_data
    } read_state_t;

    read_state_t read_state;

    reg [31:0] response_schedule [0:256];

    reg [31:0] latency_count;

    reg [7:0] num_of_data;
    reg [7:0] num_have_send;


    typedef struct packed {
        reg [3:0]  id;
        reg [31:0] data;
        reg [1:0]  resp;
        reg        last;
    } rdata_t;

    rdata_t data_array [0:255];

    assign out_arvalid = ((read_state == read_idle) || (read_state == wait_arready)) ? in_arvalid : 1'b0;

    assign out_arid    = in_arid;
    assign out_araddr  = in_araddr;
    assign out_arlen   = in_arlen;
    assign out_arsize  = in_arsize;
    assign out_arburst = in_arburst;


    assign in_arready = (read_state == read_idle)       ? out_arready :
                        (read_state == delay_arready)   ? ((latency_count + 1) >= response_schedule[0]) : 
                        1'b0;


    assign out_rready = (read_state != read_idle);


    assign in_rvalid =
        (read_state == read_data) &&
        (num_have_send < num_of_data) &&
        ((latency_count + 1) >=
         response_schedule[num_have_send + 1]);


    assign in_rid   = data_array[num_have_send].id;
    assign in_rdata = data_array[num_have_send].data;
    assign in_rresp = data_array[num_have_send].resp;
    assign in_rlast = data_array[num_have_send].last;

    always @(posedge clock) begin
        if (reset) begin
            read_state    <= read_idle;
            latency_count <= 32'b0;
            num_of_data      <= 8'b0;
            num_have_send    <= 8'b0;
        end
        else begin
            case (read_state)
                read_idle: begin
                    if (in_arvalid) begin
                        latency_count <= 32'b0;
                        num_of_data   <= 8'b0;
                        num_have_send <= 8'b0;
                        if (out_arready) begin
                            read_state <= read_data;
                        end
                        else begin
                            read_state <= wait_arready;
                        end
                    end
                end
                wait_arready: begin
                    latency_count <= latency_count + 1'b1;
                    if (out_arready) begin
                        response_schedule[0] <= (latency_count + 1) * ratio * scale;
                        read_state <= delay_arready;
                    end
                end
                delay_arready: begin
                    latency_count <= latency_count + 1'b1;
                    if (in_arvalid && in_arready) begin
                        read_state <= read_data;
                    end
                end
                read_data: begin
                    latency_count <= latency_count + 1'b1;
                    if (in_rvalid && in_rready) begin
                        num_have_send <= num_have_send + 1'b1;
                        if (in_rlast) begin
                            read_state <= read_idle;
                        end
                    end
                end
            endcase

            if ((read_state != read_idle) && out_rvalid && out_rready) begin
                data_array[num_of_data].id   <= out_rid;
                data_array[num_of_data].data <= out_rdata;
                data_array[num_of_data].resp <= out_rresp;
                data_array[num_of_data].last <= out_rlast;
                response_schedule[num_of_data + 1] <= (latency_count + 1) * ratio * scale;
                num_of_data <= num_of_data + 1'b1;
            end

        end
    end



    assign in_awready = out_awready;
    assign out_awvalid = in_awvalid;
    assign out_awid = in_awid;
    assign out_awaddr = in_awaddr;
    assign out_awlen = in_awlen;
    assign out_awsize = in_awsize;
    assign out_awburst = in_awburst;

    assign in_wready = out_wready;
    assign out_wvalid = in_wvalid;
    assign out_wdata = in_wdata;
    assign out_wstrb = in_wstrb;
    assign out_wlast = in_wlast;

    assign out_bready = in_bready;
    assign in_bvalid = out_bvalid;
    assign in_bid = out_bid;
    assign in_bresp = out_bresp;


endmodule
