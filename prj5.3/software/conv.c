#include "printf.h"
#include "trap.h"
#include "mul.h"
#include "div.h"
#include "perf_cnt.h"

#define FRAC_BIT 10

#define RD_ADDR 135106448               //输入图像在内存中的位置？
#define RD_SIZE_D0 1                    //输入图像1个
#define RD_SIZE_D1 1                    //单通道
#define RD_SIZE_D2 28                   //行
#define RD_SIZE_D3 28                   //列

#define WEIGHT_ADDR 134217728
#define WEIGHT_SIZE_D0 20               //卷积核20组
#define WEIGHT_SIZE_D1 1                //单通道
#define WEIGHT_SIZE_D2 5
#define WEIGHT_SIZE_D3 5

#define WR_ADDR 135108240
#define WR_SIZE_D0 1                    //输出图像一个
#define WR_SIZE_D1 20                   //输出图像20通道
#define WR_SIZE_D2 12
#define WR_SIZE_D3 12

#define KERN_ATTR_CONV_PAD 0            //输入图像是否填充
#define KERN_ATTR_CONV_STRIDE 1         //输入图像步幅
#define KERN_ATTR_POOL_PAD 0            //池化时是否填充
#define KERN_ATTR_POOL_KERN_SIZE 2      //池化选择范围
#define KERN_ATTR_POOL_STRIDE 2         //池化移动步幅

//MMIO register address of DNN accelerator
#define GPIO_START_ADDR    0x60030000
#define GPIO_DONE_ADDR     0x60030008

struct size_vec4
{
	unsigned d0;
	unsigned d1;
	unsigned d2;
	unsigned d3;
};

struct mem_addr
{
	unsigned rd_addr;
	unsigned weight_addr;
	unsigned wr_addr;
};

int mul(short a, short b)
{
#ifndef USE_MUL
	int ans = mul_ll(a, b);
#else
	int ans = a * b;
#endif
	return ans;
}

struct mem_addr addr = {RD_ADDR, WEIGHT_ADDR, WR_ADDR};
struct size_vec4 rd_size = {RD_SIZE_D0, RD_SIZE_D1, RD_SIZE_D2, RD_SIZE_D3};
struct size_vec4 wr_size = {WR_SIZE_D0, WR_SIZE_D1, WR_SIZE_D2, WR_SIZE_D3};
struct size_vec4 weight_size = {WEIGHT_SIZE_D0, WEIGHT_SIZE_D1, WEIGHT_SIZE_D2, WEIGHT_SIZE_D3};

struct size_vec4 conv_size;

extern char _binary_data_result_bin_start[];
extern char _binary_data_result_bin_size[];
//test
void convolution()              //步幅为一，因此不考虑奇偶矩阵的区别
{
	short *in = (short *)addr.rd_addr;
	short *weight = (short *)addr.weight_addr;
	short *out = (short *)addr.wr_addr;

	unsigned output_offset = 0;
	unsigned input_offset = 0;

	unsigned input_fm_w = rd_size.d3;
	unsigned input_fm_h = rd_size.d2;

	unsigned pad = KERN_ATTR_CONV_PAD;
	unsigned pad_len = pad << 1;

	unsigned conv_out_w = rd_size.d3 - weight_size.d3 + pad_len;
	unsigned conv_out_h = rd_size.d2 - weight_size.d2 + pad_len;

	unsigned stride = KERN_ATTR_CONV_STRIDE;

	conv_out_w = div(conv_out_w, stride);
	conv_out_h = div(conv_out_h, stride);

	conv_out_w++;
	conv_out_h++;

	conv_size.d0 = wr_size.d0;
	conv_size.d1 = wr_size.d1;
	conv_size.d2 = conv_out_h;              //输出矩阵的高
	conv_size.d3 = conv_out_w;              //输出矩阵的宽

	//TODO: Please add your implementation here
        //根据宏定义可知，无边界填充
        typedef short (*IN)[RD_SIZE_D1][input_fm_h][input_fm_w];
	typedef short (*WEIGHT)[WEIGHT_SIZE_D0][WEIGHT_SIZE_D1][mul(WEIGHT_SIZE_D2, WEIGHT_SIZE_D3) + 1];
	typedef short (*OUT)[WR_SIZE_D1][conv_out_h][conv_out_w];
	IN in_array = (IN)(in + input_offset);
	WEIGHT weight_array = (WEIGHT)weight;
	OUT out_array = (OUT)(out + output_offset);
        unsigned x,y;                                //遍历输出特征图的宽和高
        unsigned no,ni;                              //遍历输出的特征图和卷积核，以及输入的图像
        unsigned kx,ky;                              //遍历卷积核的宽和高
        unsigned iw,ih;                              //卷积运算时选择的输入图的位置
        unsigned temp;
        for(no=0;no<wr_size.d1;no++)
        {
                for(ni=0;ni<rd_size.d1;ni++)
                {
                        for(y=0;y<conv_out_h;y++)
                        {
                                for(x=0;x<conv_out_w;x++)
                                {
                                        temp = 0;
                                        if(ni==0)
                                                (*out_array)[no][y][x] = (*weight_array)[no][0][0];
                                        for(ky=0;ky<weight_size.d2;ky++)
                                        {
                                                for(kx=0;kx<weight_size.d3;kx++)
                                                {
                                                        iw = kx + mul(x,stride) - pad;
                                                        ih = ky + mul(y,stride) - pad;
                                                        if(iw>=0 && iw<input_fm_w && ih>=0 && ih<input_fm_h)
                                                                temp += mul((*in_array)[ni][ih][iw],(*weight_array)[no][ni][mul(ky, WEIGHT_SIZE_D3) + kx + 1]);
                                                }
                                        }
                                        (*out_array)[no][y][x] += (short)((int)(temp >> FRAC_BIT));
                                }
                        }
                }
        }
}


void pooling()
{
	short *out = (short *)addr.wr_addr;

	unsigned output_offset = 0;
	unsigned input_offset = 0;

	unsigned input_fm_w = conv_size.d3;
	unsigned input_fm_h = conv_size.d2;

	unsigned pad = KERN_ATTR_POOL_PAD;
	unsigned pad_len = pad << 1;

	unsigned pad_w_test = conv_size.d3 - KERN_ATTR_POOL_KERN_SIZE;
	unsigned pad_h_test = conv_size.d2 - KERN_ATTR_POOL_KERN_SIZE;

	unsigned pool_out_w = pad_w_test + pad_len;
	unsigned pool_out_h = pad_h_test + pad_len;

	unsigned stride = KERN_ATTR_POOL_STRIDE;

        //需要考虑方矩阵的长度为奇还是为偶
	unsigned pad_w_test_remain = pad_w_test - mul(div(pad_w_test, stride), stride);
	unsigned pad_h_test_remain = pad_h_test - mul(div(pad_h_test, stride), stride);

	pool_out_w = div(pool_out_w, stride);
	pool_out_h = div(pool_out_h, stride);
	pool_out_w++;
	pool_out_h++;

	if ((!pad) && (pad_w_test_remain || pad_h_test_remain))         //考虑池化时是否填充
	{
		pool_out_w++;
		pool_out_h++;
	}
        //经过上述操作，得出来的输出结果的高和宽时正确的
        //此高度和宽度说明奇数矩阵需要填充边缘值
        //(虽然输出的高宽就是12,所以未考虑奇数的情况)
	//TODO: Please add your implementation here
        typedef short (*IN)[WEIGHT_SIZE_D0][input_fm_h][input_fm_w];
	typedef short (*OUT)[WEIGHT_SIZE_D0][pool_out_h][pool_out_w];
	IN in_array = (IN)(out + input_offset);
	OUT out_array = (OUT)(out + output_offset);
        unsigned no;
        unsigned x,y;
        unsigned kx,ky;
        unsigned iw,ih;
        short max;
        for(no=0;no<wr_size.d1;no++)
        {
                for(y=0;y<pool_out_h;y++)
                {
                        for(x=0;x<pool_out_w;x++)
                        {
                                max = 0x8000;
                                for(ky=0;ky<KERN_ATTR_POOL_KERN_SIZE;ky++)
                                {
                                        for(kx=0;kx<KERN_ATTR_POOL_KERN_SIZE;kx++)
                                        {
                                                iw = mul(x,KERN_ATTR_POOL_KERN_SIZE) - pad + kx;
                                                ih = mul(y,KERN_ATTR_POOL_KERN_SIZE) - pad + ky;
                                                if(iw>=0 && iw<input_fm_w && ih>=0 && ih<input_fm_h)
                                                {
                                                        if(max < (*in_array)[no][ih][iw])
                                                                max = (*in_array)[no][ih][iw];
                                                }
                                        }
                                }
                                (*out_array)[no][y][x] = max;
                        }
                }
        }
}

#ifdef USE_HW_ACCEL
void launch_hw_accel()          //硬件加速器的软件实现部分
{
	volatile int* gpio_start = (void*)(GPIO_START_ADDR);
	volatile int* gpio_done = (void*)(GPIO_DONE_ADDR);

	//TODO: Please add your implementation here
        *(gpio_start) |= 0x1;
        while(!(*(gpio_done) & 0x1))
                ;
        *(gpio_start) &= 0xfffe;
}
#endif

int comparing()
{
	char *out = (char *)addr.wr_addr;
	char *result = (char *)_binary_data_result_bin_start;

#ifdef USE_HW_ACCEL
	int count = (int)_binary_data_result_bin_size + 
		    (16 - WR_SIZE_D3) * 2 * WR_SIZE_D2 * WR_SIZE_D1;
#else
	int count = (int)_binary_data_result_bin_size;
#endif

	for (int i = 0, j = 0; i < count; i++)
	{
#ifdef USE_HW_ACCEL
		int alignment = i & 0x0000001f;
		if (alignment >= (WR_SIZE_D3 << 1))
			continue;
#endif
		if (*(out + i) != *(result + j))
		{
			printf("Failed! at address %x and %x with data %x and %x\n", out + i, result + j, *(out + i), *(result + j));
			return 1;
		}
		j++;
	}

	printf("Passed!\n");
	return 0;
}

int main()
{
        Result res;
        bench_prepare(&res);
#ifdef USE_HW_ACCEL
	printf("Launching task...\n");
	launch_hw_accel();
#else
	printf("starting convolution\n");
	convolution();
	printf("starting pooling\n");
	pooling();
#endif

	int result = comparing();
        bench_done(&res);
        printf("========== Performance Counter ==========\n");
        printf("Runtime Cycle: %u\n",res.msec);
        printf("Instruction Number: %u\n",res.instrnum);
        printf("Instruction Request Cycle: %u\n",res.instrreq);
        printf("Instruction Valid Cycle: %u\n",res.instrvalid);
        printf("Store Request Cycle: %u\n",res.memsreq);
        printf("Load Request Cycle: %u\n",res.memlreq);
        printf("Load Valid Cycle: %u\n",res.memvalid);
        printf("Jump Number: %u\n",res.jumpnum);
        printf("Branch Number: %u\n",res.branchnum);
        printf("Wrong Branch Number: %u\n",res.wrongbranchnum);
        printf("=========================================\n");
	printf("benchmark finished\n");

	if (result == 0) {
		hit_good_trap();
	} else {
		nemu_assert(0);
	}

	return 0;
}
