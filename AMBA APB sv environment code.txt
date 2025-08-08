/////////////////////////////////Design Code////////////////////////////////////

module APB_master(pclk,presetn,penable,psel,pwrite,paddr,pwdata,prdata,pready,pslverr);
  input presetn;
  input pclk;
  input psel;
  input penable;
  input pwrite;
  input [31:0] paddr,pwdata;
  output reg [31:0] prdata;
  output reg pready,pslverr;
  
  reg [31:0] mem [32];
  
  parameter idle = 2'b00;
  parameter setup = 2'b01;
  parameter access = 2'b10;
  parameter transfer = 2'b11;
  
  reg [2:0] state,next_state;
  
  //////////////////Seq. block code//////////////////
  
  always@(posedge pclk) begin
    if(!presetn)
      state <= idle;
    else
      state <= next_state;
  end
  
  //////////////////Comb. block code////////////////////
  
  always@(pready or state) begin
    case(state)
      idle:
        begin
          if((psel == 1'b0) && (penable == 1'b0))
            begin
              next_state = setup;
            end
          
          pready = 1'b0;
          pslverr = 1'b0;
        end
      
      setup:
        begin
          if((psel == 1'b1) && (penable == 1'b0))
            begin
              if(paddr < 32)
                begin
                  next_state = access;
                  pready = 1'b1;
                end
              else
                begin
                  next_state = access;
                  pready = 1'b0;
                end
            end
          else
            next_state = setup;
        end
      
      access:
        begin
          if((psel == 1'b1) && (pwrite == 1'b1) && (penable == 1'b1))
            begin
            if(paddr < 32)
              begin
                next_state = transfer;
                pready = 1'b1;
                pslverr = 1'b0;
              end
          else
            begin
              next_state = transfer;
              pready = 1'b1;
              pslverr = 1'b1;
            end
            end
          else if((psel == 1'b1) && (pwrite == 1'b0) && (penable == 1'b1))
            begin
            if(paddr < 32)
              begin
                next_state = transfer;
                pready = 1'b1;
                pslverr = 1'b0;
              end
          else
            begin
              next_state = transfer;
              pready = 1'b1;
              pslverr = 1'b1;
            end
            end
        end
      
      default: next_state = idle;
      
    endcase
  end
  
endmodule




interface intf();
 // input logic pclk
  logic presetn;
  logic pclk;
  logic psel;
  logic penable;
  logic pwrite;
  logic [31:0] paddr,pwdata;
  logic [31:0] prdata;
  logic pready,pslverr;
endinterface



//////////////////////////////////TestBench code///////////////////////////////////////

class packet;
      bit pclk;
 rand bit presetn;
 rand bit psel;
 rand bit penable;
 rand bit pwrite;
 rand bit [31:0] paddr;
 rand bit pwdata;
  bit [31:0] prdata;
  bit pready;
  bit pslverr;
  
  function void disp();
    $display($time," penable : %0d,psel : %0d,pwrite : %0d,paddr : %0d,pwdata : %0d,prdata : %0d,pready : %0d,pslverr : %0d",penable,psel,pwrite,paddr,pwdata,prdata,pready,pslverr);
  endfunction
  
endclass

class generator;
  packet pkt;
  virtual intf vif;
  
  function new(virtual intf inf);
    this.vif = inf;
  endfunction
  
  task run;
    repeat(20) begin
    pkt = new;
    pkt.randomize();
    vif.presetn <= pkt.presetn;
    vif.pclk <= pkt.pclk;
    vif.psel <= pkt.psel;
    vif.penable <= pkt.penable;
    vif.pwrite <= pkt.pwrite;
    vif.paddr <= pkt.paddr;
    vif.pwdata <= pkt.pwdata;
    end
  endtask
  
endclass

class monitor;
  packet pkt;
  mailbox m_box;
  virtual intf vif;
  
  covergroup cg;
    A : coverpoint pkt.psel{
      bins b1 = {0};
      bins b2 = {1};
  }
    B : coverpoint pkt.penable{
      bins b1 = {1};
      bins b2 = {0};
    }
    
  endgroup
  
  function new(virtual intf inf, mailbox mbx);
    this.vif = inf;
    this.m_box = mbx;
    cg = new();
  endfunction
  
  task run;
    repeat(20) begin
    pkt = new;
    pkt.presetn = vif.presetn;
    pkt.pclk <= vif.pclk;
   // pkt.psel = vif.psel;
   // pkt.penable = vif.penable;
   // pkt.pwrite = vif.pwrite;
   // pkt.paddr = vif.paddr;
   // pkt.pwdata = vif.pwdata;
      
      @(posedge vif.pclk) begin
        if(vif.psel && vif.pwrite && vif.penable) //	write access
        begin
         pkt.paddr = vif.paddr;
         pkt.pwdata = vif.pwdata;
         pkt.pwrite = vif.pwrite;
         pkt.pslverr = vif.pslverr;
         pkt.pready = vif.pready; 
        end
        else if(vif.psel && !vif.pwrite && vif.penable) //read access
        begin
         pkt.paddr = vif.paddr;
         pkt.pwdata = vif.pwdata;
         pkt.pwrite = vif.pwrite;
         pkt.pslverr = vif.pslverr;
         pkt.pready = vif.pready; 
        end
      end
      cg.sample();
        m_box.put(pkt);
    end
  endtask
  
endclass

class scoreboard;
  packet pkt;
  mailbox s_box;
  
  function new(mailbox mbx);
    this.s_box = mbx;
  endfunction
  
  task run;
    repeat(20) begin
      s_box.get(pkt);
      
      if(pkt.pwrite == 1'b1 && pkt.pready == 1'b1 || pkt.pslverr == 1'b0) //Write operation
        $display("APB Write Test Passed");
      else if(pkt.pwrite == 1'b0 && pkt.pready == 1'b1 || pkt.pslverr == 1'b0) // Read operation
        $display("APB Read Test Passed");
      else if(pkt.pslverr == 1'b1) // Error
        $display("APB Test Failed");
    end
    
  endtask
endclass



module top;
  bit pclk;
  
  intf inf();
  
  APB_master dut(inf.pclk,inf.presetn,inf.penable,inf.psel,inf.pwrite,inf.paddr,inf.pwdata,inf.prdata,inf.pready,inf.pslverr);
  
  always #5 inf.pclk = ~inf.pclk;
  
  initial
    inf.pclk = 0;
  
  mailbox mbx;
  packet pkt;
  generator gen;
  monitor mon;
  scoreboard scr;
  
  initial begin
   // inf.pclk = 0;
    mbx = new();
    pkt = new();
    gen = new(inf);
    mon = new(inf,mbx);
    scr = new(mbx);
    
    fork
      pkt.disp();
      gen.run();
      mon.run();
      scr.run();
    join
  end
  
   initial 
     $monitor($time," pclk : %0d,presetn : %0d,pwrite : %0d,paddr : %0d,pwdata : %0d,prdata : %0d,pready : %0d,pslverr : %0d",inf.pclk,inf.presetn,inf.pwrite,inf.paddr,inf.pwdata,inf.prdata,inf.pready,inf.pslverr);
  
  initial 
    #250 $finish();
endmodule



////////////////////////////////////////RUN.DO FILE////////////////////////////////////////////

asim -acdb +access+r;
run -all;
acdb save;
acdb report -db work.acdb -txt -o cov.txt;
exec cat cov.txt;
exit

////////////////////////////////////////////////////////////////////////////////////////////

&& acdb report -db fcover.acdb -txt -o cov.txt