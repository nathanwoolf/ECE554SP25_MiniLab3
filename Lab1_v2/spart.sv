//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:   
// Design Name: 
// Module Name:    spart 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module spart(
    input clk,
    input rst,
    input iocs,
    input iorw,         // 1: spart to driver       0: driver to spart
    output logic rda,
    output logic tbr,
    input [1:0] ioaddr,
    inout [7:0] databus,
    output txd,
    input rxd);

logic [15:0] div_buf;
always_ff @(posedge clk, posedge rst) begin 
    if (rst) begin 
        div_buf <= 16'b0;
    end
    else if (iocs & !iorw) begin
        case (ioaddr)
            2'b10 : div_buf[7:0] <= databus;
            2'b11 : div_buf[15:8] <= databus;
        endcase
    end
end

// baud gen signals and logic
logic [15:0] baud_cnt;
logic [3:0] bit_cnt; 
logic baud_en;
logic[7:0] tx_data;

// shift registers signals
logic [8:0] tx_shift_reg, rx_shift_reg;
logic tx, rx, rxd_ff, rxd_dff, start, data_rdy, tx_init;
logic tx_stp; 

// baud counter for baud rate generator
always_ff @(posedge clk) begin
    if (start) 
        baud_cnt <= (tx_init) ? (div_buf >> 1) : div_buf;
    else if (baud_en)
        baud_cnt <= div_buf; 
    else if (tx | rx)
        baud_cnt <= baud_cnt - 1;    
end

// bit count register for Tx and Rx
always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        bit_cnt <= 4'b0;
    else if (start) 
        bit_cnt <= 4'b0;
    else if (!tx & !rx)
        bit_cnt <= 4'b0;
    else if (baud_en) 
        bit_cnt <= bit_cnt + 1;
end 

assign baud_en = (baud_cnt == 0) ? 1 : 0;

assign databus = (ioaddr == 2'b00 & iorw & iocs) ? rx_shift_reg[7:0] : 'Z;

always_ff @(posedge clk, posedge rst) begin
    if (rst) begin 
        rxd_ff <= 1'b1;
        rxd_dff <= 1'b1;
    end
    else begin
        rxd_ff <= rxd;
        rxd_dff <= rxd_ff;
    end
end

// shift reg for rx
always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        rx_shift_reg <= 9'h1FF;
    else if (rx & baud_en) begin
        rx_shift_reg <= {rxd_dff, rx_shift_reg[8:1]};
    end
end

// shift reg for tx 
always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        tx_shift_reg <= 9'h1FF;
    else if (tx & start) 
        tx_shift_reg <= {databus, 1'b0};       //appending zero for start signal to remote device
    else if (tx & baud_en) begin
        tx_shift_reg <= {1'b1, tx_shift_reg[8:1]};
    end
end

assign txd = tx_shift_reg[0];

always_ff @(posedge clk, posedge rst) begin
    if (rst) begin 
        rda <= 1'b0; 
        tbr <= 1'b0;
    end 
    else begin 
        rda <= data_rdy; 
        tbr <= tx_stp; 
    end
end

// ************************** STATE MACHINE **************************
typedef enum reg [1:0] {IDLE, TX, RX} state_t;
state_t state, next_state;

always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        state <= IDLE;
    else
        state <= next_state;
end

always_comb begin 
    tx = 1'b0; 
    rx = 1'b0;
    start = 1'b0;
    tx_init = 1'b0;
    data_rdy = 1'b0;   
    tx_stp = 1'b0; 
    next_state = state;

    case(state)
        IDLE: begin 
            if (~rxd_ff & iocs) begin 
                start = 1'b1;
                next_state = RX;
            end
            else if (tbr & iocs) begin 
                tx = 1'b1;
                tx_init = 1'b1;
                start = 1'b1;
                next_state = TX;
            end
        end

        TX: begin 
            tx = 1'b1;
            if (bit_cnt == 10) begin 
                tx_stp = 1'b1; 
                next_state = IDLE;
            end
        end 

        RX : begin 
            rx = 1'b1;
            if (bit_cnt == 10) begin
                if (rxd_ff) begin 
                    data_rdy = 1'b1;
                    next_state = IDLE;
                end
                else begin 
                    start = 1'b1;
                    next_state = RX;
                end  
            end 
        end 

    endcase 
end
endmodule