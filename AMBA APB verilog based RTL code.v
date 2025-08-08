///////////////////////////APB MASTER ///////////////////////////////

module master(
  input [7:0] apb_write_paddr,apb_read_paddr,
  input [7:0] apb_write_data,prdata,
  input presetn,pclk,read,write,transfer,pready,
  
  output psel1,psel2,
  output reg penable,
  output reg [8:0] paddr,
  output reg pwrite,
  output reg [7:0] pwdata,apb_read_data_out,
  output pslverr );
  
  reg [2:0] present_state,next_state;
  
  reg invalid_setup_error;
  reg setup_error,
      invalid_read_paddr,
      invalid_write_paddr,
      invalid_write_data;
  
  parameter idle = 2'b01;
  parameter setup = 2'b10;
  parameter enable = 2'b11;
  
  always@(posedge pclk)
    begin
      if(!presetn)
        present_state <= idle;
      else
        present_state <= next_state;
    end
  
  always@(present_state,transfer,pready)
    begin
      pwrite = write;
      
      case(present_state)
        idle:
          begin
            penable = 0;
            if(!transfer)
              next_state = idle;
            else
              next_state = setup;
          end
        
        setup:
          begin
            penable = 0;
            if(read == 1'b1 && write == 1'b0)
              paddr = apb_read_paddr;
            else if(read == 1'b0 && write == 1'b1)
              begin
                paddr = apb_write_paddr;
                pwdata = apb_write_data;
              end
          end
        
        enable:
          begin
            if(psel1 || psel2)
              penable = 1'b1;
            
            if(transfer & !pslverr)
              begin
                if(pready)
                  begin
                    if(read == 1'b0 && write == 1'b1)
                      next_state = setup;
                    else if (read == 1'b1 && write == 1'b0)
                      begin
                        next_state = setup;
                        apb_read_data_out = prdata;
                      end
                    else
                      next_state = enable;
                  end
                next_state = idle;
              end
          end
      endcase
    end
  
 // assign{psel1,psel2} = ((present != idle) ?(paddr[8] ?{1'b0,1'b1} : {1'b1 : 1'b0}) : 2'd0
  
  /////PLSAVE ERROR LOGIC
  
  always@(*)
    begin
     // invaild_setup_error = setup_error || invalid_read_paddr || invalid_write_data || invalid_write_paddr;
      if(!presetn) 
        begin
          setup_error = 0;
          invalid_read_paddr = 0;
          invalid_write_paddr = 0;
        end
      else if(present_state == idle && next_state == enable)
        begin
          setup_error = 1;
        end
      else if((apb_write_data == 8'dx) && (read == 1'b0) && (write == 1'b1) && (present_state == setup || present_state == enable))
        begin
          invalid_write_data = 1'b1;
        end
      else if((apb_read_paddr == 9'dx) && (read == 1'b1) && (write == 1'b0) && (present_state == setup) || (present_state == enable))
        begin
          invalid_read_paddr = 1'b1;
        end
      else if((apb_write_paddr == 9'dx) && (read == 1'b0) && (write == 1'b1) && (present_state = setup) || (present_state == enable))
        begin
          invalid_write_paddr = 1'b0;
        end
      
      else
        invalid_write_paddr = 1'b0;
        invalid_write_data = 1'b0;
        invalid_read_paddr = 1'b0;
    end
  
  assign pslverr = invalid_setup_error;
  
  
endmodule


///////////////////////APB_SLAVE/////////////////

module apb_slave(
  input pclk,presetn,
  input psel,penable,pwrite,
  input [7:0] paddr,pwdata,
  output [7:0] prdata,
  output reg pready );
  
  reg [7:0] addr;
  reg [7:0] mem [63:0];
  
  assign prdata = mem[addr];
  
  always@(*)
    begin
      if(!presetn)
        begin
          pready = 0;
        end
      else if(psel && !penable && !pwrite)
        pready = 0;
      else if(psel && penable && !pwrite)
        begin
         pready = 1;
          addr = paddr;
        end
      else if(psel && !penable && pwrite)
        begin
          pready = 0;
        end
      else if(psel && penable && pwrite)
        begin
          pready = 1;
          mem[addr] = pwdata;
        end
      else
        pready = 0;
    end
  
endmodule



/////////////////////////APB_Testbench//////////////////////////////////

module apb_top(
  
  input pclk,presetn,transfer,read,write,
  input [8:0] apb_write_paddr,
  input [7:0] apb_write_data,
  input [8:0] apb_read_paddr,
  output pslverr,
  output [7:0] apb_read_data_out );
  
  wire [7:0] pwdata,prdata,prdata1,prdata2;
  wire [8:0] paddr;
  wire pready,pready1,pready2,penable,psel1,psel2,pwrite;
  
  
  master dut_mas(apb_write_paddr,apb_read_paddr,
                 apb_write_data,prdata,
                 presetn,pclk,read,write,transfer,pready,
                 psel1,psel2,penable,paddr,
                 pwrite,pwdata,apb_read_data_out,pslverr);
  
  apb_slave dut_slave1( pclk,presetn,psel,penable,
                       pwrite,paddr,pwdata,prdata,pready);
  
  apb_slave dut_slave2( pclk,presetn,psel,penable,
                       pwrite,paddr,pwdata,prdata,pready);
  
endmodule