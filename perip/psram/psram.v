module psram(
    input           sck,
    input           ce_n,
    inout   [ 3:0]  dio
);

logic [7:0] mem[0: 1 << 24 - 1];

assign dio = 4'bz;
wire    reset = ce_n;

typedef enum [2:0]{
    cmd_t,
    addr_t,
    rdata_t,
    wdata_t,
    wait_t,
    err_t    
} state_t;

state_t state;

wire [ 3:0] din;
reg [ 3:0] dout, douten;
reg [ 7:0] cnt;
reg [ 7:0] cmd;
reg [23:0] addr;
reg [23:0] cur_waddr, cur_raddr;
reg [31:0] data;
reg [31:0] rdata;
reg [ 7:0] wdata;

always @(negedge sck) begin
    //if(state == wdata_t && cnt == 0) $display("wdata:\t%h\t%h\t%h\t%h", mem[0], mem[1], mem[2], mem[3]);
end

always @(posedge sck or posedge reset) begin
    //$display("state: %d", state);
    if (reset) state <= cmd_t;
    else begin
        case (state)
        cmd_t:  state <= (cnt == 8'd07) ? addr_t    : state;
        addr_t: state <= (cmd != 8'hEB && cmd != 8'h38) ? err_t   :
                         (cmd == 8'hEB && cnt == 8'h05) ? wait_t   :
                         (cmd == 8'h38 && cnt == 8'h05) ? wdata_t   : state;
        wait_t: state <= (cnt == 8'd05) ? rdata_t   : state;
        rdata_t: state <= state;
        wdata_t: state <= state;
        default: begin
            //$display("cmd: %h", cmd);
            state <= state;
            $fwrite(32'h80000002, "Assertion failed: Unsupported command `%xh`, only support `EBh` and `38h` read command\n", cmd);
            //$finish;
            $fatal;
        end
        endcase
    end
end

always @(posedge sck or posedge reset) begin
    if (reset)  cmd <= 8'h0;
    else if (state == cmd_t) cmd <= {cmd[6:0], din[0]};
end

always @(posedge sck or posedge reset) begin
    if (reset)  addr <= 24'd0;
    else if (state == addr_t) begin
        addr <= {addr[19:0], din};
        cur_waddr <= {cur_waddr[19:0], din};
        //if(cnt == 8'd5) cur_waddr <= addr;
    end
    else if (state == wdata_t) begin
        //$display("cur_waddr:%h", cur_waddr);
        if(cnt == 0) mem[cur_waddr][7:4] <= din;
        if(cnt == 1) begin
            mem[cur_waddr][3:0] <= din;
            cur_waddr <= cur_waddr + 24'b1;
        end
    end
end

always @(negedge sck) begin
    //if(state == wait_t) $display("wait:%h", cnt);
    if(state == wait_t) begin
        if(cnt == 8'd0) cur_raddr <= addr;
    end
    if (state == rdata_t) begin
        //if(state == wait_t) $display("wait");
        //$display("raddr:%h", addr);
        //$display("cur_raddr:%h", cur_raddr);
        //$display("cnt:%h", cnt);
        douten <= 4'hf;
        //$display("dout:%d", dout);
        if(cnt == 0) dout <= mem[cur_raddr][7:4];
        if(cnt == 1) begin
            dout <= mem[cur_raddr][3:0];
            cur_raddr <= cur_raddr + 24'b1;
        end
    end 
    else douten <= 4'h0;
end


always @(posedge sck or posedge reset) begin
    if (reset) cnt <= 8'h0;
    else begin
        case (state)
            cmd_t:  cnt <= (cnt < 8'd7 ) ? cnt + 1'b1 : 8'd0;
            addr_t: cnt <= (cnt < 8'd5) ? cnt + 1'b1 : 8'd0;
            wait_t: cnt <= (cnt < 8'd5) ? cnt + 1'b1 : 8'd0;
            wdata_t: cnt <= (cnt < 8'd1) ? cnt + 1'b1 : 8'd0;
            rdata_t: cnt <= (cnt < 8'd1) ? cnt + 1'b1 : 8'd0;
            default: cnt <= cnt + 8'd1;
        endcase
    end
end

assign dio[0] = douten[0] ? dout[0] : 1'bz;
assign dio[1] = douten[1] ? dout[1] : 1'bz;
assign dio[2] = douten[2] ? dout[2] : 1'bz;
assign dio[3] = douten[3] ? dout[3] : 1'bz;
assign din = dio;

endmodule
