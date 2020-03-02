`include "Z80Bus.vh"

module z80_uart#(
    parameter CLKS_PER_BIT
)(
	// Z80 Interface
    input logic		    clk,
	input logic 	    rst_n,
	input logic         ena,
    input Z80MasterBus  ibus,
    output Z80SlaveBus  obus,

    // Uart Interface
    input logic         rx,
    output logic        tx
);

logic out_busy;
logic out_valid, in_valid;
logic[7:0] out_data;

assign obus.mwait = ~(
    ena && (                        // Device enabled and...
        (~ibus.wrn && out_busy) ||  //      Writing when busy
        (~ibus.rdn && ~in_valid)    //      Reading when not valid
    ));

always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        out_valid <= 1'b0;
    end else if(ena == 1'b1) begin
        if(ibus.wrn == 1'b0 && out_busy == 1'b0) begin
            out_valid <= 1'b1;
            out_data <= ibus.dmaster;
        end
    end

    if(out_valid == 1'b1) begin
        out_valid <= 1'b0;
    end
end

uart_rx#(CLKS_PER_BIT) rx_dev (
    .i_Clock(clk),
    .i_Rst_n(rst_n),
    .i_Rx_Serial(rx),
    .o_Rx_DV(in_valid),
    .o_Rx_Byte(obus.dslave)
);

uart_tx#(CLKS_PER_BIT) tx_dev (
    .i_Clock(clk),
    .i_Rst_n(rst_n),
    .i_Tx_DV(out_valid),
    .i_Tx_Byte(out_data),
    .o_Tx_Active(out_busy),
    .o_Tx_Serial(tx),
    .o_Tx_Done()
);

endmodule : z80_uart

//////////////////////////////////////////////////////////////////////
// File Downloaded from http://www.nandland.com
// Steven McLeod 2020: Added Reset signal instead of default reg values
//////////////////////////////////////////////////////////////////////
// This file contains the UART Receiver.  This receiver is able to
// receive 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When receive is complete o_rx_dv will be
// driven high for one clock cycle.
// 
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87
  
module uart_rx 
  #(parameter CLKS_PER_BIT)
  (
   input        i_Clock,
   input        i_Rst_n,
   input        i_Rx_Serial,
   output       o_Rx_DV,
   output [7:0] o_Rx_Byte
   );
    
  localparam s_IDLE         = 3'b000;
  localparam s_RX_START_BIT = 3'b001;
  localparam s_RX_DATA_BITS = 3'b010;
  localparam s_RX_STOP_BIT  = 3'b011;
  localparam s_CLEANUP      = 3'b100;
   
  reg           r_Rx_Data_R = 1'b1;
  reg           r_Rx_Data   = 1'b1;
   
  reg [$clog2(CLKS_PER_BIT)-1:0]     r_Clock_Count;
  reg [2:0]     r_Bit_Index; //8 bits total
  reg [7:0]     r_Rx_Byte;
  reg           r_Rx_DV;
  reg [2:0]     r_SM_Main;
   
  // Purpose: Double-register the incoming data.
  // This allows it to be used in the UART RX Clock Domain.
  // (It removes problems caused by metastability)
  always @(posedge i_Clock)
    begin
      r_Rx_Data_R <= i_Rx_Serial;
      r_Rx_Data   <= r_Rx_Data_R;
    end
   
   
  // Purpose: Control RX state machine
  always @(posedge i_Clock)
    begin
      if(i_Rst_n == 1'b0) begin
        r_Clock_Count <= 0;
        r_Bit_Index = 0;
        r_Rx_Byte = 0;
        r_Rx_DV = 0;
        r_SM_Main = 0;
      end else begin
          case (r_SM_Main)
            s_IDLE :
              begin
                r_Rx_DV       <= 1'b0;
                r_Clock_Count <= 0;
                r_Bit_Index   <= 0;
                 
                if (r_Rx_Data == 1'b0)          // Start bit detected
                  r_SM_Main <= s_RX_START_BIT;
                else
                  r_SM_Main <= s_IDLE;
              end
             
            // Check middle of start bit to make sure it's still low
            s_RX_START_BIT :
              begin
                if (r_Clock_Count == (CLKS_PER_BIT-1)/2)
                  begin
                    if (r_Rx_Data == 1'b0)
                      begin
                        r_Clock_Count <= 0;  // reset counter, found the middle
                        r_SM_Main     <= s_RX_DATA_BITS;
                      end
                    else
                      r_SM_Main <= s_IDLE;
                  end
                else
                  begin
                    r_Clock_Count <= r_Clock_Count + 1;
                    r_SM_Main     <= s_RX_START_BIT;
                  end
              end // case: s_RX_START_BIT
             
             
            // Wait CLKS_PER_BIT-1 clock cycles to sample serial data
            s_RX_DATA_BITS :
              begin
                if (r_Clock_Count < CLKS_PER_BIT-1)
                  begin
                    r_Clock_Count <= r_Clock_Count + 1;
                    r_SM_Main     <= s_RX_DATA_BITS;
                  end
                else
                  begin
                    r_Clock_Count          <= 0;
                    r_Rx_Byte[r_Bit_Index] <= r_Rx_Data;
                     
                    // Check if we have received all bits
                    if (r_Bit_Index < 7)
                      begin
                        r_Bit_Index <= r_Bit_Index + 1;
                        r_SM_Main   <= s_RX_DATA_BITS;
                      end
                    else
                      begin
                        r_Bit_Index <= 0;
                        r_SM_Main   <= s_RX_STOP_BIT;
                      end
                  end
              end // case: s_RX_DATA_BITS
         
         
            // Receive Stop bit.  Stop bit = 1
            s_RX_STOP_BIT :
              begin
                // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
                if (r_Clock_Count < CLKS_PER_BIT-1)
                  begin
                    r_Clock_Count <= r_Clock_Count + 1;
                    r_SM_Main     <= s_RX_STOP_BIT;
                  end
                else
                  begin
                    r_Rx_DV       <= 1'b1;
                    r_Clock_Count <= 0;
                    r_SM_Main     <= s_CLEANUP;
                  end
              end // case: s_RX_STOP_BIT
         
             
            // Stay here 1 clock
            s_CLEANUP :
              begin
                r_SM_Main <= s_IDLE;
                r_Rx_DV   <= 1'b0;
              end
             
             
            default :
              r_SM_Main <= s_IDLE;
             
          endcase
      end
    end   
   
  assign o_Rx_DV   = r_Rx_DV;
  assign o_Rx_Byte = r_Rx_Byte;
   
endmodule // uart_rx

//////////////////////////////////////////////////////////////////////
// File Downloaded from http://www.nandland.com
// Steven McLeod 2020: Added Reset signal instead of default reg values
//////////////////////////////////////////////////////////////////////
// This file contains the UART Transmitter.  This transmitter is able
// to transmit 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When transmit is complete o_Tx_done will be
// driven high for one clock cycle.
//
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87
  
module uart_tx 
  #(parameter CLKS_PER_BIT)
  (
   input       i_Clock,
   input       i_Rst_n,
   input       i_Tx_DV,
   input [7:0] i_Tx_Byte, 
   output      o_Tx_Active,
   output reg  o_Tx_Serial,
   output      o_Tx_Done
   );
  
  localparam s_IDLE         = 3'b000;
  localparam s_TX_START_BIT = 3'b001;
  localparam s_TX_DATA_BITS = 3'b010;
  localparam s_TX_STOP_BIT  = 3'b011;
  localparam s_CLEANUP      = 3'b100;
   
  reg [2:0]    r_SM_Main;
  reg [$clog2(CLKS_PER_BIT)-1:0]    r_Clock_Count;
  reg [2:0]    r_Bit_Index;
  reg [7:0]    r_Tx_Data;
  reg          r_Tx_Done;
  reg          r_Tx_Active;
     
  always @(posedge i_Clock)
    begin
      if(i_Rst_n == 1'b0) begin
        r_SM_Main <= 0;
        r_Clock_Count <= 0;
        r_Bit_Index <= 0;
        r_Tx_Data <= 0;
        r_Tx_Done <= 0;
        r_Tx_Active <= 0;
      end else begin
        case (r_SM_Main)
          s_IDLE :
            begin
              o_Tx_Serial   <= 1'b1;         // Drive Line High for Idle
              r_Tx_Done     <= 1'b0;
              r_Clock_Count <= 0;
              r_Bit_Index   <= 0;
               
              if (i_Tx_DV == 1'b1)
                begin
                  r_Tx_Active <= 1'b1;
                  r_Tx_Data   <= i_Tx_Byte;
                  r_SM_Main   <= s_TX_START_BIT;
                end
              else
                r_SM_Main <= s_IDLE;
            end // case: s_IDLE
           
           
          // Send out Start Bit. Start bit = 0
          s_TX_START_BIT :
            begin
              o_Tx_Serial <= 1'b0;
               
              // Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
              if (r_Clock_Count < CLKS_PER_BIT-1)
                begin
                  r_Clock_Count <= r_Clock_Count + 1;
                  r_SM_Main     <= s_TX_START_BIT;
                end
              else
                begin
                  r_Clock_Count <= 0;
                  r_SM_Main     <= s_TX_DATA_BITS;
                end
            end // case: s_TX_START_BIT
           
           
          // Wait CLKS_PER_BIT-1 clock cycles for data bits to finish         
          s_TX_DATA_BITS :
            begin
              o_Tx_Serial <= r_Tx_Data[r_Bit_Index];
               
              if (r_Clock_Count < CLKS_PER_BIT-1)
                begin
                  r_Clock_Count <= r_Clock_Count + 1;
                  r_SM_Main     <= s_TX_DATA_BITS;
                end
              else
                begin
                  r_Clock_Count <= 0;
                   
                  // Check if we have sent out all bits
                  if (r_Bit_Index < 7)
                    begin
                      r_Bit_Index <= r_Bit_Index + 1;
                      r_SM_Main   <= s_TX_DATA_BITS;
                    end
                  else
                    begin
                      r_Bit_Index <= 0;
                      r_SM_Main   <= s_TX_STOP_BIT;
                    end
                end
            end // case: s_TX_DATA_BITS
           
           
          // Send out Stop bit.  Stop bit = 1
          s_TX_STOP_BIT :
            begin
              o_Tx_Serial <= 1'b1;
               
              // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
              if (r_Clock_Count < CLKS_PER_BIT-1)
                begin
                  r_Clock_Count <= r_Clock_Count + 1;
                  r_SM_Main     <= s_TX_STOP_BIT;
                end
              else
                begin
                  r_Tx_Done     <= 1'b1;
                  r_Clock_Count <= 0;
                  r_SM_Main     <= s_CLEANUP;
                  r_Tx_Active   <= 1'b0;
                end
            end // case: s_Tx_STOP_BIT
           
           
          // Stay here 1 clock
          s_CLEANUP :
            begin
              r_Tx_Done <= 1'b1;
              r_SM_Main <= s_IDLE;
            end
           
           
          default :
            r_SM_Main <= s_IDLE;
           
        endcase
      end
    end
 
  assign o_Tx_Active = r_Tx_Active;
  assign o_Tx_Done   = r_Tx_Done;
   
endmodule
