module psram(
    input           sck,
    input           ce_n,
    inout   [ 3:0]  dio
);

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

wire [ 3:0] din, dout, douten;
reg [ 7:0] cnt;
reg [ 7:0] cmd;
reg [23:0] addr;
reg [31:0] data;

always @(posedge sck or posedge reset) begin
    if (reset) state <= cmd_t;
    else begin
        case (state)
        cmd_t:  state <= (cnt == 8'd07) ? addr_t    : state;
        addr_t: state <= (cmd != 8'hEB && cmd != 8'h38) ? err_t   :
                         (cmd == 8'hEB) ? wait_t   :
                         (cmd == 8'h38) ? wdata_t   : state;
        wait_t: state <= (cnt == 8'd05) ? rdata_t   : state;
        rdata_t: state <= state;
        wdata_t: state <= state;
        default: begin
            state <= state;
            $fwrite(32'h80000002, "Assertion failed: Unsupported command `%xh`, only support `EBh` and `38h` read command\n", cmd);
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
    end
end

always @(posedge sck or posedge reset) begin
    if (reset) cnt <= 8'h0;
    else begin
        case (state)
            cmd_t:  cnt <= (cnt < 8'd7 ) ? cnt + 1'b1 : 8'd0;
            addr_t: cnt <= (cnt < 8'd23) ? cnt + 1'b1 : 8'd0;
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
