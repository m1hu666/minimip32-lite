#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <elf.h>

int main(int argc, char* argv[])
{
	FILE *in;
	FILE *out;

	uint8_t *file_bin_name = malloc(80);
	uint8_t *file_data_name = malloc(80);

	int i,j,k,n;
	unsigned char mem[32];

	strcat(file_bin_name, argv[1]);  
	strcat(file_data_name, argv[2]);

    	in = fopen(file_bin_name, "rb");
    	out = fopen("inst_rom.coe","w");

	fprintf(out, "memory_initialization_radix = 16;\n");
	fprintf(out, "memory_initialization_vector =\n");
	
	int inst_count = 0;
	while(!feof(in)) {
	    if(fread(mem,1,4,in) == 4) {
	        inst_count++;
	        fprintf(out, "%02x%02x%02x%02x,\n", mem[0], mem[1], mem[2], mem[3]);
	    }
        }
	
	// Remove last comma and add semicolon
	if(inst_count > 0) {
	    fseek(out, -2, SEEK_CUR);
	    fprintf(out, ";\n");
	}
	
	fclose(in);
	fclose(out);

    in = fopen(file_data_name, "rb");
    out = fopen("data_ram.coe","w");

	fprintf(out, "memory_initialization_radix = 16;\n");
	fprintf(out, "memory_initialization_vector =\n");
	
	int data_count = 0;
	while(!feof(in)) {
	    n = fread(mem,1,4,in);
            int index;
	    if(n != 4) {
		for(index = 0; index < n; index++)
	        	fprintf(out, "%02x", mem[index]);
		if(n > 0) {
		    data_count++;
		    fprintf(out, ",\n");
		}
		break;
	     }
	    data_count++;
	    fprintf(out, "%02x%02x%02x%02x,\n", mem[0], mem[1], mem[2],mem[3]);
        }
	
	// If no data, write at least one zero word
	if(data_count == 0) {
	    fprintf(out, "00000000;\n");
	} else {
	    // Remove last comma and add semicolon
	    fseek(out, -2, SEEK_CUR);
	    fprintf(out, ";\n");
	}
	
	fclose(in);
	fclose(out);

    return 0;
}
