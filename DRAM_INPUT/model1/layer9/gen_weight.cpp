#include <iostream>
#include <fstream>
#include <cstdio>

#define input_C 3
#define f_size 3
#define f_channel 64

using namespace std;

unsigned int little_big(unsigned int little)
{
    return((little&0xff)<<24)+((little&0xff00)<<8)+((little&0xff0000)>>8)+((little>>24)&0xff);
}

int main(){
    
    fstream output;
    int *arr = new int[f_size*f_size*input_C*f_channel];
    FILE *pfile;
    pfile = fopen("weight.hex","w");

    output.open("weight.txt", ios::out);
    /* 設定亂數種子 */
    srand( time(NULL) );

    int i, f, j ,z;

    for(i = 0; i < (f_size*f_size*input_C*f_channel); i++){
        arr[i] = rand()%3-1;
        output << arr[i] << endl;
        printf("weight index %d = %d\n", i, arr[i]);
    }

    i=0;
    j=0;

    for (z = 0; z < (f_size*f_size*input_C*f_channel); ++z){
        if(i==0)printf("-----%d-----\n",z);
        if(i==16384){
            j++;
            fprintf(pfile,":02000004");
            fprintf(pfile,"%04X",j);
            fprintf(pfile,"00\n");
            i=0;
        }
        fprintf(pfile,":10");
        fprintf(pfile,"%03X",i/4);
        fprintf(pfile,"000");
        //if(z<100)printf("%d\n",arr[z]);
        fprintf(pfile,"%08X",little_big(arr[z++]));
        fprintf(pfile,"%08X",little_big(arr[z++]));
        fprintf(pfile,"%08X",little_big(arr[z++]));
        fprintf(pfile,"%08X",little_big(arr[z]));
        fprintf(pfile,"00\n");
        i=i+4;
        // printf("%08X\n",little_big(i++));
    }

    output.close();
    return 0;
}