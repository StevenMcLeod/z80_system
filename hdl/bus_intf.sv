interface z80Bus;
    logic[7:0] dmaster, dslave;
    logic[15:0] addr;

    logic inta;
    logic mwait;

    modport master( input dslave, mwait,
                    output dmaster, addr, inta);

    modport slave(  input dmaster, addr, inta,
                    output dslave, mwait);
endinterface : z80Bus
