//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    
// Design Name: 
// Module Name:    driver 
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
module driver(
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

typedef enum reg[2:0]{IDLE, RECEIVE, TRANSMIT, BR_CONFIG_TOP, BR_CONFIG_BOTTOM}state_t;
state_t state, nxt_state;

logic [15:0] baud_rate;
logic[7:0] read_data;
logic [1:0] br_cfg_prev;
logic rd_dbus, ld_dbus, ld_brt, ld_brb, br_change, br_consume;

//Detect change in baud rate, update spart baud rate if change
always_ff@(posedge clk, posedge rst)begin
  if(rst) begin
    br_cfg_prev <= '0;
  end
  else begin
    br_cfg_prev <= br_cfg;
  end
end

always_ff@(posedge clk, posedge rst)begin
  if(rst) begin
    br_change <= 1'b1;
  end
  else if(br_cfg != br_cfg_prev) begin
    br_change <= 1'b1;
  end
  else if(br_consume) begin
    br_change <= 1'b0;
  end
end
//assign br_change = (br_cfg == br_cfg_prev) ? 1'b0 : 1'b1;

//Select value stored in spart divisor buffer based on baud rate
always_ff@(posedge clk, posedge rst)begin
  if(rst)
    baud_rate <= '0;
  else begin
    case(br_cfg)
      2'b00: baud_rate <= 16'h028A;
      2'b01: baud_rate <= 16'h0145;
      2'b10: baud_rate <= 16'h00A2;
      2'b11: baud_rate <= 16'h0050;
    endcase
  end
end

//Read the data bus if data is available
always_ff@(posedge clk, posedge rst) begin
  if(rst)
    read_data <= '0;
  else if(rd_dbus)
    read_data <= databus;
end

//Load the databus with required data based on state
assign databus = (ld_brt) ? baud_rate[15:8] : (ld_brb) ? baud_rate[7:0] : (ld_dbus) ? read_data : 8'hzz;

/*
always_ff @(posedge clk) begin
  if(ld_brt)
    databus <= baud_rate[15:8];
  if(ld_brb)
    databus <= baud_rate[7:0];
  if(ld_dbus)
    databus <= read_data;
end */

//Hold tba, rda signal until consumed in state machine
logic tbr_wait, rda_wait, tbr_consume, rda_consume, rda_prev, tbr_prev;

always_ff@(posedge clk, posedge rst)begin
  if(rst) begin
    rda_prev <= 1'b0;
//   tbr_prev <= 1'b0;
  end
  else begin
    rda_prev <= rda;
//    tbr_prev <= tbr;
  end
end

always_ff@(posedge clk, posedge rst)begin
  if(rst)begin
    tbr_wait <= 0;
    rda_wait <= 0;
  end
  else if(rda & !rda_prev)begin
    rda_wait <= 1'b1;
	 end
  else if(tbr)begin
    tbr_wait <= 1'b1;
	 end
  else if(rda_consume)begin
    rda_wait <= 1'b0;
	 end
  else if(tbr_consume)begin
    tbr_wait <= 1'b0;
	 end
end

/////////STATE MACHINE/////////////
always_ff@(posedge clk, posedge rst)begin
  if(rst)
    state <= IDLE;
  else
    state <= nxt_state;
end

always_comb begin
  nxt_state = state;
  iocs = 0;
  iorw = 0;
  ioaddr = 0;
  rd_dbus = 0;
  ld_dbus = 0;
  ld_brt = 0;
  ld_brb = 0;
  rda_consume = 0;
  tbr_consume = 0;
  br_consume = 0;

  case(state)
    //If data available, read and store data
    RECEIVE: begin
      rd_dbus = 1'b1;
      iocs = 1'b1;
      ioaddr = 2'b00;
      iorw = 1'b1;
      if(!rda)
        nxt_state = IDLE;
    end
    
    //If transmit ready, send stored bit
    TRANSMIT: begin
      ld_dbus = 1'b1;
      iocs = 1'b1;
      ioaddr = 2'b00;
      iorw = 1'b0;
      if(!tbr)
        nxt_state = IDLE;
    end

    //If baud rate changed, send high bits then low bits
    BR_CONFIG_TOP:begin
      ld_brt = 1'b1;
      iocs = 1'b1;
      ioaddr = 2'b11;
      iorw = 1'b0;
      nxt_state = BR_CONFIG_BOTTOM;
    end
    
    BR_CONFIG_BOTTOM:begin
      ld_brb = 1'b1;
      iocs = 1'b1;
      ioaddr = 2'b10;
      iorw = 1'b0;
      br_consume = 1'b1;
      nxt_state = IDLE;
    end
    
    ////////default -> IDLE///////
    //select state based on signals
    default: begin
     if(br_change)begin
        nxt_state = BR_CONFIG_TOP;
     end
     else if(rda_wait)begin
        rda_consume = 1'b1;
       nxt_state = RECEIVE;
     end     
     else if(tbr_wait)begin
        tbr_consume = 1'b1;
        nxt_state = TRANSMIT;
     end

     end
  endcase
end

endmodule
