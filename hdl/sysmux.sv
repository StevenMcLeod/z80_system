`include "Z80Bus.vh"

`define CLAMP_LOW(v, cl) ((v) > (cl) ? (v) : (cl))

module sysmux #(
    parameter MASTER_QTY,
    parameter SLAVE_QTY
) (
//    z80Bus.master                           busmaster,
//    z80Bus.slave                            busslave[SLAVE_QTY],

//    input logic[7:0]                        dmaster_ins,
//    input logic[15:0]                       addr_ins,
//    input logic                             inta_ins,
    input Z80MasterBus                      master_ins[MASTER_QTY],
    
//    output logic[7:0]                       dmaster_out,
//    output logic                            addr_out,
//    output logic                            inta_out,
    output Z80MasterBus                     master_out,
    
//    input logic[7:0]                        dslave_ins[SLAVE_QTY],
//    input logic                             mwait_ins[SLAVE_QTY],
    input Z80SlaveBus                       slave_ins[SLAVE_QTY],
    
//    output logic[7:0]                       dslave_out,
//    output logic                            mwait_out,
    output Z80SlaveBus                      slave_out,

    // If MASTER_QTY or SLAVE_QTY == 1 then vector width is 0 and tie low
    input logic[`CLAMP_LOW($clog2(MASTER_QTY)-1, 0) : 0]   msel,
    input logic[`CLAMP_LOW($clog2(SLAVE_QTY)-1, 0)  : 0]   ssel
);

always_comb
begin
    if(MASTER_QTY == 1 
        || msel < MASTER_QTY) begin
        master_out.dmaster  <= master_ins[msel].dmaster;
        master_out.addr     <= master_ins[msel].addr;
        master_out.rdn      <= master_ins[msel].rdn;
        master_out.wrn      <= master_ins[msel].wrn;
        master_out.mreqn    <= master_ins[msel].mreqn;
        master_out.iorqn    <= master_ins[msel].iorqn;
        master_out.inta     <= master_ins[msel].inta;
    end else begin
        master_out.dmaster  <= '0;
        master_out.addr     <= '0;
        master_out.rdn      <= 1'b0;
        master_out.wrn      <= 1'b0;
        master_out.mreqn    <= 1'b0;
        master_out.iorqn    <= 1'b0;
        master_out.inta     <= 1'b0;
    end
end

always_comb
begin
    if(SLAVE_QTY == 1 
        || ssel < SLAVE_QTY) begin
        slave_out.dslave    <= slave_ins[ssel].dslave;
        slave_out.mwait     <= slave_ins[ssel].mwait;
    end else begin
        slave_out.dslave    <= '0;
        slave_out.mwait     <= 1'b1;
    end
end

//always_comb
//begin
//    // Selected Master -> Slave Signal Transfer
//    for(s = 0; s < SLAVE_QTY; ++s) begin
//        //if(msel >= MASTER_QTY) begin
//            busslave[s].dmaster <= busmaster.dmaster;
//            busslave[s].addr    <= busmaster.addr;
//            busslave[s].inta    <= busmaster.inta;
//        //end else begin
//            //busslave[s].dmaster <= '0;
//            //busslave[s].addr <= '0;
//            //busslave[s].inta <= 1'b0;
//        //end
//    end

//    // Selected Slave -> Master Signal Transfer
//    for(int m = 0; m < MASTER_QTY; ++m) begin
//        if(ssel >= SLAVE_QTY) begin
//            busmaster.dslave    <= busslave[ssel].dslave;
//            busmaster.mwait     <= busslave[ssel].mwait;
//        end else begin
//            busmaster.dslave    <= '0;
//            busmaster.mwait     <= 1'b1;
//        end
//    end
//end

endmodule : sysmux
