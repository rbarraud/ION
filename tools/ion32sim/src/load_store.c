/**
    @file load_store.c
    @brief Implementation of loads and stores including simulated IO and RAM.
*/

#include "ion32sim.h"


/*---- Local function prototypes ---------------------------------------------*/


void gpio_reg_write(t_state *s, uint32_t address, uint32_t data);
uint16_t gpio_reg_read(t_state *s, int size, unsigned int address);
void debug_reg_write(t_state *s, uint32_t address, uint32_t data);
int debug_reg_read(t_state *s, int size, unsigned int address);


/*---- Common functions ------------------------------------------------------*/

/** Read memory, optionally logging */
int mem_read(t_state *s, int size, unsigned int address, int log){
    unsigned int value=0, word_value=0, i, ptr;
    unsigned int full_address = address;
    int c;

    /* Handle access to debug register block */
    if((address&0xfffffff0)==(TB_DEBUG&0xfffffff0)){
        return debug_reg_read(s, size, address);
    }

    /* Handle access to GPIO register block */
    /* FIXME this is actually an APPLICATION feature, should be optional! */
    if((address&0xfffffff0)==(IO_GPIO&0xfffffff0)){
        return gpio_reg_read(s, size, address);
    }


    s->irqStatus |= IRQ_UART_WRITE_AVAILABLE;
    switch(address){
    case TB_UART_RX:
        /* FIXME Take input from text file */
        /* Wait for incoming character */
        while(!kbhit());
        //s->irqStatus &= ~IRQ_UART_READ_AVAILABLE; //clear bit
        c = getch();
        printf("%c", c);
        return c;
    case UART_STATUS:
        /* Hardcoded status bits: tx and rx available */
        return IRQ_UART_WRITE_AVAILABLE | IRQ_UART_READ_AVAILABLE;
    case TIMER_READ:
        printf("TIMER = %10d\n", s->instruction_ctr);
        return s->instruction_ctr;
        break;
    case IRQ_MASK:
       return 0;
    case IRQ_MASK + 4:
       sim_sleep(10);
       return 0;
    case IRQ_STATUS:
       /*if(kbhit())
          s->irqStatus |= IRQ_UART_READ_AVAILABLE;
       return s->irqStatus;
       */
       /* FIXME Optionally simulate UART TX delay */
       word_value = 0x00000003; /* Ready to TX and RX */
       //log_read(s, full_address, word_value, size, log);
       return word_value;
    }

    /* point ptr to the byte in the block, or NULL is the address is unmapped */
    ptr = 0;
    for(i=0;i<NUM_MEM_BLOCKS;i++){
        if((address & s->blocks[i].mask) ==
           (s->blocks[i].start & s->blocks[i].mask)){
            ptr = (unsigned)(s->blocks[i].mem) +
                  ((address - s->blocks[i].start) % s->blocks[i].size);
            break;
        }
    }
    if(!ptr){
        /* address out of mapped blocks: log and return zero */
        /* if bit CP0.16==1, this is a D-Cache line invalidation access and
           the HW will not read any actual data, so skip the log (@note1) */
        // FIXME refactor
        printf("MEM RD ERROR @ 0x%08x [0x%08x]\n", s->pc, full_address);
        if(log_enabled(s) && log!=0 && !(s->cp0_status & (1<<16))){
            fprintf(s->t.log, "(%08X) [%08X] <**>=%08X RD UNMAPPED\n",
                s->pc, full_address, 0);
        }
        return 0;
    }

    if((s->blocks[i].flags & MEM_TEST)){
        return test_pattern(s->blocks[i].start, address);
    }

    /* get the whole word */
    word_value = *(int*)(ptr&0xfffffffc);
    if(s->big_endian){
        word_value = ntohl(word_value);
    }

    switch(size){
    case 4:
        if(address & 3){
            printf("Unaligned access PC=0x%x address=0x%x\n",
                (int)s->pc, (int)address);
        }
        if((address & 3) != 0){
            /* unaligned word, log fault */
            s->failed_assertions |= ASRT_UNALIGNED_READ;
            s->faulty_address = address;
            address = address & 0xfffffffc;
        }
        value = *(int*)ptr;
        if(s->big_endian){
            value = ntohl(value);
        }
        break;
    case 2:
        if((address & 1) != 0){
            /* unaligned halfword, log fault */
            s->failed_assertions |= ASRT_UNALIGNED_READ;
            s->faulty_address = address;
            address = address & 0xfffffffe;
        }
        value = *(unsigned short*)ptr;
        if(s->big_endian){
            value = ntohs((unsigned short)value);
        }
        break;
    case 1:
        value = *(unsigned char*)ptr;
        break;
    default:
        /* This is a bug, display warning */
        printf("\n\n**** BUG: wrong memory read size at 0x%08x\n\n", s->pc);
    }

    //log_read(s, full_address, value, size, log);
    return(value);
}


/** Write to memory, including simulated i/o */
void mem_write(t_state *s, int size, unsigned address, unsigned value, int log){
    unsigned int i, ptr, mask, dvalue, b0, b1, b2, b3;

    if(log_enabled(s)){
        b0 = value & 0x000000ff;
        b1 = value & 0x0000ff00;
        b2 = value & 0x00ff0000;
        b3 = value & 0xff000000;

        switch(size){
        case 4:  mask = 0x0f;
            dvalue = value;
            break;
        case 2:
            if((address&0x2)==0){
                mask = 0xc;
                dvalue = b1<<16 | b0<<16;
            }
            else{
               mask = 0x3;
               dvalue = b1 | b0;
            }
            break;
        case 1:
            switch(address%4){
            case 0 : mask = 0x8;
                dvalue = b0<<24;
                break;
            case 1 : mask = 0x4;
                dvalue = b0<<16;
                break;
            case 2 : mask = 0x2;
                dvalue = b0<<8;
                break;
            case 3 : mask = 0x1;
                dvalue = b0;
                break;
            }
            break;
        default:
            printf("BUG: mem write size invalid (%08x)\n", s->pc);
            exit(2);
        }

        fprintf(s->t.log, "(%08X) [%08X] |%02X|=%08X WR\n",
                //s->op_addr, address&0xfffffffc, mask, dvalue);
                s->op_addr, address, mask, dvalue);
    }

    /* Handle accesses to debug registers */
    if((address&0xfffffff0)==(TB_DEBUG&0xfffffff0)){
        debug_reg_write(s, address, value);
        return;
    }

    /* Handle accesses to GPIO registers */
    /* FIXME Application feature, not CPU's, should be optional! */
    if((address&0xfffffff0)==(IO_GPIO&0xfffffff0)){
        gpio_reg_write(s, address, value);
        return;
    }

    // Capture accesses to simulated registers.
    // FIXME should be enabled with command line argument
    switch(address){
    case TB_UART_TX:
        putchar(value);
        fflush(stdout);
        return;
    case TB_HW_IRQ:
        /* HW interrupt trigger register */
        s->t.irq_trigger_countdown = 3;
        s->t.irq_trigger_inputs = value;
        return;
    case TB_STOP_SIM:
        /* Simulation stop: writing anything here stops the simulation.
        The value being written is, by convention, the number of errors
        detected in a test bench program and will be displayed as such.
        */
        fprintf(stderr, "Simulation terminated by program command.\n\n");
        if (value>0) {
            fprintf(stderr, "Program reports FAILURE -- %d errors.\n", value);
        }
        else {
            fprintf(stderr, "Program reports SUCCESS -- no errors.\n");
        }
        fprintf(stderr, "\n");
        s->wakeup = 1;
        return;
    case IRQ_MASK:
        return;
    case IRQ_STATUS:
        s->irqStatus = value;
        return;
    }

    ptr = 0;
    for(i=0;i<NUM_MEM_BLOCKS;i++){
        if((address & s->blocks[i].mask) ==
                  (s->blocks[i].start & s->blocks[i].mask)){
            ptr = (unsigned)(s->blocks[i].mem) +
                            ((address - s->blocks[i].start) % s->blocks[i].size);

            if(s->blocks[i].flags & MEM_READONLY){
                if(log_enabled(s) && log!=0){
                    fprintf(s->t.log, "(%08X) [%08X] |%02X|=%08X WR READ ONLY\n",
                    s->op_addr, address, mask, dvalue);
                    return;
                }
            }
            break;
        }
    }
    if(!ptr){
        /* address out of mapped blocks: log and return zero */
        printf("MEM WR ERROR @ 0x%08x [0x%08x]\n", s->pc, address);
        if(log_enabled(s) && log!=0){
            fprintf(s->t.log, "(%08X) [%08X] |%02X|=%08X WR UNMAPPED\n",
                s->op_addr, address, mask, dvalue);
        }
        return;
    }

    switch(size){
    case 4:
        if((address & 3) != 0){
            /* unaligned word, log fault */
            s->failed_assertions |= ASRT_UNALIGNED_WRITE;
            s->faulty_address = address;
            address = address & (~0x03);
        }
        if(s->big_endian){
            value = htonl(value);
        }
        *(int*)ptr = value;
        break;
    case 2:
        if((address & 1) != 0){
            /* unaligned halfword, log fault */
            s->failed_assertions |= ASRT_UNALIGNED_WRITE;
            s->faulty_address = address;
            address = address & (~0x01);
        }
        if(s->big_endian){
            value = htons((unsigned short)value);
        }
        *(short*)ptr = (unsigned short)value;
        break;
    case 1:
        *(char*)ptr = (unsigned char)value;
        break;
    default:
        /* This is a bug, display warning */
        printf("\n\n**** BUG: wrong memory write size at 0x%08x\n\n", s->pc);
    }
}



/*---- Local functions -------------------------------------------------------*/

/** Read from GPIO register (HW register simplified for TB). */
uint16_t gpio_reg_read(t_state *s, int size, unsigned int address){
    /* A single 16 bit register available */
    return (s->gpio_regs[0] + 0x02901) & 0xffff;
}


/** Write to debug register */
void gpio_reg_write(t_state *s, uint32_t address, uint32_t data){
    //printf("GPIO REG[%1d]=%08x\n", (address >> 2)&0x03, data);
    s->gpio_regs[0] = data & 0xffff;
}

/** Read from debug register (TB only feature). */
int debug_reg_read(t_state *s, int size, unsigned int address){
    /* Four 32 bit registers available */
    return s->debug_regs[(address >> 2)&0x03];
}

/** Write to debug register */
void debug_reg_write(t_state *s, uint32_t address, uint32_t data){
    /* all other registers are used for display (like LEDs) */
    //printf("DEBUG REG[%1d]=%08x\n", (address >> 2)&0x03, data);
    s->debug_regs[(address >> 2)&0x03] = data;
}

