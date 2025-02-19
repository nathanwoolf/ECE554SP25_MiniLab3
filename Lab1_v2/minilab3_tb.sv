module minilab3_tb ();

logic    clk, 
        rst;
// singals tying spart and driver together 
logic   iocs, 
        iorw,
        rda,
        tbr, 
        iocs_r, 
        iorw_r,
        rda_r,
        tbr_r,
        rxd_r;
logic [1:0] ioaddr, ioaddr_r, br_cfg;
wire [7:0] databus, databus_r; 

// I/O from spart
logic txd, rxd;

//tb internal singals 
logic [9:0] shift_reg;
logic [7:0] test_word;

spart spart0(   .clk(clk),
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

spart spart1(   .clk(clk),
                .rst(rst),
                .iocs(iocs_r),
                .iorw(iorw_r),
                .rda(rda_r),
                .tbr(tbr_r),
                .ioaddr(ioaddr_r),
                .databus(databus_r),
                .txd(rxd_r),
                .rxd(txd)
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
    $display("Setting Baud Rates");
    clk = 0; 
    br_cfg = 2'b00;      //default to the lowest baud rate

    @(negedge clk) rst = 1;
    @(negedge clk) rst = 0;

    ////////////////////////////////////////////////////////////////
    // TEST: SEND A WORD THROUGH THE COMMUNICATION UNIT at 9600 BAUD
    ////////////////////////////////////////////////////////////////
    // HEX: 74 65 73 74 69 6E 67 
    
    //force remote spart unit to baud rate - start w/ low bits 
    repeat (2) @(posedge clk);
    ioaddr_r = 2'b10;
    force databus_r = 8'ha3;
    @(negedge clk) begin 
        iocs_r = 1; 
        iorw_r = 0;
    end 

    repeat (1) @(negedge clk);

    //do same thing for high bits of baud
    ioaddr_r = 2'b11;
    force databus_r = 8'h27;
    @(negedge clk) begin 
        iocs_r = 1; 
    end 
    @(posedge clk) begin 
        release databus_r;
        iocs_r = 0;
	iorw_r = 1;
    end

    $display("TEST: Sending word 8'h74");
    test_word = 8'h74;
    shift_reg = {1'b1, test_word, 1'b0};

    rxd = shift_reg[0];

    for (int i = 1; i < 10; i++) begin
        @(posedge spart0.baud_en) begin 
            rxd = shift_reg[i];
        end
    end

    @(posedge spart0.baud_en) rxd = shift_reg[9];

    fork
        begin : init_rx_to
            repeat (75000) @(posedge clk);
            $display("ERROR: timeout on wait for rda to go high");
            $stop();
        end : init_rx_to
        begin
            @(posedge rda) begin
                disable init_rx_to;
                if (spart0.rx_shift_reg[7:0] !== 8'h74) begin 
                    $display("ERROR: signal recieved was not the same as the signal given"); 
                    $display("\tExpected: 8'h74, Received: 8'h%h", spart0.rx_shift_reg[7:0]);
                    $stop();
                end 
                $display("SUCCESS: signal recieved was the same as the signal given");
            end
        end
    join 
    

    //attempting to get remote spart to go into rx state
    @(negedge clk) begin 
        ioaddr_r = 2'b00;
        iocs_r = 1;
    end


    fork
        begin : init_tx_to
            repeat (150000) @(posedge clk);
            $display("ERROR: timeout on wait for remote rda to go high");
            $stop();
        end : init_tx_to
        begin
            @(posedge spart1.data_rdy) begin
                disable init_tx_to;
                if (spart1.rx_shift_reg[7:0] !== 8'h74) begin 
                    $display("ERROR: signal transmitted was not the same as the signal given"); 
                    $display("\tExpected: 8'h74, Received: 8'h%h",spart1.rx_shift_reg[7:0]);
		    $stop();
                end 
                $display("SUCCESS: signal transmitted was the same as the signal given");
            end
        end
    join 

    repeat (1000) @(posedge clk);
    $display("TEST: Sending word 8'h47");
    test_word = 8'h47;
    shift_reg = {1'b1, test_word, 1'b0};

    rxd = shift_reg[0];

    for (int i = 1; i < 10; i++) begin
        @(posedge spart0.baud_en) begin 
            rxd = shift_reg[i];
        end
    end
    @(posedge spart0.baud_en) rxd = shift_reg[9];

    fork
        begin : init_rx_to2
            repeat (75000) @(posedge clk);
            $display("ERROR: timeout on wait for rda to go high");
            $stop();
        end : init_rx_to2
        begin
            @(posedge rda) begin
                disable init_rx_to2;
                if (spart0.rx_shift_reg[7:0] !== 8'h47) begin 
                    $display("ERROR: signal recieved was not the same as the signal given"); 
                    $display("\tExpected: 8'h47, Received: 8'h%h", spart0.rx_shift_reg[7:0]);
                    $stop();
                end 
                $display("SUCCESS: signal recieved was the same as the signal given");
            end
        end
    join 
    

    //attempting to get remote spart to go into rx state
    @(negedge clk) begin 
        ioaddr_r = 2'b00;
        iocs_r = 1;
    end


    fork
        begin : init_tx_to2
            repeat (150000) @(posedge clk);
            $display("ERROR: timeout on wait for remote rda to go high");
            $stop();
        end : init_tx_to2
        begin
            @(posedge spart1.data_rdy) begin
                disable init_tx_to2;
                if (spart1.rx_shift_reg[7:0] !== 8'h47) begin 
                    $display("ERROR: signal transmitted was not the same as the signal given"); 
                    $display("\tExpected: 8'h47, Received: 8'h%h",spart1.rx_shift_reg[7:0]);
		    $stop();
                end 
                $display("SUCCESS: signal transmitted was the same as the signal given");
            end
        end
    join 
    $stop();
end


always #5 clk = ~clk;

endmodule