/**
    tb_cpu.v -- Testbench for the bare CPU entity in project ION.

    Derived somewhat remotely from the testbench in project Pico-RISCV:
        https://github.com/cliffordwolf/picorv32


    # Configuration macros
    ~~~~~~~~~~~~~~~~~~~~~~

    TEST:       Test to be run (dir. under '../../sw'). Defaults to 'cputest'.
    TIMEOUT:    Timeout in clock cycles. Defaults to 80000.


    # Simulated environment
    ~~~~~~~~~~~~~~~~~~~~~~~

    There's a single block of simulated memory of 128KB that is connected to 
    both code and data spaces:

    Code address    0xbfc00000
    Data address    0xa0000000

    (Actually, there's no address decoding in this TB and the memory block is 
    just mirrored all over the memory space(s) but those are the addresses that 
    should be used in the link file.)

    Two I/O registers are simulated on the data bus:

    0xffff8000      Console output. 
    0xffff8018      Test outcome. Write anything to end test.


    TODO Interrupt simulation register missing.
    TODO Test outcome criteria & console output explanation missing.
*/

`timescale 1 ns / 1 ps

//--- Config macros (cmdline overrideable) -------------------------------------

// Test name (used to infer object code path in project dirs).
`ifndef TEST
`define TEST cputest
`endif

// Test timeout in clock cycles.
`ifndef TIMEOUT
`define TIMEOUT 80000
`endif


// Non-overrideable test configuration stuff.
`define SWDIR "../../sw/"
`define STRINGIFY(x) `"x`"
`define TEST_STR `STRINGIFY(`TEST)

// Address of concole output register.
`define IO_CON_OUT          32'hffff8000
// Address of test termination register.
`define IO_TERMINATE        32'hffff8018
// Size of simulated memory in bytes.
`define RAM_SIZE_BYTES      (128*1024)
// I'll have to clean this up eventually and do a real memory interface. 
`define RAM_BLOCK_ADDR_MASK (32'h0001ffff)
// Get wait state config from command line, if given.
`ifndef WAIT_STATES
`define WAIT_STATES 0
`endif


//------------------------------------------------------------------------------

module testbench;

    // TODO For the time being, both buses will have the same wait state config
    // and both will have the same # of ws in all cycles.
    localparam CODE_WAIT_STATES = `WAIT_STATES;
    // TODO And data bus does not have any wait states.
    localparam DATA_WAIT_STATES = 0;//`WAIT_STATES;


    reg clk = 1;
    reg reset = 1;

    // Clock.
    always #5 clk = ~clk;


    //--- UUT instantiation ----------------------------------------------------

    wire [31:0] code_addr;
    wire [ 1:0] code_trans;
    reg         code_ready;
    reg  [ 1:0] code_resp;
    reg  [31:0] code_rdata;

    wire [31:0] data_addr;
    wire [ 1:0] data_trans;
    wire [ 2:0] data_size;
    reg         data_ready;
    reg  [ 1:0] data_resp;
    reg  [31:0] data_rdata;
    wire [31:0] data_wdata;
    wire        data_write;
    reg         data_wpending;
    reg         data_rpending;
    reg  [ 1:0] data_wsize;
    reg  [31:0] data_waddr;
    reg  [31:0] mem_op_pc; 
    reg  [31:0] mem_rdata;
    reg  [ 4:0] hw_irq;

    cpu #(
        
    )
    uut (
        .CLK          (clk),
        .RESET_I      (reset),

        /* Code AHB interface. Only 32b RD supported so some signals omitted. */
        .CADDR_O        (code_addr),
        .CTRANS_O       (code_trans),
        .CRDATA_I       (code_rdata),
        .CREADY_I       (code_ready),
        .CRESP_I        (code_resp),

        .DADDR_O        (data_addr),
        .DTRANS_O       (data_trans),
        .DSIZE_O        (data_size),
        .DRDATA_I       (data_rdata),
        .DWDATA_O       (data_wdata),
        .DWRITE_O       (data_write),
        .DREADY_I       (data_ready),
        .DRESP_I        (data_resp),

        .HWIRQ_I        (hw_irq)
    );



    //-- Logs ------------------------------------------------------------------

    // Make our logging life easier by zeroing the regbank before the test.
    initial
    begin
        for (i=0; i<31; i = i+1) begin
            uut.s42r_rbank[i] = 32'h0;
        end        
    end 

    // CPU register bank delta log.
    reg [31:0] s23r_pc;
    reg [31:0] s34r_pc;
    always @(posedge clk) begin
        #1;
        if (uut.s4_en & uut.s34r_wb_en & ~uut.s4_st) begin
            if ((uut.s34r_rd_index != 0) && 
                (uut.s42r_rbank[uut.s34r_rd_index] !== uut.s4_wb_data)) begin
                $fwrite(logfile,
                    "(%08H) [%02h]=%08h\n", s34r_pc, uut.s34r_rd_index, uut.s4_wb_data); 
            end   
        end
        if (uut.s4_en & uut.s34r_wb_csr_en & ~uut.s4_st) begin
            if ((uut.s34r_csr_xindex != 4'hf)) begin
                $fwrite(logfile,
                    "(%08H) [%02h]=%08h\n", 0, uut.s34r_csr_xindex, uut.s34r_alu_res); 
            end   
        end 
        if (~uut.s2_st) s23r_pc <= uut.s12r_pc;
        if (~uut.s3_st) s34r_pc <= s23r_pc;
    end

    // Waveform display visual aid: mark passage over some address.
    reg mark;
    always @(*) begin
        mark = uut.s01r_pc == 32'hbfc001e4;
    end

    // Waveform display visual aid: cycle count reference.
    integer cycle_counter;
    always @(posedge clk) begin
        cycle_counter <= (~reset) ? cycle_counter + 1 : 0;
    end


    //-- Memory ----------------------------------------------------------------

    // Memory block initialized with test binary. 
    // Wired to code and data buses with no arbitration (virtual 2-port RAM).
    reg [31:0] memory [0:`RAM_SIZE_BYTES/4-1];
    integer a;
    initial begin 
        $readmemh({`SWDIR, `TEST_STR, "/software.hex"}, memory);
    end


    //~~ Read port connected to code bus ~~~~~~~~~

    integer code_wstate_ctr;
    reg [31:0] code_addr_reg;
    // Wait state counter.
    always @(posedge clk) begin
        if (reset) begin
            code_wstate_ctr <= 0;          
        end
        else begin
            if ((code_trans == 2'b10) && (code_wstate_ctr==0)) begin
                code_wstate_ctr <= CODE_WAIT_STATES;
            end
            else begin
                code_wstate_ctr <= (code_wstate_ctr > 0)? code_wstate_ctr - 1 : 0;
            end  
        end
    end
    // Address register (code bus is AHB-alike).
    always @(posedge clk) begin
        if (reset) begin
            code_addr_reg <= 32'h0;          
        end
        else if ((code_trans == 2'b10) && (code_wstate_ctr==0)) begin
            code_addr_reg <= code_addr;
        end
    end
    // Actual read port. Drive data bus for a single clock cycle per transfer.
    always @(posedge clk) begin
        # 0.1;
        code_ready = (code_wstate_ctr == 0);
        code_resp = 2'b00;         
        code_rdata = code_ready? memory[(code_addr_reg & `RAM_BLOCK_ADDR_MASK) >> 2] :  32'h0; 
    end

    //~~ Read/Write port connected to data bus ~~~~~~~~

    integer data_wstate_ctr;
    reg [31:0] data_addr_reg;
    // Wait state counter.
    always @(posedge clk) begin
        #0.1;
        if (reset) begin
            data_wstate_ctr <= 0;
            mem_op_pc <= 32'h0;
            data_addr_reg <= 32'h0;
        end
        else begin
            if ((data_trans == 2'b10) && (data_wstate_ctr==0)) begin
                data_wstate_ctr <= DATA_WAIT_STATES;
                mem_op_pc <= s23r_pc;
                data_wpending <= data_write;
                data_rpending <= ~data_write;
                data_waddr <= data_addr;
                data_wsize <= data_size;
                mem_op_pc <= s23r_pc; 
                data_addr_reg <= data_addr; 
            end
            else if (data_wstate_ctr > 0) begin
                data_wstate_ctr <= data_wstate_ctr - 1;
            end  
            else begin
                data_wpending <= 1'b0;
                data_rpending <= 1'b0;
            end
        end
    end
    // Actual read port. Drive data bus for a single clock cycle per transfer.
    always @(posedge clk) begin
        # 0.1;
        data_ready = (data_wstate_ctr == 0);
        data_resp = 2'b00;
        if (data_wstate_ctr==0) begin
            if (data_wpending) begin
                write_data_task(data_waddr, data_wsize, data_wdata);
            end
            else if (data_rpending) begin
                read_data_task(data_waddr, data_wsize, data_rdata);
            end
        end
    end

    //~~ Simulated I/O on data bus ~~~~~~~~
    always @(posedge clk) begin
        if (data_trans == 2'b10 && data_write==1'b1) begin
            // Simulated console output register.
            if (data_addr == `IO_CON_OUT) begin
                #1;
                $fwrite(confile, "%c", data_wdata[31:24]);    
                $write("%c", data_wdata[31:24]);
                $fflush();
            end
            // Simulated test outcome register.
            if (data_addr == `IO_TERMINATE) begin
                #1;
                $display("Simulation terminated by SW command.");
                $finish;
            end
        end 
    end 


    //-- Interrupts ------------------------------------------------------------

    initial hw_irq = 0;

    // TODO HW interrupts not simulated.
    always @(*)
    begin
        hw_irq = 0;
    end


    //-- Test driver block -----------------------------------------------------

    integer i;
    integer logfile;
    integer confile;
    initial begin
        logfile = $fopen("rtl_sim_log.txt","w");
        confile = $fopen("console_log.txt","w");
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);
        for (i=1; i<32; i = i + 1) $dumpvars(0, testbench.uut.s42r_rbank[i]);
        
        // Assert reset for a long while...
        reset <= 1'b1;    
        repeat (10) @(posedge clk);
        reset <= 1'b0;
        // ...then let the test run until it terminates the sim by writing 
        // to the test control register OR it times out.
        repeat (`TIMEOUT) @(posedge clk);
        $display("TIMEOUT");
        $finish;
    end

    //-- Utility tasks ---------------------------------------------------------

    task read_data_task([31:0] addr, [1:0] size, output [31:0] rdata);
    reg [31:0] mem_rdata;
    begin
        // Data from memory block goes straight into AHB bus.
        rdata = memory[(addr & `RAM_BLOCK_ADDR_MASK) >> 2];

        // Now log the memory load with the non-used byte lanes zeroed.
        //mem_rdata = read_data_mux(data_wsize, data_waddr[1:0], data_rdata);
        mem_rdata = 32'h0;
        case ({size, addr[1:0]})
        4'b0000: mem_rdata[7:0]  = rdata[31:24];   
        4'b0001: mem_rdata[7:0]  = rdata[23:16];
        4'b0010: mem_rdata[7:0]  = rdata[15: 8];
        4'b0011: mem_rdata[7:0]  = rdata[ 7: 0];
        4'b0100: mem_rdata[15:0] = rdata[31:16];
        4'b0110: mem_rdata[15:0] = rdata[15: 0];
        default: mem_rdata       = rdata;            
        endcase
        $fwrite(logfile, 
            "(%08h) [%08h] <%1d>=%08h RD\n", 
            mem_op_pc, addr, 2**size, mem_rdata);
    end 
    endtask

    task write_data_task([31:0] addr, [1:0] size, [31:0] data);
    reg [31:0] wdata;
    begin
        // Update only the relevant byte lanes in the memory block.
        wdata = memory[(addr & 32'h0003ffff) >> 2];
        case ({size, addr[1:0]})
        4'b0011: wdata[ 7: 0] = data[ 7: 0];   
        4'b0010: wdata[15: 8] = data[15: 8];
        4'b0001: wdata[23:16] = data[23:16];
        4'b0000: wdata[31:24] = data[31:24];
        4'b0110: wdata[15: 0] = data[15: 0];
        4'b0100: wdata[31:16] = data[31:16];
        default: wdata        = data;
        endcase
        memory[(addr & 32'h0003ffff) >> 2] <= wdata;

        // Now log the memory write with the non-used byte lanes zeroed.
        wdata = 0;
        case ({size, addr[1:0]})
        4'b0011: wdata[ 7: 0] = data[ 7: 0];   
        4'b0010: wdata[15: 8] = data[15: 8];
        4'b0001: wdata[23:16] = data[23:16];
        4'b0000: wdata[31:24] = data[31:24];
        4'b0110: wdata[15: 0] = data[15: 0];
        4'b0100: wdata[31:16] = data[31:16];
        default: wdata        = data;
        endcase        $fwrite(logfile,
            "(%08h) [%08h] <%1d>=%08h WR\n", mem_op_pc, addr, 2**size, wdata);
    end
    endtask


endmodule
