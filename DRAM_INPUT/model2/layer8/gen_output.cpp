#include <iostream>
#include <fstream>
#include <cstdio>

//===input size===
#define input_W (53)
#define input_H (53)
#define input_C (45)
//===filter size===
#define f_size (5)
#define f_channel (64)
//===output size===
#define output_W (25)
#define output_H (25)
//max pooling
#define max_pooling (0)
#define stride (2)

using namespace std;

unsigned int little_big(unsigned int little)
{
    return((little&0xff)<<24)+((little&0xff00)<<8)+((little&0xff0000)>>8)+((little>>24)&0xff);
}

int	func_max(int v1,int v2)
{
	return	(v1>=v2)?v1:v2;
}

int	func_max_pooling(int v1,int v2,int v3,int v4)
{
	return	func_max(func_max(v1,v2),func_max(v3,v4));
}


int main(int argc, char *argv[ ]){

    int *input = new int[input_W * input_H * input_C];
    int *weight = new int[f_size * f_size * input_C * f_channel];
    int *output = new int[output_W * output_H * f_channel];
    int tmp;

    int i, f, j ,z;

    //load input 
    ifstream fin("input.txt");
    for(i = 0; i < (input_W * input_H * input_C); i++){
        fin >> tmp;
        input[i] = tmp;
        //cout << "index : " << i << " data : " << input[i] << endl;
    }
    fin.close();

    //load weight
    ifstream fweight("weight.txt");
    for(i = 0; i < (f_size * f_size * input_C * f_channel); i++){
        fweight >> tmp;
        weight[i] = tmp;
        //cout << "index : " << i << " data : " << weight[i] << endl;
    }
    fin.close();

    fstream file;
    file.open("output.txt", ios::out);

    for(int f_ch = 0; f_ch < f_channel; f_ch++){
        for(int out_h = 0; out_h < output_H; out_h++){
            for(int out_w = 0; out_w < output_W; out_w++){
                for(int in_c = 0; in_c < input_C; in_c++){ //filter channel
                    for(int f_h = 0; f_h < f_size; f_h++){
                        for(int f_w = 0; f_w < f_size; f_w++){
                            if((f_ch * output_W * output_H + out_h * output_W + out_w) == atoi(argv[1]) && in_c == atoi(argv[2]))
                            {
                                // printf("f_ch:%d  in_c:%d  f_h:%d  f_w:%d\n",f_ch,in_c,f_h,f_w);
                                // printf("output : %d\n",f_ch * output_W * output_H + out_h * output_W + out_w);
                                // printf("input : %d\n",(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w);
                                // printf("weight : %d\n",(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w);
                                // printf("output : %d\n",output[f_ch * output_W * output_H + out_h * output_W + out_w]);
                                // printf("input : %d\n",input[(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w]);
                                // printf("weight : %d\n",weight[(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w]);
                                // printf("\n");
                            }
                            /*output[f_ch * output_W * output_H + out_h * output_W + out_w] = output[f_ch * output_W * output_H + out_h * output_W + out_w] + 
                                                        input[(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w] * 
                                                        weight[(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w]; 
                            */
                        }
                    }
                }
                //printf("output[%d] : %d\n", f_ch * output_W * output_H + out_h * output_W + out_w, output[f_ch * output_W * output_H + out_h * output_W + out_w]);
                //file << output[f_ch * output_W * output_H + out_h * output_W + out_w] << endl;
            }
        }
    }
int PE = 0;
    for(int f_ch = 0; f_ch < f_channel; f_ch++){
        for(int out_h = 0; out_h < output_H; out_h++){
            for(int out_w = 0; out_w < output_W; out_w++){
                for(int in_c = 0; in_c < input_C; in_c++){ //filter channel
                    for(int f_w = 0; f_w < f_size; f_w++){
                        for(int f_h = 0; f_h < f_size; f_h++){
                            if((f_ch * output_W * output_H + out_h * output_W + out_w) == atoi(argv[1]) && in_c == atoi(argv[2]))
                            {
                                PE ++ ;
                                // printf("f_ch:%d  in_c:%d  f_h:%d  f_w:%d\n",f_ch,in_c,f_h,f_w);
                                // printf("output : %d\n",f_ch * output_W * output_H + out_h * output_W + out_w);
                                // printf("input : %d\n",(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w);
                                // printf("weight : %d\n",(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w);
                                // printf("output : %d\n",output[f_ch * output_W * output_H + out_h * output_W + out_w]);
                                // printf("input : %d\n",input[(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w]);
                                // printf("weight : %d\n",weight[(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w]);
                                // printf("\n");
                                // if(f_h == 0)
                                //     printf("\n");
                                // printf("%3d ",input[(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w]);
                                
                            }
                            output[f_ch * output_W * output_H + out_h * output_W + out_w] = output[f_ch * output_W * output_H + out_h * output_W + out_w] + 
                                                        input[(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w] * 
                                                        weight[(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w]; 
                            
                            if(((f_ch * output_W * output_H + out_h * output_W + out_w) == atoi(argv[1])) && (PE % 9 == 0 || (f_w==f_size-1&&f_h==f_size-1)) && in_c == atoi(argv[2]))
                                printf("\nch=%d h=%d w=%d : %d\n",in_c,f_h,f_w,output[f_ch * output_W * output_H + out_h * output_W + out_w]);
                        }
                    }
                    PE = 0;
                }
                //printf("output[%d] : %d\n", f_ch * output_W * output_H + out_h * output_W + out_w, output[f_ch * output_W * output_H + out_h * output_W + out_w]);
                file << output[f_ch * output_W * output_H + out_h * output_W + out_w] << endl;
            }
        }
    }

    for(int f_ch = 0; f_ch < f_channel; f_ch++){
        for(int out_h = 0; out_h < output_H; out_h++){
            for(int out_w = 0; out_w < output_W; out_w++){
                for(int in_c = 0; in_c < input_C; in_c++){ //filter channel
                    for(int f_w = 0; f_w < f_size; f_w++){
                        for(int f_h = 0; f_h < f_size; f_h++){
                            if((f_ch * output_W * output_H + out_h * output_W + out_w) == atoi(argv[1]) && in_c == atoi(argv[2]))
                            {
                                // printf("f_ch:%d  in_c:%d  f_h:%d  f_w:%d\n",f_ch,in_c,f_h,f_w);
                                // printf("output : %d\n",f_ch * output_W * output_H + out_h * output_W + out_w);
                                // printf("input : %d\n",(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w);
                                // printf("weight : %d\n",(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w);
                                // printf("output : %d\n",output[f_ch * output_W * output_H + out_h * output_W + out_w]);
                                // printf("input : %d\n",input[(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w]);
                                // printf("weight : %d\n",weight[(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w]);
                                // printf("\n");
                                if(f_h == 0)
                                    printf("\n");
                                printf("%3d ",input[(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w]);
                                
                            }
                            /*output[f_ch * output_W * output_H + out_h * output_W + out_w] = output[f_ch * output_W * output_H + out_h * output_W + out_w] + 
                                                        input[(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w] * 
                                                        weight[(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w]; 
                            */
                        }
                    }
                }
                //printf("output[%d] : %d\n", f_ch * output_W * output_H + out_h * output_W + out_w, output[f_ch * output_W * output_H + out_h * output_W + out_w]);
                //file << output[f_ch * output_W * output_H + out_h * output_W + out_w] << endl;
            }
        }
    }
    printf("\n");
    for(int f_ch = 0; f_ch < f_channel; f_ch++){
        for(int out_h = 0; out_h < output_H; out_h++){
            for(int out_w = 0; out_w < output_W; out_w++){
                for(int in_c = 0; in_c < input_C; in_c++){ //filter channel
                    for(int f_w = 0; f_w < f_size; f_w++){
                        for(int f_h = 0; f_h < f_size; f_h++){
                            if((f_ch * output_W * output_H + out_h * output_W + out_w) == atoi(argv[1]) && in_c == atoi(argv[2]))
                            {
                                // printf("f_ch:%d  in_c:%d  f_h:%d  f_w:%d\n",f_ch,in_c,f_h,f_w);
                                // printf("output : %d\n",f_ch * output_W * output_H + out_h * output_W + out_w);
                                // printf("input : %d\n",(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w);
                                // printf("weight : %d\n",(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w);
                                // printf("output : %d\n",output[f_ch * output_W * output_H + out_h * output_W + out_w]);
                                // printf("input : %d\n",input[(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w]);
                                // printf("weight : %d\n",weight[(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w]);
                                // printf("\n");
                                if(f_h == 0)
                                    printf("\n");
                                printf("%3d ",weight[(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w]);
                                
                            }
                            /*output[f_ch * output_W * output_H + out_h * output_W + out_w] = output[f_ch * output_W * output_H + out_h * output_W + out_w] + 
                                                        input[(in_c * input_H * input_W) + (out_h * stride) * input_W + (out_w * stride) + f_h * input_W + f_w] * 
                                                        weight[(f_ch * input_C * f_size * f_size) + (in_c * f_size * f_size) + (f_size * f_h) + f_w]; 
                            */
                        }
                    }
                }
                //printf("output[%d] : %d\n", f_ch * output_W * output_H + out_h * output_W + out_w, output[f_ch * output_W * output_H + out_h * output_W + out_w]);
                //file << output[f_ch * output_W * output_H + out_h * output_W + out_w] << endl;
            }
        }
    }
    // printf(": %d \n",output[2570940]);
    // printf(": %d %d %d\n",output[0],input[0],weight[0]);
    // 
    if(max_pooling == 1)
    {
		int v1,v2,v3,v4;
		i=0;
    	j=0;
		z=0;
    	FILE *pfile;
    	pfile = fopen("output_max_pooling.txt","w");
		int max_pooling_output_W = output_W/2;
		int max_pooling_output_H = output_H/2;
		int *output_max_pooling = new int[(max_pooling_output_W * max_pooling_output_H * f_channel) / 4];
		for ( z = 0; z < f_channel; z = z + 1)
		{
			for ( i = 0; i < max_pooling_output_H; i = i + 1)
			{
				for ( j = 0; j < max_pooling_output_W; j = j + 1)
				{
					v1	=	output[z*(output_W*output_H) + i*2*output_W + j*2];
					v2	=	output[z*(output_W*output_H) + i*2*output_W + j*2 + 1];
					v3	=	output[z*(output_W*output_H) + (i*2+1)*output_W + j*2];
					v4	=	output[z*(output_W*output_H) + (i*2+1)*output_W + j*2 + 1];
					output_max_pooling[i*output_W + j]	=	func_max_pooling(v1,v2,v3,v4);
					fprintf(pfile,"%d\n",output_max_pooling[i*output_W + j]);
				}
			}
		}
		fclose(pfile);
		
    }
    

    

    // for (z = 0; z < (output_W*output_H*f_channel); ++z){
    //     if(i==0)printf("-----%d-----\n",z);
    //     if(i==16384){
    //         j++;
    //         fprintf(pfile,":02000004");
    //         fprintf(pfile,"%04X",j);
    //         fprintf(pfile,"00\n");
    //         i=0;
    //     }
    //     fprintf(pfile,":10");
    //     fprintf(pfile,"%03X",i/4);
    //     fprintf(pfile,"000");
    //     //if(z<100)printf("%d\n",arr[z]);
    //     fprintf(pfile,"%08X",little_big(output[z++]));
    //     fprintf(pfile,"%08X",little_big(output[z++]));
    //     fprintf(pfile,"%08X",little_big(output[z++]));
    //     fprintf(pfile,"%08X",little_big(output[z]));
    //     fprintf(pfile,"00\n");
    //     i=i+4;
    //     // printf("%08X\n",little_big(i++));
    // }

    file.close();





    return 0;
}