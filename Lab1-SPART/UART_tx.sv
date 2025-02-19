module UART_tx(clk, rst_n, TX, trmt, tx_data, tx_done, baud_rate);
input clk, rst_n, trmt;
input [7:0]tx_data;
input [15:0] baud_rate;
output TX;
output reg tx_done;

logic init, shift, transmitting, set_done;
reg [3:0]bit_cnt;
reg [15:0]baud_cnt;
reg [8:0]tx_shift_reg;
typedef enum reg{INIT, TRANSMITTING}state_t;
state_t state, nxt_state;


//Counter
always_ff@(posedge clk)begin
  if(init)
    bit_cnt <= '0;
  else if(shift)
    bit_cnt <= bit_cnt + 1;
end

//Baud
always_ff@(posedge clk)begin
  if(init|shift)
    baud_cnt <= '0;
  else if(transmitting)
    baud_cnt <= baud_cnt + 1;
end

assign shift = (baud_cnt == baud_rate) ? 1'b1 : 1'b0;

//Shift
always_ff@(posedge clk, negedge rst_n)begin
  if(!rst_n)
    tx_shift_reg <= '1;
  else if(init)
    tx_shift_reg <= {1'b1, tx_data, 1'b0};
  else if(shift)
    tx_shift_reg <= {1'b1, tx_shift_reg[8:1]};
end

assign TX = tx_shift_reg[0];

//Assert Done
always_ff@(posedge clk, negedge rst_n)begin
  if(!rst_n)
    tx_done <= 1'b0;
  else if(init|transmitting)
    tx_done <= 1'b0;
  else if(set_done)
    tx_done <= 1'b1;
end

/////////STATE MACHINE/////////////
always_ff@(posedge clk, negedge rst_n)begin
  if(!rst_n)
    state <= INIT;
  else
    state <= nxt_state;
end

always_comb begin
  nxt_state = state;
  init = 0;
  transmitting = 0;
  set_done = 0;

  case(state)
    TRANSMITTING: if(bit_cnt != 4'h9)
	transmitting = 1;
    else begin
	set_done = 1;
	nxt_state = INIT;
    end
  
    ////////default -> INIT///////
    default: if(trmt)begin
	init = 1;
	nxt_state = TRANSMITTING;
    end
  endcase
end

endmodule
