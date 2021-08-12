module SPI_Master#(parameter ClockPerBit=1) ( MISO,
Masterclk, // clk of the master 
 reset,
ExternalIn,
SPIMode,
 mem1,
 mem2,
 mem3,
 rw,
 load,
 MOSI,
SCLK,   //this clock will be used in communication and shift register
                    // it will be generated with the clock of the master 
 CS1,
 CS2,
 CS3,
 Enable,
 flag,
  DataOfMaster,    // after shifting to be tested);
  we,
  oe,
  start); //start of transmission
 input MISO;
 output reg [0:7] DataOfMaster; // after shifting to be tested);
input Masterclk; // clk of the master 
input reset;
input [0:7]ExternalIn;
input [0:1]SPIMode;
input mem1;
input mem2;
input mem3;
input [0:1] rw;
input  load;
output reg MOSI;
output reg SCLK;   //this clock will be used in communication and shift register
                    // it will be generated with the clock of the master 
output reg we;
output reg start;
output reg oe;                    
output wire CS1;
output wire CS2;
output wire CS3;
input Enable;
output reg flag;

//localparam ClockPerBit=2;
wire CPOL;
wire CLPH;
reg ReadyToReceive1;
reg RisingEdge;  //of SCKL
reg FallingEdge; //of SCLK
reg r_SCLK;
reg [0:7]r_reg; 
reg [0:(ClockPerBit*2)-1]Clock_SPI_Count;
integer i;
localparam Write=2'd1;
localparam Read=2'd2;
localparam ReadANDWrite=2'd3;
assign CPOL=(SPIMode==2)|(SPIMode==3);
assign CLPH=(SPIMode==1)|(SPIMode==2);
assign CS1=(mem1)? 1'b0:1'b1;
assign CS2=(mem2)? 1'b0:1'b1;
assign CS3=(mem3)? 1'b0:1'b1;

//this block to generate the clock of spi
always @(posedge Masterclk , posedge reset)
  begin
    if (reset)begin
      flag<=1'b0;
      i<=0;
      DataOfMaster<=0;
      ReadyToReceive1<=0;
      start<=0;
      RisingEdge  <= 1'b0; //defoult values in case that count=2
      FallingEdge <= 1'b0;
      if(load)begin
       r_reg<=ExternalIn;
       DataOfMaster<=ExternalIn;
     end
       else
       r_reg<=8'b0;
       r_SCLK<=CPOL;// assign default state to idle state
       SCLK <=CPOL;
       Clock_SPI_Count <= 0;
    end
    else
    begin
      RisingEdge  <= 1'b0; //defoult values 
      FallingEdge <= 1'b0;
        if (Clock_SPI_Count == ClockPerBit*2-1)
        begin
          if(CPOL)
           RisingEdge<=1'b1;
         else 
          FallingEdge<=1'b1;
          Clock_SPI_Count <= 0;
          start<=1'b1;
          r_SCLK       <= ~r_SCLK;
        end
        else if (Clock_SPI_Count == ClockPerBit-1)
        begin
          if(CPOL)
           FallingEdge<=1'b1;
         else 
          RisingEdge<=1'b1;
          Clock_SPI_Count <= Clock_SPI_Count + 1;
          start<=1'b1;
          r_SCLK      <= ~r_SCLK ;
        end
        else
        begin
          Clock_SPI_Count <= Clock_SPI_Count + 1;
        end
      end  
      
    end 
    always@(posedge Masterclk)
    begin
      //if(start)
      SCLK<=r_SCLK;
    end
 always@(posedge Masterclk)
 begin
   if(!flag)begin
   if(Enable)begin
     if(rw==2 | rw==3) begin // when it reads and write OR reads only 
     if(((CLPH & FallingEdge)|(!CLPH & RisingEdge))& ReadyToReceive1)begin
       r_reg<={MISO,r_reg[0:6]};
           DataOfMaster<={MISO,DataOfMaster[0:6]};
           ReadyToReceive1<=1'b0;
           if(i<7)
             i=i+1;
               else 
                flag<=1'b1;
            end
          end
          if((CLPH & RisingEdge)|(!CLPH & FallingEdge))begin
          if(rw==1)begin
                MOSI=r_reg[7];
                r_reg={1'b0,r_reg[0:6]};
                DataOfMaster={1'b0,DataOfMaster[0:6]};
                if(i<7)
             i=i+1;
               else 
                flag<=1'b1;
            end
            if(rw==3) MOSI=r_reg[7];
              ReadyToReceive1<=1'b1;
            end
          end
        end
      end
   always@(rw) 
   begin
    we<=1'b0; //default values
    oe<=1'b0; 
    case(rw)
       Write:
       we<=1;
       Read:
       oe<=1;
       ReadANDWrite:
       begin
         we<=1;
         oe<=1;
         end
         endcase
   end             
endmodule
//------------Master testbench--------------//
module MasterTB();
  reg MISO;
  reg reset;
  reg [0:7]ExternalIn;
  reg [0:1]SPIMode;
  reg mem1;
  reg mem2;
  reg mem3;
  reg Masterclk;
  reg [0:1]rw;
  reg load;
  wire MOSI;
  wire SCLK;
  wire CS1;
  wire CS2;
  wire CS3;
  wire we;
  wire oe;
  reg Enable;
  wire flag;
  wire start;
  wire [0:7]DataOfMaster;
  reg [0:7]DataRecieved;
  reg [0:7]ExpectedOut;
  integer Succeed;
  integer i;
  
  SPI_Master UT(MISO,Masterclk,reset,ExternalIn,SPIMode,mem1,mem2,mem3,rw,load,MOSI,SCLK,CS1,CS2,CS3,Enable,flag,DataOfMaster,we,oe,start);
  always #5 Masterclk=~Masterclk;
  initial begin
    mem1=1'b0;mem2=1'b1;mem3=1'b0;
    Succeed=0;
   ///////////////////////////
   //TestCase 1: Master will receive Data=3D , SPI-Mode=0 , rw=3 read & write
   ExternalIn=8'b10111101; load=1'b1; reset=1; Masterclk=0; rw=3; Enable=1; SPIMode=0; DataRecieved=8'b10111100; //3D
   ExpectedOut=8'b00111101;
   #(5)reset=0;
  MISO=DataRecieved[0];
  #40;
   for(i=1;i<8;i=i+1) begin
   MISO=DataRecieved[i];
   #20;
   end
   $display("Test 1: ");$display("Data that will be sent =3D , The Master recieved %h",DataOfMaster);
   if(ExpectedOut==DataOfMaster) Succeed=Succeed+1; else $display("Test 1: wrong test the ExpectedOut should be %h ",ExpectedOut);
   ///////////////////////////
   
   
   ///////////////////////////
   //TestCase 2: Master will receive Data=4F , SPI-Mode=1 , rw=2 read only
   ExternalIn=8'b10111101; load=1'b1; reset=1; rw=2; Enable=1; SPIMode=1; DataRecieved=8'b11110010;
   ExpectedOut=8'b01001111;
   #(5)reset=0;
     MISO=DataRecieved[0];
  #40;
   for(i=1;i<8;i=i+1) begin
   MISO=DataRecieved[i];
   #20;
   end
   $display("Test 2: ");$display("Data that will be sent =4F , The Master recieved %h",DataOfMaster);
   if(ExpectedOut==DataOfMaster) Succeed=Succeed+1; else $display("Test 2: wrong test the ExpectedOut should be %h",ExpectedOut);
   ///////////////////////////
   
   
   ///////////////////////////
   //TestCase 3: Master is expected to not receive any Data because rw=1 which writes in slave only , SPI-Mode=3
   ExternalIn=8'b10111101; load=1'b1; reset=1; rw=1; Enable=1; SPIMode=3; DataRecieved=8'b10100101;
   ExpectedOut=8'b00000000;
   #(5)reset=0;
     MISO=DataRecieved[0];
  #40;
   for(i=1;i<8;i=i+1) begin
   MISO=DataRecieved[i];
   #20;
   end
   $display("Test 3: ");$display("Data that will be sent =A5 , Master's Data is expected to be 00 due to rw=1 'Writing only mode' , The Master Data= %h",DataOfMaster);
   if(ExpectedOut==DataOfMaster) Succeed=Succeed+1; else $display("Test 3: wrong test the ExpectedOut should be %h",ExpectedOut);
   ///////////////////////////
  
  
   ///////////////////////////
   //TestCase 4: Master will receive Data=21 , SPI-Mode=3 , rw=2 read only
   ExternalIn=8'b10111101; load=1'b1; reset=1; rw=2; Enable=1; SPIMode=3; DataRecieved=8'b10000100;
   ExpectedOut=8'b00100001;
   #(5)reset=0;
    MISO=DataRecieved[0];
  #40;
   for(i=1;i<8;i=i+1) begin
   MISO=DataRecieved[i];
   #20;
   end
   $display("Test 4: ");$display("Data that will be sent =21 , The Master recieved %h",DataOfMaster);
   if(ExpectedOut==DataOfMaster) Succeed=Succeed+1; else $display("Test 4: wrong test the ExpectedOut should be %h",ExpectedOut);
   ///////////////////////////
   
  $display("succeed %d ",Succeed," out of 4" ) ;
  $finish;
    
  end
  
endmodule
//-------------------------Slave-------------------------//
module SPI_Slave(MISO,
   reset,
ExternalIn,
SPIMode,
 we,
 oe,
 load,
 MOSI,
Clk,
 Cs,
 flag,
 DataOfSlave,
 start
 );
  input reset;
input [0:7]ExternalIn;
input [0:1]SPIMode;
input we;
input oe;
input load;
input  MOSI;
input  Clk;
input start;
output reg [0:7]DataOfSlave;
input wire Cs;
output reg MISO;
output reg flag;
integer i;
wire CLPH;
reg ReadyToReceive;
reg [0:7]r_reg;
assign CLPH=(SPIMode==1)|(SPIMode==2);
always @(posedge Clk,posedge reset)
begin
if(reset)begin //begin of reset
 flag<=1'b0;
 i<=0;
 ReadyToReceive<=0;
 DataOfSlave<=8'b0;
 if(load) begin
   r_reg<=ExternalIn;
   DataOfSlave<=ExternalIn;
 end
 else begin
   r_reg<=8'b0;
   DataOfSlave<=8'b0;
end 
end     //end of reset
else begin
  if(!flag&start)begin
    if(!CLPH)begin  //which in mode 1,2
      if(!Cs) begin   
         if(we & ReadyToReceive)begin
           r_reg<={MOSI,r_reg[0:6]};
           DataOfSlave<={MOSI,DataOfSlave[0:6]};
           if(i<7)
             i=i+1;
           else 
             flag<=1'b1;
     end
     end
   end
 //else begin
 if(CLPH) begin    //which in mode 0,3
        if(!Cs)begin
         if(oe & !we ) begin
         MISO<=r_reg[7];
         r_reg={1'b0,r_reg[0:6]};
         DataOfSlave={1'b0,DataOfSlave[0:6]};
         if(i<7)
             i=i+1;
           else 
             flag<=1'b1;
         end
       else if(oe) MISO<=r_reg[7];
         ReadyToReceive<=1'b1;
       end
       
 //end
 end
 end
 end
 end
 always @(negedge Clk)
 begin 
   if(!flag &start)begin
     if(CLPH)begin    //what happen in negative edge in mode 0,3 
     if(!Cs)begin
          if(we & ReadyToReceive) begin
             r_reg<={MOSI,r_reg[0:6]};
             DataOfSlave<={MOSI,DataOfSlave[0:6]};
          if(i<7)
             i=i+1;
          else 
             flag<=1'b1;
     end
   end
 end
 //else begin
 if(!CLPH)begin    //what happen in negative edge in mode 2,1
   if(!Cs)begin
     if(oe & !we ) begin
         MISO<=r_reg[7];
         r_reg={1'b0,r_reg[0:6]};
         DataOfSlave={1'b0,DataOfSlave[0:6]};
         if(i<7)
             i=i+1;
           else 
             flag<=1'b1;
         end
       else if(oe) MISO<=r_reg[7];
         ReadyToReceive<=1'b1;
       end
 //end
 end
 end
 end
    
endmodule
//----------------Slave-TestBench-------------------//
module SlaveTB();
  wire MISO;
  reg reset;
  reg [0:7]ExternalIn;
  reg [0:1]SPIMode;
  reg we;
  reg oe;
  reg load;
  reg MOSI;
  reg sclk;
  reg Cs;
  wire flag;
  wire [0:7]DataOfSlave;
  integer j;
  integer Succeed;
  reg [0:7]Test;
  reg [0:7]ExpectedOut;
  reg start;
  SPI_Slave SUT(.MISO(MISO),.reset(reset),.ExternalIn(ExternalIn),.SPIMode(SPIMode),.we(we),.oe(oe),.load(load),.MOSI(MOSI),.Clk(sclk),.Cs(Cs),.flag(flag),.DataOfSlave(DataOfSlave),.start(start));
  always #5 sclk=~sclk;
  initial begin
    Succeed=0;
    ////////////////////////////
    //TestCase 1: Slave will receive Data=F9 , SPI-Mode=0 , oe=1 able to send data ,we=1 able to receive data
    we=1; oe=1; reset=1; load=1; ExpectedOut=8'b11111001;start=1;
    ExternalIn=8'b10101001; sclk=0; Cs=1; Test=8'b10011111; SPIMode=0;
    #2 Cs=~Cs;
    #3 reset=~reset; 
    MOSI=Test[0];
    #(15);
    //#10 $display("Test 1:"); $display(" The Master received 1 from the Slave, The Slave sent %b",MISO);
    for(j=1;j<8;j=j+1)
    begin
      MOSI=Test[j];
      #10;
    end
    $display("Test 1:"); $display("Data that will be sent =F9 , The Slave recieved %h",DataOfSlave);
    if(ExpectedOut==DataOfSlave) Succeed=Succeed+1; else $display("Test 1: wrong test the ExpectedOut should be %h",ExpectedOut);
    ////////////////////////////
    
    
    ////////////////////////////
    //TestCase 2: Slave will receive Data=AA , SPI-Mode=1 , oe=0 unable to send data ,we=1 able to receive data
    we=1; oe=0; reset=1; load=0; ExpectedOut=8'b10101010; 
    ExternalIn=8'b10101001;  Cs=1; Test=8'b01010101; SPIMode=1;
    #2 Cs=~Cs;
    #3 reset=~reset; 
    for(j=0;j<8;j=j+1)
    begin
      MOSI=Test[j];
      #10;
    end
    $display("Test 2:"); $display("Data that will be sent =AA , The Slave recieved %h",DataOfSlave);
    if(ExpectedOut==DataOfSlave) Succeed=Succeed+1; else $display("Test 2: wrong test the ExpectedOut should be %h",ExpectedOut);
    ////////////////////////////
    
    ////////////////////////////
    //TestCase 3: Slave will send Data=A9 , SPI-Mode=2 , oe=1 unable to send data ,we=0 unable to receive data
    we=0; oe=1; reset=1; load=1; ExpectedOut=8'b00000000;
    ExternalIn=8'b10101001; sclk=0; Cs=1; Test=8'b00100000; SPIMode=2;
    #2 Cs=~Cs;
    #3 reset=~reset; 
    for(j=0;j<8;j=j+1)
    begin
      MOSI=Test[j];
      #10;
    end
    $display("Test 3:"); $display("Data that will be sent =04 , Slave's Data is expected to be 00 after shifting data to Master due to we=0 'Reading is able only' , The Slave Data=  %h",DataOfSlave);
    if(ExpectedOut==DataOfSlave) Succeed=Succeed+1; else $display("Test 3:wrong test the ExpectedOut should be %h",ExpectedOut);
    ////////////////////////////
    
    
    ////////////////////////////
    //TestCase 4: Slave will receive Data=19 , SPI-Mode=3 , oe=0 unable to send data ,we=1 able to receive data
    we=1; oe=0; reset=1; load=1; ExpectedOut=8'b10010001;
    ExternalIn=8'b10101001; sclk=0; Cs=1; Test=8'b10001001; SPIMode=3;
    #2 Cs=~Cs;
    #3 reset=~reset; 
    for(j=0;j<8;j=j+1)
    begin
      MOSI=Test[j];
      #10;
    end
    $display("Test 4:"); $display("Data that will be sent =91 , The Slave recieved %h",DataOfSlave);
    if(ExpectedOut==DataOfSlave) Succeed=Succeed+1; else $display("Test 4: wrong test the ExpectedOut should be %h",ExpectedOut);
    ////////////////////////////
    
    $display("succeed %d ",Succeed," out of 4" );
    $finish;
  end
endmodule
//----------------------Testbench---------------------//
module SPI_tb() ; 
reg[0:1]SPI_MODE; // 0/1/2/3
reg Mreset;
reg Sreset;
reg mem1;
reg mem2;
reg mem3;
reg [0:1]rw;
reg Masterclk; 
reg[0:7]MExternalIn;
reg [0:7]SExternalIn;
reg Mload;
reg Sload;
reg Enable;
wire Mflag;
wire Sflag1;
wire Sflag2;
wire Sflag3;
reg [0:7] SExpectedOutput ; 
reg [0:7] MExpectedOutput ;
reg [0:2] succeed  =3'b0 ;
wire [0:7]DataOfMaster ;
wire [0:7] DataOfSlave1 ;
wire [0:7] DataOfSlave2 ;
wire [0:7] DataOfSlave3 ;
Integration SPI (SPI_MODE,
Mreset,
Sreset,
mem1,
mem2,
mem3,
rw,
Masterclk, 
MExternalIn,
SExternalIn,,
Mload,
Sload,
Enable,
Mflag,
Sflag1,
Sflag2,
Sflag3,
DataOfMaster ,
DataOfSlave1 ,
DataOfSlave2,
DataOfSlave3
);
always #5 Masterclk=~Masterclk;
initial begin
  Masterclk = 0 ;
 ///////////////////////////////////////////////
  //TestCase 1: Master data =AA , slave data =89 , testing according to spi mode 1, 1st slave is the active slave
SPI_MODE=1;MExternalIn=8'b10101010;SExternalIn=8'b10001001;Sreset=1;Mreset=1;mem2=0;mem1=1;mem3=0;
rw = 3; Mload =1 ;Sload = 1;Enable = 1;
#2.5 Mreset=0;Sreset=0;
SExpectedOutput = 8'b10101010;
MExpectedOutput = 8'b10001001;
#170 $display("Test 1:");$display("Master will send AA to slave1, slave1 received %h",DataOfSlave1);$display("Slave1 will send 89 to Master, Master received %h",DataOfMaster);
if((SExpectedOutput == DataOfSlave1) &(MExpectedOutput == DataOfMaster))  succeed <= succeed+1 ;
  else begin $display("Test 1: wrong test the SlaveExpectedOut should be %h",SExpectedOutput);
    $display("MasterExpectedOut should be %h",MExpectedOutput);end

//TestCase 2: Master data =6D , slave data =CC , testing according to spi mode 0 , 2nd slave is the active slave
///////////////////////////////////////////////

MExternalIn=8'b01101101;SExternalIn=8'b11001100;Mreset = 1;Sreset =1 ;SPI_MODE =0 ;
mem1=0;mem2 =1;mem3 = 0;rw = 3; Mload =1 ;Sload = 1;Enable = 1;
#2.5 Mreset = 0 ;
Sreset = 0 ;
SExpectedOutput = 8'b01101101 ;
MExpectedOutput = 8'b11001100;
#185 $display("Test 2:");$display("Master will send 6D to slave2, slave2 received %h",DataOfSlave2);$display("Slave2 will send CC to Master, Master received %h",DataOfMaster);
if((SExpectedOutput == DataOfSlave2) &(MExpectedOutput == DataOfMaster))  succeed <= succeed+1 ;
else begin $display("Test 2: wrong test the SlaveExpectedOut should be %h",SExpectedOutput);
    $display("MasterExpectedOut should be %h",MExpectedOutput);end
///////////////////////////////////////////////
 ///////////////////////////////////////////////
//TestCase 3: Master data =F2 , slave data =0D , testing according to spi mode 4, 1st slave is the active slave
SPI_MODE=3;MExternalIn=8'b00101000;SExternalIn=8'b00000111;Sreset=1;Mreset=1;mem1=1;mem3=0;mem2=0;
#2.5 Mreset=0;Sreset=0;
SExpectedOutput = 8'b00101000;
MExpectedOutput = 8'b00000111;
#170 $display("Test 3:");$display("Master will send 28 to slave1, slave1 received %h",DataOfSlave1);$display("Slave1 will send 07 to Master, Master received %h",DataOfMaster);
if((SExpectedOutput == DataOfSlave1) &(MExpectedOutput == DataOfMaster))  succeed <= succeed+1 ;
else begin $display("Test 3: wrong test the SlaveExpectedOut should be %h",SExpectedOutput);
    $display("MasterExpectedOut should be %h",MExpectedOutput);end
///////////////////////////////////////////////
//TestCase 4: Master data =F2 , slave data =0D , testing according to spi mode 3, 3rd slave is the active slave
SPI_MODE=2;MExternalIn=8'b01110010;SExternalIn=8'b00001110;Sreset=1;Mreset=1;mem3=1;mem1=0;
#2.5 Mreset=0;Sreset=0;
SExpectedOutput = 8'b01110010;
MExpectedOutput = 8'b00001110;
#190 $display("Test 4:");$display("Master will send 72 to slave3, slave3 received %h",DataOfSlave3);$display("Slave3 will send 0E to Master, Master received %h",DataOfMaster);
if((SExpectedOutput == DataOfSlave3) &(MExpectedOutput == DataOfMaster))  succeed <= succeed+1 ;
else begin $display("Test 4: wrong test the SlaveExpectedOut should be %h",SExpectedOutput);
    $display("MasterExpectedOut should be %h",MExpectedOutput);end
///////////////////////////////////////////////





///////////////////////////////////////////////
//TestCase 5: Master data = 7 , testing according to spi mode 0, 1st slave is the active slave
rw = 1 ;
SPI_MODE=0;MExternalIn=8'b00000111;Sreset=1;Mreset=1;mem1=1;mem3=0;mem2=0;
#2.5 Mreset=0;Sreset=0;
SExpectedOutput = 8'b00000111 ;
#180 $display("Test 5:");$display("Master will send 07 to slave1, slave1 received %h",DataOfSlave1);
if(SExpectedOutput == DataOfSlave1)  succeed <= succeed+1 ;
else begin $display("Test 5: wrong test the SlaveExpectedOut should be %h",SExpectedOutput);
  end
///////////////////////////////////////////////

///////////////////////////////////////////////
//TestCase 6: Slave3 data = C , testing according to spi mode 3, 3rd slave is the active slave
rw = 2 ;
SPI_MODE=3;SExternalIn=8'b00001100;Sreset=1;Mreset=1;mem1=0;mem3=1;
#2.5 Mreset=0;Sreset=0;
MExpectedOutput = 8'b00001100 ;
#170 $display("Test 6:");$display(" slave3 will send 0C, Master received %h",DataOfMaster);
if(MExpectedOutput == DataOfMaster)  succeed <= succeed+1 ;
else begin 
    $display(" Test 6: wrong test the MasterExpectedOut should be %h",MExpectedOutput);end
///////////////////////////////////////////////

#10 $display("succeed %d ",succeed,"out of 6" ) ;


#5 $finish ;
end


endmodule
//------------------------------Integration----------------------------//
module Integration(SPI_MODE,
   Mreset,
   Sreset,
   mem1,
   mem2,
  mem3,
   rw,
   Masterclk, 
   MExternalIn,
  SExternalIn,,
    Mload,
  Sload,
   Enable,
    Mflag,
  Sflag1,
  Sflag2,
  Sflag3,
DataOfMaster ,
DataOfSlave1 ,
DataOfSlave2,
DataOfSlave3
  );
  input wire [0:1]SPI_MODE;
  input  Mreset;
  input  Sreset;
  input  mem1;
  input  mem2;
  input  mem3;
  input  [0:1]rw;
  input  Masterclk; 
  input [0:7]MExternalIn;
  input  [0:7]SExternalIn;
  input Mload;
  input wire Sload;
  input   Enable;
  output wire Mflag;
  output wire Sflag1;
  output wire Sflag2;
  output wire Sflag3;
  output wire [0:7] DataOfMaster ;
  output wire [0:7] DataOfSlave1 ;
  output wire [0:7] DataOfSlave2 ;
  output wire [0:7] DataOfSlave3 ;
  reg MISO;
  wire SCLK;
  wire MOSI;
  wire MISO1;
  wire MISO2;
  wire MISO3;
  wire CS1;
  wire CS2;
  wire CS3;
  wire oe;
  wire we;
  wire start;
//to check the MISO with the real value needed to be transfered
  always @(posedge Masterclk,negedge Masterclk)
  begin
    //if(MISO1 || ~MISO1)begin
      if(mem1)begin//IMPORTANT:the upper if condition is commented to make the MISO assign to MISO1/2/3 
      //even if it is x which is then checked in the master module to prevent assigning the x the the master data 
      //and the main purpose is to avoid assigning the last value of MISO which can be signed from the prev slave
      MISO=MISO1;
    //end 
  end
    //if(MISO2 || ~MISO2)begin
      if(mem2)begin
      MISO=MISO2;
    //end 
  end
    //if(MISO3 || ~MISO3)begin
      if(mem3)begin
      MISO=MISO3;
    //end 
  end
  end
 SPI_Master M(.MISO( MISO),.Masterclk(Masterclk), // clk of the master 
.reset (Mreset),
.ExternalIn(MExternalIn),
.SPIMode(SPI_MODE),
 .mem1(mem1),
.mem2(mem2),
.mem3(mem3),
. rw(rw),
. load(Mload),
. MOSI(MOSI),
. SCLK(SCLK),   //this clock will be used in communication and shift register
                    // it will be generated with the clock of the master 
. CS1(CS1),
. CS2(CS2),
.CS3(CS3),
. Enable(Enable),
. flag(Mflag),
.DataOfMaster(DataOfMaster),
.we(we),
.oe(oe),
.start(start)
);
SPI_Slave S1(
. MISO(MISO1),
  . reset(Sreset),
.ExternalIn(SExternalIn),
.SPIMode(SPI_MODE),
. we(we),
.oe(oe),
. load(Sload),
. MOSI(MOSI),
. Clk(SCLK),
.Cs(CS1),
. flag(Sflag1),
.DataOfSlave(DataOfSlave1),
.start(start)
);
SPI_Slave S2(
. MISO(MISO2),
  . reset(Sreset),
.ExternalIn(SExternalIn),
.SPIMode(SPI_MODE),
. we(we),
.oe(oe),
. load(Sload),
. MOSI(MOSI),
. Clk(SCLK),
.Cs(CS2),
. flag(Sflag2),
.DataOfSlave(DataOfSlave2),
.start(start)
);
SPI_Slave S3(
. MISO(MISO3),
  . reset(Sreset),
.ExternalIn(SExternalIn),
.SPIMode(SPI_MODE),
. we(we),
.oe(oe),
. load(Sload),
. MOSI(MOSI),
. Clk(SCLK),
.Cs(CS3),
. flag(Sflag3),
.DataOfSlave(DataOfSlave3),
.start(start)
);
endmodule
