function signed [15:0] fir_coeff;
input [5:0] a;
begin case(a)
0:fir_coeff=0;
1:fir_coeff=-24;
2:fir_coeff=-60;
3:fir_coeff=-116;
4:fir_coeff=-186;
5:fir_coeff=-248;
6:fir_coeff=-267;
7:fir_coeff=-199;
8:fir_coeff=0;
9:fir_coeff=358;
10:fir_coeff=877;
11:fir_coeff=1527;
12:fir_coeff=2247;
13:fir_coeff=2951;
14:fir_coeff=3544;
15:fir_coeff=3940;
16:fir_coeff=4080;
17:fir_coeff=3940;
18:fir_coeff=3544;
19:fir_coeff=2951;
20:fir_coeff=2247;
21:fir_coeff=1527;
22:fir_coeff=877;
23:fir_coeff=358;
24:fir_coeff=0;
25:fir_coeff=-199;
26:fir_coeff=-267;
27:fir_coeff=-248;
28:fir_coeff=-186;
29:fir_coeff=-116;
30:fir_coeff=-60;
31:fir_coeff=-24;
32:fir_coeff=0;
default:fir_coeff=0;
endcase end
endfunction
