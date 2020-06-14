#include <stdio.h>
#include <stdlib.h>

int main(){
	int i,j,k,h;
	FILE *pfile0;
	FILE *pfile1;
	FILE *pfile2;
	FILE *pfile3;
	int t = 2048;

	pfile0 = fopen("test0.hex","w");
	pfile1 = fopen("test1.hex","w");
	pfile2 = fopen("test2.hex","w");
	pfile3 = fopen("test3.hex","w");

	fprintf(pfile0,"@00000000\n");
	for(i=0;i<t;i++){
		for(j=0;j<16;j++){
			for(k=0;k<16;k++){
				fprintf(pfile0,"%X%X ",j,k);
			}
			fprintf(pfile0,"\n");
		}
	}


	fprintf(pfile1,"@00000000\n");
	for(h=0;h<((t/256)+(t%256!=0));h++){
		for(i=0;i<((t>256)?256:t);i++){
			for(j=0;j<16;j++){
				for(k=0;k<16;k++){
					fprintf(pfile1,"%02X ",i);
				}
				fprintf(pfile1,"\n");
			}
		}
	}

	fprintf(pfile2,"@00000000\n");
	for(h=0;h<((t/256)+(t%256!=0));h++){
		for(i=0;i<((t>256)?256:t);i++){
			for(j=0;j<16;j++){
				for(k=0;k<16;k++){
					fprintf(pfile2,"%02X ",h);
				}
				fprintf(pfile2,"\n");
			}
		}
	}

	fprintf(pfile3,"@00000000\n");
	for(i=0;i<t;i++){
		for(j=0;j<16;j++){
			for(k=0;k<16;k++){
				fprintf(pfile3,"00 ");
			}
			fprintf(pfile3,"\n");
		}
	}
	return 0;
}
