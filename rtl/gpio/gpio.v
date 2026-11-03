module gpio #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input                           iCLK, iRST,
    input                           w_REQ, r_REQ,
    input       [DATA_WIDTH-1:0]    w_DATA,
    input       [ADDR_WIDTH-1:0]    w_ADDR, r_ADDR,
    output reg  [DATA_WIDTH-1:0]    r_DATA,
    
    /* interfaces */
    input       [15:0]               iSW,
    output reg  [15:0]               oLED
);

    always @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            r_DATA <= 32'h00000000;
            oLED   <= 16'h0000;
        end else begin
            if (w_REQ) begin
                oLED             <= w_DATA;
            end else if (r_REQ) begin
                r_DATA          <= iSW;
            end
        end
    end

endmodule