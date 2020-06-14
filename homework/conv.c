#include <stdio.h>

int main(){
	int	input[9];
	int	filter[9];
	int psum[9];
	int i,result;
	result	=	0;
	int start	=	0;
	scanf("%d",&start);

	input[0]	=	start;
	input[1]	=	start+1;
	input[2]	=	start+2;
	input[3]	=	start+416;
	input[4]	=	start+417;
	input[5]	=	start+418;
	input[6]	=	start+832;
	input[7]	=	start+833;
	input[8]	=	start+834;
	filter[0]	=	9;
	filter[1]	=	26;
	filter[2]	=	14;
	filter[3]	=	33;
	filter[4]	=	-17;
	filter[5]	=	-33;
	filter[6]	=	-2;
	filter[7]	=	-59;
	filter[8]	=	-8;

	printf("PSUM\n");
	for(i=0;i<9;i++)
	{
		psum[i]	=	input[i]*filter[i];
		printf("\tpsum[%d] : %d\n",i,psum[i]);
		result	=	result	+	psum[i];
	}
	start	=	start	-	173056;
	
	while (start >= 0)
	{
		for(i=0;i<9;i++)
		{
			input[i]	=	input[i]	-	173056;
			psum[i]	=	input[i]*filter[i];
			result	=	result	+	psum[i];
		}
		start	=	start	-	173056;
	}
	

	printf("\nANSWER\n");

	printf("\tresult : %d\n\n",result);

	return 0;
}