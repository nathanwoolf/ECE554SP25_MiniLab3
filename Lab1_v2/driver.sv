module driver (
    input clk,
    input rst,
    input [1:0] br_cfg,
    output logic iocs,
    output logic iorw,
    input rda,
    input tbr,
    output logic [1:0] ioaddr,
    inout [7:0] databus
); 

//  DIP Setting to Baud Rate mapping (comes in through I/O address)
//  00 -> 4800  ->  650 -> 0x28A
//  01 -> 9600  ->  325 -> 0x145
//  10 -> 19200 ->  162 -> 0xA2
//  11 -> 38400 ->  80  -> 0x50

//  IOADDR bit mappings
//  00 -> Tx buffer (R/W = 0) : Rx buffer (R/W = 1)
//  01 -> Status register (R/W = 1)
//  10 -> DB (low) division buffer
//  11 -> DB (high) division buffer

//Detect change in baud rate, update spart baud rate if change
logic [1:0] br_cfg_prev;
logic ld_brt, ld_brb, ld_dbus, rd_dbus;
logic [15:0] baud_rate;
reg [7:0] read_data;

always_ff@(posedge clk, posedge rst)begin
  if(rst)
    br_cfg_prev <= '0;
  else
    br_cfg_prev <= br_cfg;
end

always_ff@(posedge clk, posedge rst)begin
  if(rst)
    baud_rate <= '0;
  else begin
    case(br_cfg)
      2'b00: baud_rate <= 16'h27A3;
      2'b01: baud_rate <= 16'h1458;
      2'b10: baud_rate <= 16'h0A2C;
      2'b11: baud_rate <= 16'h0516;
    endcase
  end
end

assign databus = (!iorw) ? read_data : 'z;
typedef enum reg [2:0] {IDLE, WAIT, PROG_LOW, PROG_HIGH, CMD_RX, CMD_TX} state_t;
state_t state, nxt_state;  

always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        state <= WAIT;
    else
        state <= nxt_state;
end

always_comb begin 
    iocs = 1'b0;
    iorw = 1'b0;
    ioaddr = 2'b00;
    ld_brb = 1'b0;
    ld_brt = 1'b0;
    ld_dbus = 1'b0;
    read_data = 'z;
    nxt_state = state;

    case (state) 
        IDLE: begin 
            if (br_cfg !== br_cfg_prev) begin 
                nxt_state = PROG_LOW;
            end
            else if (rda) begin 
                iocs = 1'b1;
                iorw = 1'b1;
                nxt_state = CMD_RX;
            end
        end

        WAIT: begin 
            nxt_state = PROG_LOW;
        end

        PROG_LOW: begin 
            ld_brb = 1'b1;
            iocs = 1'b1;
            ioaddr = 2'b10;
            iorw = 1'b0;
            read_data = baud_rate[7:0];
            nxt_state = PROG_HIGH;
        end

        PROG_HIGH: begin 
            ld_brt = 1'b1;
            iocs = 1'b1;
            ioaddr = 2'b11;
            iorw = 1'b0;
            read_data = baud_rate[15:8];
            nxt_state = IDLE;
        end

        CMD_RX: begin 
           iocs = 1'b1;
           ioaddr = 2'b00;
           iorw = 1'b1;
           read_data = databus;
           if (rda) begin 
                rd_dbus = 1'b1;
                iorw = 1'b0;
                nxt_state = CMD_TX;
            end
        end

        CMD_TX: begin 
            iocs = 1'b1;
            ioaddr = 2'b00;
            iorw = 1'b0;
            if (tbr) begin
		iocs = 1'b0;
		nxt_state = IDLE;
	  end
        end
    endcase
end
endmodule