module bitrev (
    input           sck,
    input           ss,
    input           mosi,
    output  reg     miso
);
    //assign miso = 1'b1;
    parameter   WR = 1'b0, RD = 1'b1;

    reg     [3:0]   cnt;
    reg     [7:0]   shifter;
    reg     state, next_state;
    always @(posedge sck or posedge ss) begin
        state <= next_state;
        if(ss == 1) begin
            cnt <= 4'b0;
            shifter[7:0] <= 8'b00;
        end
        else begin
            cnt <= cnt + 1'b1;
            if(state == WR)
                shifter[7:0] <= {shifter[6:0], mosi};
        end
    end
    
    always @(negedge sck or posedge ss) begin
        if(ss == 1) begin
            miso <= 1'b1;
        end
        else begin
            if(state == RD)
                miso <= shifter[cnt - 8];

        end
    end   
    always @(*) begin
        if(cnt < 7) next_state = WR;
        else    next_state = RD;
    end

endmodule
