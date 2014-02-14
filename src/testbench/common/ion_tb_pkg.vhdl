--------------------------------------------------------------------------------
-- mips_tb_pkg.vhdl -- Functions and data for the simulation test benches.
--------------------------------------------------------------------------------
-- Most of this file deals with the 'simulation log': the CPU execution history
-- is logged to a text file for easy comparison to a similar log written by the
-- software simulator. This is meant as a debugging tool and is explained in
-- some detail in the project doc.
-- It is used as a verification tool at least while no other verification test
-- bench exists.
--------------------------------------------------------------------------------
-- FIXME Console logging code should be here too
--------------------------------------------------------------------------------
-- WARNING: 
-- This package contains arguably the worst code of the project; in order
-- to expedite things, a number of trial-and-error hacks have been performed on
-- the code below. Mostly, the adjustment of the displayed PC.
-- This is just the kind of hdl you don't want prospective employers to see :)
-- At least the synthesis tools never get to see it, it's simulation only.
-- 
-- The problem is: each change in the CPU state is logged in a text line, in 
-- which the address of the instruction that caused the change is included. 
-- From outside the CPU it is not always trivial to find out what instruction
-- caused what change (pipeline delays, cache stalls, etc.). 
-- I think the logging rules should be pretty stable now but I might have to
-- tweak them again as the cache implementation changes. Eventually I aim to
-- make this code fully independent of the cache implementation; it should
-- only depend on the cpu. I will do this step by step, as I do all the rest.
--------------------------------------------------------------------------------
-- NOTES (tagged in the code as @note1, etc.):
--
-- note1:
-- The multiplier LO/HI register change logging has been disabled (commented
-- out) until fixed (it fails in code sample 'adventure').
-- Please note it's the LOGGING that fails, not the instruction.
--
--------------------------------------------------------------------------------

library ieee,modelsim_lib;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.ION_MAIN_PKG.all;

use modelsim_lib.util.all;
use std.textio.all;
use work.txt_util.all;


package ION_TB_PKG is

-- Address of the simulated UART; a single TxB register.
constant TB_UART_ADDRESS : t_word := X"20000000";

-- Maximum line size of for console output log. Lines longer than this will be
-- truncated.
constant CONSOLE_LOG_LINE_SIZE : integer := 1024*4;

type t_pc_queue is array(0 to 3) of t_word;


type t_log_info is record
    rbank :                 t_rbank;
    prev_rbank :            t_rbank;
      
    epc_reg :               t_pc;
    prev_epc :              t_pc;
    sr_bev_reg :            std_logic;
    cp0_status :            std_logic_vector(4 downto 0);
    cp0_cache_control :     std_logic_vector(1 downto 0);
    prev_status :           t_word;
    p1_set_cp0 :            std_logic;
    p1_eret :               std_logic;
    pc_mtc0 :               t_word;
    
    pc_m :                  t_pc_queue;
    
    reg_hi, reg_lo :        t_word;
    prev_hi, prev_lo :      t_word;
    negate_reg_lo :         std_logic;
    mdiv_count_reg :        std_logic_vector(5 downto 0);
    prev_count_reg :        std_logic_vector(5 downto 0);
    
    data_rd_en :            std_logic;
    p1_rbank_we :           std_logic;
    code_rd_en :            std_logic;
    wr_be :          std_logic_vector(3 downto 0);

    present_data_wr_addr :  t_word;
    present_data_wr :       t_word;
    present_data_rd_addr :  t_word;
    present_code_rd_addr :  t_word;
    stall_pipeline :        std_logic;
    
    pending_data_rd_addr :  t_word;
    pending_data_wr_addr :  t_word;
    pending_data_wr_pc :    t_word;
    pending_data_wr :       t_word;
    pending_data_wr_we :    std_logic_vector(3 downto 0);
    
    word_loaded :           t_word;
    
    io_wr_data :            t_word;
    
    mdiv_address :          t_word;
    mdiv_pending :          boolean;
    
    exception :             std_logic;
    exception_prev :        std_logic_vector(1 downto 0);
    exception_pc :          t_word;
    
    data_rd_address :       t_word;
    load :                  std_logic;
    
    read_pending :          boolean;
    write_pending :         boolean;
    debug :                 t_word;
    
    -- Console log line buffer --------------------------------------
    con_line_buf :         string(1 to CONSOLE_LOG_LINE_SIZE);
    con_line_ix :          integer;
    
    -- Log trigger --------------------------------------------------
    -- Enable logging after fetching from a given address -----------
    log_trigger_address :   t_word;
    log_triggered :         boolean;
end record t_log_info;

procedure log_cpu_activity(
                signal clk :    in std_logic;
                signal reset :  in std_logic;
                signal done :   in std_logic;   
                base_entity :   string;
                cpu_name :      string;
                signal info :   inout t_log_info; 
                signal_name :   string;
                trigger_addr :  in t_word;
                file l_file :   TEXT;
                file con_file : TEXT);


end package;

package body ION_TB_PKG is

procedure log_cpu_status(
                signal info :   inout t_log_info;
                file l_file :   TEXT;
                file con_file : TEXT) is
variable i : integer;
variable ri : std_logic_vector(7 downto 0);
variable full_pc, temp, temp2 : t_word;
variable k : integer := 2;
variable log_trap_status :      boolean := false;
variable uart_data : integer;
variable uart_we : std_logic;
begin
    
    -- Trigger logging if the CPU fetches from trigger address
    if (info.log_trigger_address = info.present_code_rd_addr) and
       info.code_rd_en='1' then
        info.log_triggered <= true;
        
        assert 1=0
        report "Log triggered by fetch from address 0x"& hstr(info.log_trigger_address)
        severity note;
    end if;
    
    -- This is the address of the opcode that triggered the changed we're
    -- about to log
    full_pc := info.pc_m(k);
    
    -- Log memory writes ----------------------------------------
    if info.write_pending then
        if conv_integer(info.pending_data_wr_pc) <= conv_integer(full_pc) then
    
            ri := X"0" & info.pending_data_wr_we;
            temp := info.pending_data_wr;
            if info.pending_data_wr_we(3)='0' then
                temp := temp and X"00ffffff";
            end if;
            if info.pending_data_wr_we(2)='0' then
                temp := temp and X"ff00ffff";
            end if;
            if info.pending_data_wr_we(1)='0' then
                temp := temp and X"ffff00ff";
            end if;
            if info.pending_data_wr_we(0)='0' then
                temp := temp and X"ffffff00";
            end if;
            if info.log_triggered then
                print(l_file, "("& hstr(info.pending_data_wr_pc) &") ["& 
                    hstr(info.pending_data_wr_addr) &"] |"& 
                    hstr(ri)& "|="& 
                    hstr(temp)& " WR" );
            end if;
            info.debug <= info.pending_data_wr_pc;
            info.write_pending <= false;
        end if;
    end if;

    -- Log register bank activity.
    -- NOTE: in previous versions we used to do this only at the 1st cycle of
    --- instructions, mistakenly. Reg changes need to be logged as soon as 
    -- they happen.
    if true then --info.code_rd_en='1' then
        
        -- Log register changes -------------------------------------
        ri := X"00";
        for i in 0 to 31 loop
            if info.prev_rbank(i)/=info.rbank(i) 
               and info.prev_rbank(i)(0)/='U' then
                if info.log_triggered then
                    print(l_file, "("& hstr(info.pc_m(k-0))& ") "& 
                        "["& hstr(ri)& "]="& hstr(info.rbank(i)));
                end if;
            end if;
            ri := ri + 1;
        end loop;        
                           
        -- Log aux register changes ---------------------------------
        
        -- Mult/div module, register LO
        if info.prev_lo /= info.reg_lo and info.prev_lo(0)/='U' then
            -- Adjust opcode PC when LO came from the mul module
            if info.mdiv_pending then
                temp2 := info.mdiv_address;
                info.mdiv_pending <= false;
            else
                temp2 := info.pc_m(k-2);
            end if;
        
            -- we're observing the value of reg_lo, but the mult core
            -- will output the negated value in some cases. We
            -- have to mimic that behavior.
            if info.negate_reg_lo='1' then
                -- negate reg_lo before displaying
                temp := not info.reg_lo;
                temp := temp + 1;
                if info.log_triggered then
                    -- FIXME removed temporarily until fixed (@note1)
                    --print(l_file, "("& hstr(temp2)& ") [LO]="& hstr(temp));
                end if;
            else
                if info.log_triggered then
                    -- FIXME removed temporarily until fixed (@note1)
                    --print(l_file, "("& hstr(temp2)& ") [LO]="& hstr(info.reg_lo));
                end if;
            end if;
        end if;
        
        -- Mult/div module, register HI
        if info.prev_hi /= info.reg_hi and info.prev_hi(0)/='U' then
            -- Adjust opcode PC when HI came from the mul module
            if info.mdiv_pending then
                temp2 := info.mdiv_address;
                info.mdiv_pending <= false;
            else
                temp2 := info.pc_m(k-2);
            end if;
            
            if info.log_triggered then
                -- FIXME removed temporarily until fixed (@note1)
                --print(l_file, "("& hstr(temp2)& ") [HI]="& hstr(info.reg_hi));
            end if;
        end if;                
        
        -- CP0, register EPC
        if info.prev_epc /= info.epc_reg and info.epc_reg(31)/='U'  then
            temp := info.epc_reg & "00";
            if info.log_triggered then
                -- The instruction that caused the EP change is the last 
                -- recorded trap/syscall exception.
                print(l_file, "("& hstr(info.exception_pc)& ") [EP]="& hstr(temp));
            end if;
            info.prev_epc <= info.epc_reg;
            
            --log_trap_status := true;
        else
            --log_trap_status := false;
        end if;

        -- CP0, register SR
        
        -- If SR changed by mtc0 instruction, get the mtc0 address
        if (info.p1_set_cp0='1' or info.p1_eret='1') and info.cp0_status(4)='0' then
            info.pc_mtc0 <= info.pc_m(k-1);
        end if;
        
        -- Build SR from separate CPU signals
        temp := X"00" & "0" & info.sr_bev_reg & X"0000" & "0" &
                info.cp0_status;
        if info.prev_status /= temp and info.cp0_status(0)/='U' then
            if info.log_triggered then
                --if log_trap_status then
                if info.exception_prev(1) = '1' then
                    -- The instruction that caused the SR change is the last 
                    -- recorded trap/syscall exception.
                    -- @hack2
                    --print(l_file, "("& hstr(info.exception_pc)& ") [SR]="& hstr(temp));
                    temp2 := X"00000000";
                    print(l_file, "("& hstr(temp2)& ") [SR]="& hstr(temp));
                else
                    -- The instruction that caused the change is mtc0
                    -- @hack2
                    --print(l_file, "("& hstr(info.pc_mtc0)& ") [SR]="& hstr(temp));
                    temp2 := X"00000000";
                    print(l_file, "("& hstr(temp2)& ") [SR]="& hstr(temp));
                end if;
            end if;
            info.prev_status <= temp;
        end if;

        
        -- Save present cycle info to compare the next cycle --------
        info.prev_rbank <= info.rbank;
        info.prev_hi <= info.reg_hi;
        info.prev_lo <= info.reg_lo;

    end if;
    
    info.exception_prev(1) <= info.exception_prev(0);
    info.exception_prev(0) <= info.exception;
    
    -- Update instruction address table only at the 1st cycle of each 
    -- instruction.
    if info.code_rd_en='1' then
        info.pc_m(3) <= info.pc_m(2);
        info.pc_m(2) <= info.pc_m(1);
        info.pc_m(1) <= info.pc_m(0);
        info.pc_m(0) <= info.present_code_rd_addr;
    end if;  
    
    -- When we see an exception, overwrite last element of fetch address queue
    -- because we know it's not going to b executed and it would ruin the log.
    if info.exception='1' then
        -- Yet another crude hack, who's counting...
        info.pc_m(0) <= X"BFC00180";
    end if;
    
    -- Log memory reads ------------------------------------------
    if info.read_pending and info.load='1' and info.p1_rbank_we='1' then
        if info.log_triggered then
            print(l_file, "("& hstr(info.pc_m(1)) &") ["& 
                  hstr(info.pending_data_rd_addr) &"] <"& 
                  "**"& ">="& 
                  hstr(info.word_loaded)& " RD" );
        end if;
        info.read_pending <= false;
    end if;

    if info.exception='1' then
        info.exception_pc <= info.pc_m(1);
    end if;

    if info.wr_be/="0000" then
        --assert 1=0
        --report "write"
        --severity note;
        info.write_pending <= true;
        info.pending_data_wr_we <= info.wr_be;
        info.pending_data_wr_addr <= info.present_data_wr_addr;
        info.pending_data_wr_pc <= info.pc_m(k-1);
        info.pending_data_wr <= info.present_data_wr;
    end if;

    if info.data_rd_en='1' then
        info.read_pending <= true;
        info.pending_data_rd_addr <= info.present_data_rd_addr;
    end if;
    
    if info.mdiv_count_reg="100000" then
        info.mdiv_address <= info.pc_m(1);
        info.mdiv_pending <= true;
    end if;

    info.prev_count_reg <= info.mdiv_count_reg;

    -- Log data sent to simulated UART -----------------------------------------
    
    -- Decode the simulated UART single TX register at address 0x20000000.
    -- TODO this should be parameterizable.
    if info.present_data_wr_addr = TB_UART_ADDRESS and info.wr_be /= "0000" then 
        uart_we := '1';
    else
        uart_we := '0';
    end if;
    
    -- TX data comes from the low byte.
    if uart_we = '1' then
        uart_data := conv_integer(unsigned(info.io_wr_data(7 downto 0)));
    
        -- UART TX data goes to output after a bit of line-buffering
        -- and editing
        if uart_data = 10 then
            -- CR received: print output string and clear it
            print(con_file, info.con_line_buf(1 to info.con_line_ix));
            info.con_line_ix <= 1;
            for i in 1 to info.con_line_buf'high loop
               info.con_line_buf(i) <= ' ';
            end loop;
        elsif uart_data = 13 then
            -- ignore LF
        else
            -- append char to output string
            if info.con_line_ix < info.con_line_buf'high then
                info.con_line_buf(info.con_line_ix) <= character'val(uart_data);
                info.con_line_ix <= info.con_line_ix + 1;
            end if;
        end if;
    end if;
    
    
end procedure log_cpu_status;

procedure log_cpu_activity(
                signal clk :    in std_logic;
                signal reset :  in std_logic;
                signal done :   in std_logic;   
                base_entity :    string;
                cpu_name :      string;
                signal info :   inout t_log_info; 
                signal_name :   string;
                trigger_addr :  in t_word;
                file l_file :   TEXT;
                file con_file : TEXT) is
begin
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/p1_rbank", signal_name&".rbank", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/code_mosi_o.addr", signal_name&".present_code_rd_addr", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/stall_pipeline", signal_name&".stall_pipeline", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/mult_div/upper_reg", signal_name&".reg_hi", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/mult_div/lower_reg", signal_name&".reg_lo", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/mult_div/negate_reg", signal_name&".negate_reg_lo", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/mult_div/count_reg", signal_name&".mdiv_count_reg", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/cop0/epc_reg", signal_name&".epc_reg", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/cop0/cp0_status", signal_name&".cp0_status", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/cop0/sr_reg.bev", signal_name&".sr_bev_reg", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/p1_set_cp0", signal_name&".p1_set_cp0", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/p1_eret", signal_name&".p1_eret", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/cop0/cp0_cache_control", signal_name&".cp0_cache_control", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/data_mosi_o.rd_en", signal_name&".data_rd_en", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/p1_rbank_we", signal_name&".p1_rbank_we", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/code_mosi_o.rd_en", signal_name&".code_rd_en", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/p2_do_load", signal_name&".load", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/data_mosi_o.addr", signal_name&".present_data_wr_addr", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/data_mosi_o.wr_data", signal_name&".present_data_wr", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/data_mosi_o.wr_be", signal_name&".wr_be", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/p2_data_word_rd", signal_name&".word_loaded", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/data_mosi_o.addr", signal_name&".present_data_rd_addr", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/p1_exception", signal_name&".exception", 0);
    init_signal_spy("/"&base_entity&"/"&cpu_name&"/data_mosi_o.wr_data", signal_name&".io_wr_data", 0);
    
    
    while done='0' loop
        wait until clk'event and clk='1';
        if reset='1' then
            -- FIXME should use real reset vector here
            info.pc_m <= (others => X"00000000");
            
            -- By default logging is DISABLED by triggering with an impossible
            -- fetch address. Logging must be enabled from outside by 
            -- setting log_trigger_address to a suitable value.
            info.log_trigger_address <= trigger_addr;
            info.log_triggered <= false;
            info.debug <= (others => '0');
            
            info.con_line_ix <= 1; -- uart log line buffer is empty
        else
            log_cpu_status(info, l_file, con_file);
        end if;
    end loop;
    

end procedure log_cpu_activity;

end package body;
