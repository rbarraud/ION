/*
    mcu.v -- Microcontroller built around ION CPU.

    WARNING: THIS IS ONLY A SYNTHESIS DUMMY!

    Eventually this will really be a microcontroller. For the time being it 
    is only a stub meant as a synthesis harness: there's only enough dummy 
    logic in place to prevent the synth tool form optimizing away large chunks 
    of the CPU.
*/


module mcu # (
        // Size of Code TCM in 32-bit words.
        parameter   OPTION_CTCM_NUM_WORDS = 1024
    )
    (
        input               CLK,
        input               RESET_I,

        input       [31:0]  DEBUG_I,
        output reg  [31:0]  DEBUG_O
    ); 


    //==== CPU instantiation ===================================================

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
    reg  [ 1:0] data_wsize;
    reg  [31:0] data_waddr;
    reg  [31:0] mem_op_pc; 
    reg  [31:0] mem_rdata;
    reg  [ 4:0] hw_irq;

    reg [31:0] ctcm [0:OPTION_CTCM_NUM_WORDS-1];
    reg [10:0] ctcm_addr;
    reg [31:0] ctcm_data;


    // The synth script and/or sim makefile should put this on the include path.
    initial begin
        `include "software.rom.inc"    
    end

    cpu #(
        
    )
    cpu (
        .CLK            (CLK),
        .RESET_I        (RESET_I),

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

        .HWIRQ_I        (hw_irq),
        .STALL_I        (1'b0)
    );

    // Let's hope we can trick the synth tool into not optimizing it all away.
    always @(posedge CLK) begin
        DEBUG_O <= {code_trans, data_trans, data_size, data_write, 24'h0} ^ 
                   data_addr ^ 
                   data_wdata;
    end 

    // Dummy interconnect.
    always @(*) begin
        ctcm_addr = code_addr[12:2];
        code_ready = 1'b1;
        code_resp = 2'b00;
        code_rdata = ctcm_data;

        hw_irq = 0; // FIXME a good chunk of logic will go away!

        // Remember: this DOES NOT WORK, we only want to fool the synth tool.
        data_resp = 2'b00;
        data_ready = 1'b1;
        data_rdata = DEBUG_I;
    end

    // Synchronous CTCM ROM. We want to infer one or more BRAMs here and
    // chances are they'll be part of the most interesting timing paths.
    always @(posedge CLK) begin
        ctcm_data <= ctcm[ctcm_addr];
    end

    
endmodule
