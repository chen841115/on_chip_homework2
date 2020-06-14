#include <stdio.h>

int main(){
    int i;
    FILE *pfile;
    pfile = fopen("test.txt","w");
    for(i=0;i<8;i++)
        fprintf(pfile,"\t\t$readmemh({prog_path, \"/input.hex\"}, controller_1.u_input_SRAM[%d].input_SRAM_i.Data);\n",i);

    for(i=0;i<32;i++)
        fprintf(pfile,"\t\t$readmemh({prog_path, \"/output.hex\"}, controller_1.u_output_SRAM[%d].output_SRAM_i.Data);\n",i);

    for(i=0;i<32;i++)
        fprintf(pfile,"\t\t$readmemh({prog_path, \"/weight.hex\"}, controller_1.u_weight_SRAM[%d].weight_SRAM_i.Data);\n",i);
    
    return 0;
}