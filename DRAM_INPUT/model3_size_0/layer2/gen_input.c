#include <stdlib.h>
#include <stdio.h>
#include <time.h>

#define input_W 26
#define input_H 26
#define input_C 128
//416 * 416 * 3 = 519168

unsigned int little_big(unsigned int little)
{
    return((little&0xff)<<24)+((little&0xff00)<<8)+((little&0xff0000)>>8)+((little>>24)&0xff);
}

int main(){
    
    FILE *output;
    int arr[input_H*input_W*input_C] = {0};
    FILE *pfile;
    pfile = fopen("input.hex","w");

    output = fopen("input.txt", "wt");
    /* 設定亂數種子 */
    srand( time(NULL) );

    int i, f, j ,z;

    for(int i = 0; i < (input_W*input_H*input_C); i++){
        arr[i] = rand()%11-5;
        fprintf(output, "%d\n", arr[i]);
        //printf("data index %d = %d\n", i, arr[i]);
    }

    i=0;
    j=0;
    for (z = 0; z < (input_W*input_H*input_C); ++z){
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

    fclose(output);
    return 0;
}