// Test adapter calling the unmodified HPM transmitter and constellation map.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "psk_tx.h"
#include "psk_codec.h"
static psk_tx_t tx;
int main(int argc,char **argv) {
    if(argc!=4) return 2;
    const psk_mode_info_t *m=NULL;
    for(size_t i=0;i<psk_mode_count();i++)
        if(!strcmp(psk_mode_info_at(i)->name,argv[1])) m=psk_mode_info_at(i);
    if(!m) return 3;
    FILE *f=fopen(argv[2],"w");if(!f)return 4;
    psk_tx_init(&tx,16000);
    if(psk_tx_start_text_loop(&tx,m->id,2000,"HELLO FPGA 123 TEST "))return 5;
    for(int n=0;n<atoi(argv[3]);n++) {
        // Jump to the next symbol boundary; the production encoder, puncturer
        // and interleaver still run normally inside psk_tx_generate().
        tx.symbol_position=tx.symbol_period_samples;
        float old=tx.data_phase[0];int16_t sample;
        if(psk_tx_generate(&tx,&sample,1)!=1)return 6;
        float delta=tx.data_phase[0]-old;
        if(delta<0)delta+=6.283185307179586f;
        unsigned index=(unsigned)lroundf(delta/(m->family==PSK_MODE_FAMILY_8PSK ?
              0.7853981633974483f:1.5707963267948966f));
        unsigned sym=m->family==PSK_MODE_FAMILY_BPSK ? (index==0):
            psk_codec_symbol_from_phase_index(m->family,m->fec,index);
        fprintf(f,"%x\n",sym);
    }
    fclose(f);return 0;
}
