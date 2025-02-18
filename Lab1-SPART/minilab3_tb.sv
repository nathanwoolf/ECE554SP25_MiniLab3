module minilab3_tb ();

logic    clk, 
        rst;
// singals tying spart and driver together 
logic    iocs, 
        iorw,
        rda,
        tbr;
logic [1:0] ioaddr, br_cfg;
wire [7:0] databus; 

// I/O from spart
logic txd, rxd;

//tb internal singals 
logic [9:0] test_word;

spart_test spart0(   .clk(clk),
                .rst(rst),
                .iocs(iocs),
                .iorw(iorw),
                .rda(rda),
                .tbr(tbr),
                .ioaddr(ioaddr),
                .databus(databus),
                .txd(txd),
                .rxd(rxd)
            );

// Instantiate your driver here
driver driver0( .clk(clk),
                .rst(rst),
                .br_cfg(br_cfg),
                .iocs(iocs),
                .iorw(iorw),
                .rda(rda),
                .tbr(tbr),
                .ioaddr(ioaddr),
                .databus(databus)
            );

initial begin 
    clk = 0; 
    rst = 1; 
    br_cfg = 2'b00;      //default to the lowest baud rate
    rxd = 1'b1;

    @(negedge clk) rst = 0;

    ////////////////////////////////////////////////////////////////////////////////
    // TEST: CHANGE BAUD RATE DIP SETTING -> VERIFY THAT WAS READ OVER TO SPART UNIT
    ////////////////////////////////////////////////////////////////////////////////
    $display("TEST: CHANGE BAUD RATE DIP SETTING -> VERIFY THAT WAS READ OVER TO SPART UNIT");
    // first check was the original baud rate sent to the spart unit   
    repeat (5) @(posedge clk);
    if (spart0.div_buf !== 16'h028A) begin 
        $display("ERROR: baud rate was not set to 4800");
        $stop();
    end else
        $display("SUCCESS: baud rate was set to 4800 in spart unit");

    // now change the baud rate to 9600
    @(negedge clk) br_cfg = 2'b01;
    repeat (10) @(posedge clk);
    if (spart0.div_buf !== 16'h0145) begin 
        $display("ERROR: baud rate was not set to 9600");
        $stop();
    end else 
        $display("SUCCESS: baud rate was set to 9600 in spart unit");


    repeat(5) @(posedge clk);
    ///////////////////////////////////////////////////
    // TEST: SEND A WORD THROUGH THE COMMUNICATION UNIT
    ///////////////////////////////////////////////////
    test_word = {1'b1, 8'hA5, 1'b0};            // ** we have to build in start and stop bits **

    @(negedge clk) rxd = test_word[0]; 

    $display("TEST: SEND A WORD THROUGH THE COMMUNICATION UNIT");
    // two clk cycles after each shift signal, we'll change what rx is looking at
    for (int i = 1; i < 9; i++) begin 
       @(negedge spart0.data_transfer.iTX.shift)
        rxd = test_word[i];
    end

/*
    fork
        begin : init_rx_to
            repeat (1000) @(posedge clk);
            $display("ERROR: timeout on wait for rda to go high");
            $stop();
        end : init_rx_to
        begin
            @(posedge rda) begin
                disable init_rx_to;
                if (spart0.receive_data !== test_word) begin 
                    $display("ERROR: signal recieved by SPART was not the same as the signal sent"); 
                    $stop();
                end 
                $display("SUCCESS: signal recieved by SPART was the same as the signal sent");
            end
        end
    join
    */
 	repeat (10000) @(posedge clk);
	$stop();
end


always #5 clk = ~clk;

endmodule