//异步FIFO设计，使用格雷码
module fifo_async#(							//该#号表示用于指定模块的三个参数的默认值，这些参数可以在模块实例化时被重载
	parameter data_width = 16,				//数据是16bit
	parameter data_depth = 256,				//共有256行数据，对应2^8次地址
	parameter addr_width = 8
	)
(
	input rst_n,
	input wr_clk,
	input wr_en,
	input [data_width-1:0] din,
	input rd_clk,
	input rd_en,
	output reg valid,
	output reg [data_width-1:0] dout,
	output empty,
	output full
	);

	reg [addr_width:0] wr_addr_ptr; 		//地址指针，比地址多一位，MSB用于检测是否同一圈
	reg [addr_width:0] rd_addr_ptr;
	wire [addr_width-1:0] wr_addr;			//RAM地址
	wire [addr_width-1:0] rd_addr;			

	wire [addr_width:0] wr_addr_gray;		//地址指针对应的格雷码；
	reg [addr_width:0] wr_addr_gray_d1;		//第一级寄存器
	reg [addr_width:0] wr_addr_gray_d2;		//第二级寄存器
	wire [addr_width:0] rd_addr_gray;	
	reg [addr_width:0] rd_addr_gray_d1;
	reg [addr_width:0] rd_addr_gray_d2;

	reg [data_width-1:0] fifo_ram[data_depth-1:0];

	//功能实现write -fifo					用for循环应该用硬件的视角看，其实生成了256个begin-end，同时对ram进行初始化操作
	genvar i;
	generate
		for(int i =0; i<data_depth; i=i+1)
		begin:fifo_init
			always@(posedge wr_clk or negedge rst_n)
			begin
				if(!rst_n)
					fifo_ram[i] <= h'0; //fifo复位后输出总线上是0
				else if(wr_en && (~full))
					fifo_ram[wr_addr] <= din;
				else
					fifo_ram[wr_addr] <= fifo_ram[wr_addr];
			end
		end
	endgenerate

	//		read -fifo
	always @(posedge rd_clk, negedge rst_n)
		begin
			if(!rst_n)
			begin
				dout <= 'h0;
				valid <= 1'b0;
			end
			else if(rd_en && (~empty))
			begin
				dout <= fifo_ram[rd_addr];
				valid <= 1'b1;
			end
			else
			begin
				dout <= 'h0;
				valid <= 1'b0;
			end
		end

	assign wr_addr = wr_addr_ptr[addr_width-1-:addr_width];		//pointer是9位的，只取后面八位
	assign rd_addr = rd_addr_ptr[addr_width-1-:addr_width];

	// ====================================格雷码同步化
	always@(posedge wr_clk)									//因为是跨时钟域，所以要打两拍
	begin
		rd_addr_gray_d1 <= rd_addr_gray;					//写时钟上升沿来了，要给读的地址打两拍同步，再判断空满
		rd_addr_gray_d2 <= rd_addr_gray_d1;					//因此后面的empty和full，用的是d2的值
	end

	always@(posedge  wr_clk or negedge rst_n)
	begin
		if(!rst_n)
			wr_addr_ptr <= 'h0;
		else if(wr_en && (~full))
			wr_addr_ptr <= wr_addr_ptr + 1;
		else 
			wr_addr_ptr <= wr_addr_ptr;
	end

	// =====================================rd_clk
	always@(posedge  rd_clk )
	begin
		wr_addr_gray_d1 <= wr_addr_gray;
		wr_addr_gray_d2 <= wr_addr_gray_d1;
	end
	always@(posedge rd_clk ,negedge rst_n)
	begin
		if(!rst_n)
			rd_addr_ptr <= 'h0;
		else if(rd_en && (~empty))
			rd_addr_ptr <= rd_addr_ptr + 1;
		else
			rd_addr_ptr <= rd_addr_ptr;
	end

	// ================================binary转格雷码，空满信号
	assign wr_addr_gray = (wr_addr_ptr>>1)^wr_addr_ptr;
	assign rd_addr_gray = (rd_addr_ptr>>1)^rd_addr_ptr;
																				//高两位不同，详情见
	assign full = (wr_addr_gray=={~(rd_addr_gray_d2[addr_width-:2]),rd_addr_gray_d2[addr_width-2:0]})
	assign empty = (rd_addr_gray == wr_addr_gray_d2);//https://blog.csdn.net/yh13572438258/article/details/121862055

endmodule : fifo_async











