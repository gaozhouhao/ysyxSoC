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
        delay_t,
        resp_t
    } state_t;
    state_t state;

    reg [31:0] delay_cycle;
    reg [31:0] latency_count;

    reg [31:0] prdata;
    reg        pslverr;

    always @(posedge clock) begin
        if (reset == 1'b1) begin
            state <= idle_t;
            delay_cycle <= 32'b0;
            latency_count <= 32'b0;
            prdata <= 32'b0;
            pslverr <= 1'b0;
        end
        else begin
            case (state)
                idle_t: begin
                if (in_psel && in_penable) begin
                    state <= wait_t;
                    delay_cycle <= 32'b0;
                    latency_count <= 32'b0;
                end
                end
                wait_t: begin
                    if (in_psel && in_penable) begin
                        latency_count <= latency_count + 32'b1;

                        if (out_pready) begin
                            prdata <= out_prdata;
                            pslverr <= out_pslverr;

                            if (((delay_cycle + ratio * scale) / scale) > (latency_count + 32'b1)) begin
                                delay_cycle <= (delay_cycle + ratio * scale) / scale - latency_count - 32'b1;
                                state <= delay_t;
                            end
                            else begin
                                delay_cycle <= 32'b0;
                                state <= resp_t;
                            end
                        end
                        else begin
                            delay_cycle <= delay_cycle + ratio * scale;
                        end
                    end
                    else begin
                        state <= idle_t;
                        delay_cycle <= 32'b0;
                        latency_count <= 32'b0;
                    end
                end

                delay_t: begin
                    if (delay_cycle > 32'b1) begin
                        delay_cycle <= delay_cycle - 32'b1;
                    end
                    else begin
                        delay_cycle <= 32'b0;
                        state <= resp_t;
                    end
                end

                resp_t: begin
                    if (in_psel && in_penable) begin
                        state <= idle_t;
                    end
                end

                default: begin
                    state <= idle_t;
                end
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

    assign in_pready   = (state == resp_t) ? 1'b1 : 1'b0;
    assign in_prdata   = (state == resp_t) ? prdata : 32'b0;
    assign in_pslverr  = (state == resp_t) ? pslverr : 1'b0;

endmodule

