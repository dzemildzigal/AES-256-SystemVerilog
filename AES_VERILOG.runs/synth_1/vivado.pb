
�
I%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s
268*common2
create_project: 2

00:00:082

00:00:082	
629.1252	
199.703Z17-268h px� 
�
Command: %s
1870*	planAhead2�
�read_checkpoint -auto_incremental -incremental C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/utils_1/imports/synth_1/Top.dcpZ12-2866h px� 
�
;Read reference checkpoint from %s for incremental synthesis3154*	planAhead2_
]C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/utils_1/imports/synth_1/Top.dcpZ12-5825h px� 
T
-Please ensure there are no constraint changes3725*	planAheadZ12-7989h px� 
k
Command: %s
53*	vivadotcl2:
8synth_design -top EncryptPipelined -part xc7z020clg400-1Z4-113h px� 
:
Starting synth_design
149*	vivadotclZ4-321h px� 
z
@Attempting to get a license for feature '%s' and/or device '%s'
308*common2
	Synthesis2	
xc7z020Z17-347h px� 
j
0Got license for feature '%s' and/or device '%s'
310*common2
	Synthesis2	
xc7z020Z17-349h px� 

VNo compile time benefit to using incremental synthesis; A full resynthesis will be run2353*designutilsZ20-5440h px� 
�
�Flow is switching to default flow due to incremental criteria not met. If you would like to alter this behaviour and have the flow terminate instead, please set the following parameter config_implementation {autoIncr.Synth.RejectBehavior Terminate}2229*designutilsZ20-4379h px� 
o
HMultithreading enabled for synth_design using a maximum of %s processes.4828*oasys2
2Z8-7079h px� 
a
?Launching helper process for spawning children vivado processes4827*oasysZ8-7078h px� 
N
#Helper process launched with PID %s4824*oasys2
14584Z8-7075h px� 
�
%s*synth2v
tStarting Synthesize : Time (s): cpu = 00:00:07 ; elapsed = 00:00:07 . Memory (MB): peak = 1091.266 ; gain = 449.340
h px� 
�
synthesizing module '%s'%s4497*oasys2
EncryptPipelined2
 2c
_C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptPipelined.sv2
238@Z8-6157h px� 
�
synthesizing module '%s'%s4497*oasys2
EncryptionInitialRound2
 2i
eC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionInitialRound.sv2
238@Z8-6157h px� 
�
synthesizing module '%s'%s4497*oasys2
AddRoundKey2
 2^
ZC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/AddRoundKey.sv2
238@Z8-6157h px� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2
AddRoundKey2
 2
02
12^
ZC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/AddRoundKey.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2

SubBytes2
 2[
WC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/SubBytes.sv2
238@Z8-6157h px� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2

SubBytes2
 2
02
12[
WC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/SubBytes.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2
	ShiftRows2
 2\
XC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/ShiftRows.sv2
238@Z8-6157h px� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2
	ShiftRows2
 2
02
12\
XC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/ShiftRows.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2

MixColumns2
 2]
YC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/MixColumns.sv2
238@Z8-6157h px� 
�
synthesizing module '%s'%s4497*oasys2
	MixColumn2
 2\
XC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/MixColumn.sv2
238@Z8-6157h px� 
�
synthesizing module '%s'%s4497*oasys2
XTime2
 2X
TC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/XTime.sv2
238@Z8-6157h px� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2
XTime2
 2
02
12X
TC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/XTime.sv2
238@Z8-6155h px� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2
	MixColumn2
 2
02
12\
XC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/MixColumn.sv2
238@Z8-6155h px� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2

MixColumns2
 2
02
12]
YC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/MixColumns.sv2
238@Z8-6155h px� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2
EncryptionInitialRound2
 2
02
12i
eC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionInitialRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2
EncryptionRound2
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
D
%s
*synth2,
*	Parameter i bound to: 2 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2
EncryptionRound2
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2!
EncryptionRound__parameterized02
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
D
%s
*synth2,
*	Parameter i bound to: 3 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2!
EncryptionRound__parameterized02
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2!
EncryptionRound__parameterized12
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
D
%s
*synth2,
*	Parameter i bound to: 4 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2!
EncryptionRound__parameterized12
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2!
EncryptionRound__parameterized22
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
D
%s
*synth2,
*	Parameter i bound to: 5 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2!
EncryptionRound__parameterized22
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2!
EncryptionRound__parameterized32
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
D
%s
*synth2,
*	Parameter i bound to: 6 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2!
EncryptionRound__parameterized32
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2!
EncryptionRound__parameterized42
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
D
%s
*synth2,
*	Parameter i bound to: 7 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2!
EncryptionRound__parameterized42
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2!
EncryptionRound__parameterized52
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
D
%s
*synth2,
*	Parameter i bound to: 8 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2!
EncryptionRound__parameterized52
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2!
EncryptionRound__parameterized62
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
D
%s
*synth2,
*	Parameter i bound to: 9 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2!
EncryptionRound__parameterized62
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2!
EncryptionRound__parameterized72
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
E
%s
*synth2-
+	Parameter i bound to: 10 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2!
EncryptionRound__parameterized72
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2!
EncryptionRound__parameterized82
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
E
%s
*synth2-
+	Parameter i bound to: 11 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2!
EncryptionRound__parameterized82
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2!
EncryptionRound__parameterized92
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
E
%s
*synth2-
+	Parameter i bound to: 12 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2!
EncryptionRound__parameterized92
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2"
 EncryptionRound__parameterized102
 2b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6157h px� 
E
%s
*synth2-
+	Parameter i bound to: 13 - type: integer 
h p
x
� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2"
 EncryptionRound__parameterized102
 2
02
12b
^C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionRound.sv2
238@Z8-6155h px� 
�
synthesizing module '%s'%s4497*oasys2
EncryptionFinalRound2
 2g
cC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionFinalRound.sv2
238@Z8-6157h px� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2
EncryptionFinalRound2
 2
02
12g
cC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptionFinalRound.sv2
238@Z8-6155h px� 
�
Nreplacing case/wildcard equality operator %s with logical equality operator %s589*oasys2
===2
==2c
_C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptPipelined.sv2
1408@Z8-589h px� 
�
'done synthesizing module '%s'%s (%s#%s)4495*oasys2
EncryptPipelined2
 2
02
12c
_C:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.srcs/sources_1/new/EncryptPipelined.sv2
238@Z8-6155h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[0]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[1]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[2]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[3]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[4]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[5]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[6]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[7]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[8]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[9]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[10]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[11]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[12]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[13]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[14]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[15]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[16]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[17]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[18]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[19]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[20]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[21]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[22]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[23]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[24]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[25]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[26]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[27]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[28]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[29]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[30]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[31]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[32]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[33]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[34]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[35]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[36]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[37]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[38]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[39]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[40]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[41]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[42]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[43]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[44]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[45]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[46]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[47]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[48]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[49]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[50]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[51]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[52]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[53]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[54]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[55]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[56]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[57]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[58]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[59]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[60]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[61]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[62]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[63]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[64]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[65]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[66]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[67]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[68]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[69]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[70]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[71]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[72]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[73]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[74]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[75]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[76]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[77]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[78]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[79]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[80]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[81]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[82]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[83]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[84]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[85]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[86]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[87]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[88]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[89]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[90]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[91]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[92]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[93]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[94]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[95]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[96]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[97]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[98]2
EncryptionFinalRoundZ8-7129h px� 
�
9Port %s in module %s is either unconnected or has no load4866*oasys2
expanded_key[99]2
EncryptionFinalRoundZ8-7129h px� 
�
�Message '%s' appears more than %s times and has been disabled. User can change this message limit to see more message instances.
14*common2
Synth 8-71292
100Z17-14h px� 
�
%s*synth2v
tFinished Synthesize : Time (s): cpu = 00:00:11 ; elapsed = 00:00:11 . Memory (MB): peak = 1218.242 ; gain = 576.316
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2�
Finished Constraint Validation : Time (s): cpu = 00:00:11 ; elapsed = 00:00:11 . Memory (MB): peak = 1218.242 ; gain = 576.316
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
D
%s
*synth2,
*Start Loading Part and Timing Information
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
8
%s
*synth2 
Loading part: xc7z020clg400-1
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2�
�Finished Loading Part and Timing Information : Time (s): cpu = 00:00:11 ; elapsed = 00:00:11 . Memory (MB): peak = 1218.242 ; gain = 576.316
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
D
Loading part %s157*device2
xc7z020clg400-1Z21-403h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2�
�Finished RTL Optimization Phase 2 : Time (s): cpu = 00:00:14 ; elapsed = 00:00:12 . Memory (MB): peak = 1228.754 ; gain = 586.828
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
Z
$Part: %s does not have CEAM library.966*device2
xc7z020clg400-1Z21-9227h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
:
%s
*synth2"
 Start RTL Component Statistics 
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
9
%s
*synth2!
Detailed RTL Component Info : 
h p
x
� 
(
%s
*synth2
+---Adders : 
h p
x
� 
F
%s
*synth2.
,	   2 Input   32 Bit       Adders := 1     
h p
x
� 
&
%s
*synth2
+---XORs : 
h p
x
� 
H
%s
*synth20
.	   2 Input    128 Bit         XORs := 15    
h p
x
� 
H
%s
*synth20
.	   2 Input      8 Bit         XORs := 260   
h p
x
� 
H
%s
*synth20
.	   3 Input      8 Bit         XORs := 208   
h p
x
� 
+
%s
*synth2
+---Registers : 
h p
x
� 
H
%s
*synth20
.	              128 Bit    Registers := 28    
h p
x
� 
H
%s
*synth20
.	               32 Bit    Registers := 1     
h p
x
� 
H
%s
*synth20
.	                1 Bit    Registers := 1     
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
=
%s
*synth2%
#Finished RTL Component Statistics 
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
6
%s
*synth2
Start Part Resource Summary
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
q
%s
*synth2Y
WPart Resources:
DSPs: 220 (col length:60)
BRAMs: 280 (col length: RAMB18 60 RAMB36 30)
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
9
%s
*synth2!
Finished Part Resource Summary
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
E
%s
*synth2-
+Start Cross Boundary and Area Optimization
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
H
&Parallel synthesis criteria is not met4829*oasysZ8-7080h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2�
�Finished Cross Boundary and Area Optimization : Time (s): cpu = 00:00:39 ; elapsed = 00:00:41 . Memory (MB): peak = 1508.465 ; gain = 866.539
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2�
�---------------------------------------------------------------------------------
Start ROM, RAM, DSP, Shift Register and Retiming Reporting
h px� 
l
%s*synth2T
R---------------------------------------------------------------------------------
h px� 
;
%s*synth2#
!
ROM: Preliminary Mapping Report
h px� 
}
%s*synth2e
c+-----------------+---------------------------------------------+---------------+----------------+
h px� 
~
%s*synth2f
d|Module Name      | RTL Object                                  | Depth x Width | Implemented As | 
h px� 
}
%s*synth2e
c+-----------------+---------------------------------------------+---------------+----------------+
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|XTime            | x_time                                      | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|SubBytes         | sbox                                        | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_zeroth/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_first/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/zeroth/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/first/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/second/x_time | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_second/third/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/zeroth/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/first/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/second/x_time  | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d|EncryptPipelined | mix_columns_middle/mix_third/third/x_time   | 256x8         | LUT            | 
h px� 
~
%s*synth2f
d+-----------------+---------------------------------------------+---------------+----------------+

h px� 
�
%s*synth2�
�---------------------------------------------------------------------------------
Finished ROM, RAM, DSP, Shift Register and Retiming Reporting
h px� 
l
%s*synth2T
R---------------------------------------------------------------------------------
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
4
%s
*synth2
Start Timing Optimization
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2
}Finished Timing Optimization : Time (s): cpu = 00:00:39 ; elapsed = 00:00:42 . Memory (MB): peak = 1508.465 ; gain = 866.539
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
3
%s
*synth2
Start Technology Mapping
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2~
|Finished Technology Mapping : Time (s): cpu = 00:00:41 ; elapsed = 00:00:43 . Memory (MB): peak = 1508.465 ; gain = 866.539
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
-
%s
*synth2
Start IO Insertion
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
?
%s
*synth2'
%Start Flattening Before IO Insertion
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
B
%s
*synth2*
(Finished Flattening Before IO Insertion
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
6
%s
*synth2
Start Final Netlist Cleanup
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
9
%s
*synth2!
Finished Final Netlist Cleanup
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2x
vFinished IO Insertion : Time (s): cpu = 00:00:46 ; elapsed = 00:00:49 . Memory (MB): peak = 1508.465 ; gain = 866.539
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
=
%s
*synth2%
#Start Renaming Generated Instances
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2�
�Finished Renaming Generated Instances : Time (s): cpu = 00:00:47 ; elapsed = 00:00:49 . Memory (MB): peak = 1508.465 ; gain = 866.539
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
:
%s
*synth2"
 Start Rebuilding User Hierarchy
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2�
�Finished Rebuilding User Hierarchy : Time (s): cpu = 00:00:47 ; elapsed = 00:00:50 . Memory (MB): peak = 1508.465 ; gain = 866.539
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
9
%s
*synth2!
Start Renaming Generated Ports
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2�
�Finished Renaming Generated Ports : Time (s): cpu = 00:00:48 ; elapsed = 00:00:50 . Memory (MB): peak = 1508.465 ; gain = 866.539
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
;
%s
*synth2#
!Start Handling Custom Attributes
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2�
�Finished Handling Custom Attributes : Time (s): cpu = 00:00:48 ; elapsed = 00:00:50 . Memory (MB): peak = 1508.465 ; gain = 866.539
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
8
%s
*synth2 
Start Renaming Generated Nets
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2�
�Finished Renaming Generated Nets : Time (s): cpu = 00:00:48 ; elapsed = 00:00:50 . Memory (MB): peak = 1508.465 ; gain = 866.539
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
9
%s
*synth2!
Start Writing Synthesis Report
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
/
%s
*synth2

Report BlackBoxes: 
h p
x
� 
8
%s
*synth2 
+-+--------------+----------+
h p
x
� 
8
%s
*synth2 
| |BlackBox name |Instances |
h p
x
� 
8
%s
*synth2 
+-+--------------+----------+
h p
x
� 
8
%s
*synth2 
+-+--------------+----------+
h p
x
� 
/
%s*synth2

Report Cell Usage: 
h px� 
2
%s*synth2
+------+-------+------+
h px� 
2
%s*synth2
|      |Cell   |Count |
h px� 
2
%s*synth2
+------+-------+------+
h px� 
2
%s*synth2
|1     |BUFG   |     1|
h px� 
2
%s*synth2
|2     |CARRY4 |     8|
h px� 
2
%s*synth2
|3     |LUT1   |     1|
h px� 
2
%s*synth2
|4     |LUT2   |   880|
h px� 
2
%s*synth2
|5     |LUT4   |   162|
h px� 
2
%s*synth2
|6     |LUT5   |     4|
h px� 
2
%s*synth2
|7     |LUT6   |  8833|
h px� 
2
%s*synth2
|8     |MUXF7  |  3584|
h px� 
2
%s*synth2
|9     |MUXF8  |  1792|
h px� 
2
%s*synth2
|10    |FDRE   |  3617|
h px� 
2
%s*synth2
|11    |IBUF   |  2050|
h px� 
2
%s*synth2
|12    |OBUF   |  1793|
h px� 
2
%s*synth2
+------+-------+------+
h px� 
3
%s
*synth2

Report Instance Areas: 
h p
x
� 
d
%s
*synth2L
J+------+-----------------------+---------------------------------+------+
h p
x
� 
d
%s
*synth2L
J|      |Instance               |Module                           |Cells |
h p
x
� 
d
%s
*synth2L
J+------+-----------------------+---------------------------------+------+
h p
x
� 
d
%s
*synth2L
J|1     |top                    |                                 | 22725|
h p
x
� 
d
%s
*synth2L
J|2     |  round1               |EncryptionInitialRound           |  1944|
h p
x
� 
d
%s
*synth2L
J|3     |    mix_columns_middle |MixColumns_65                    |   120|
h p
x
� 
d
%s
*synth2L
J|4     |      mix_first        |MixColumn_67                     |    30|
h p
x
� 
d
%s
*synth2L
J|5     |      mix_second       |MixColumn_68                     |    30|
h p
x
� 
d
%s
*synth2L
J|6     |      mix_third        |MixColumn_69                     |    30|
h p
x
� 
d
%s
*synth2L
J|7     |      mix_zeroth       |MixColumn_70                     |    30|
h p
x
� 
d
%s
*synth2L
J|8     |    sub_bytes_middle   |SubBytes_66                      |   968|
h p
x
� 
d
%s
*synth2L
J|9     |  round10              |EncryptionRound__parameterized7  |  1212|
h p
x
� 
d
%s
*synth2L
J|10    |    mix_columns_middle |MixColumns_59                    |    60|
h p
x
� 
d
%s
*synth2L
J|11    |      mix_first        |MixColumn_61                     |    15|
h p
x
� 
d
%s
*synth2L
J|12    |      mix_second       |MixColumn_62                     |    15|
h p
x
� 
d
%s
*synth2L
J|13    |      mix_third        |MixColumn_63                     |    15|
h p
x
� 
d
%s
*synth2L
J|14    |      mix_zeroth       |MixColumn_64                     |    15|
h p
x
� 
d
%s
*synth2L
J|15    |    sub_bytes_middle   |SubBytes_60                      |   480|
h p
x
� 
d
%s
*synth2L
J|16    |  round11              |EncryptionRound__parameterized8  |  1212|
h p
x
� 
d
%s
*synth2L
J|17    |    mix_columns_middle |MixColumns_53                    |    60|
h p
x
� 
d
%s
*synth2L
J|18    |      mix_first        |MixColumn_55                     |    15|
h p
x
� 
d
%s
*synth2L
J|19    |      mix_second       |MixColumn_56                     |    15|
h p
x
� 
d
%s
*synth2L
J|20    |      mix_third        |MixColumn_57                     |    15|
h p
x
� 
d
%s
*synth2L
J|21    |      mix_zeroth       |MixColumn_58                     |    15|
h p
x
� 
d
%s
*synth2L
J|22    |    sub_bytes_middle   |SubBytes_54                      |   480|
h p
x
� 
d
%s
*synth2L
J|23    |  round12              |EncryptionRound__parameterized9  |  1212|
h p
x
� 
d
%s
*synth2L
J|24    |    mix_columns_middle |MixColumns_47                    |    60|
h p
x
� 
d
%s
*synth2L
J|25    |      mix_first        |MixColumn_49                     |    15|
h p
x
� 
d
%s
*synth2L
J|26    |      mix_second       |MixColumn_50                     |    15|
h p
x
� 
d
%s
*synth2L
J|27    |      mix_third        |MixColumn_51                     |    15|
h p
x
� 
d
%s
*synth2L
J|28    |      mix_zeroth       |MixColumn_52                     |    15|
h p
x
� 
d
%s
*synth2L
J|29    |    sub_bytes_middle   |SubBytes_48                      |   480|
h p
x
� 
d
%s
*synth2L
J|30    |  round13              |EncryptionRound__parameterized10 |  1152|
h p
x
� 
d
%s
*synth2L
J|31    |    sub_bytes_middle   |SubBytes_46                      |   480|
h p
x
� 
d
%s
*synth2L
J|32    |  round14              |EncryptionFinalRound             |   608|
h p
x
� 
d
%s
*synth2L
J|33    |    sub_bytes_middle   |SubBytes_45                      |   480|
h p
x
� 
d
%s
*synth2L
J|34    |  round2               |EncryptionRound                  |  1212|
h p
x
� 
d
%s
*synth2L
J|35    |    mix_columns_middle |MixColumns_39                    |    60|
h p
x
� 
d
%s
*synth2L
J|36    |      mix_first        |MixColumn_41                     |    15|
h p
x
� 
d
%s
*synth2L
J|37    |      mix_second       |MixColumn_42                     |    15|
h p
x
� 
d
%s
*synth2L
J|38    |      mix_third        |MixColumn_43                     |    15|
h p
x
� 
d
%s
*synth2L
J|39    |      mix_zeroth       |MixColumn_44                     |    15|
h p
x
� 
d
%s
*synth2L
J|40    |    sub_bytes_middle   |SubBytes_40                      |   480|
h p
x
� 
d
%s
*synth2L
J|41    |  round3               |EncryptionRound__parameterized0  |  1212|
h p
x
� 
d
%s
*synth2L
J|42    |    mix_columns_middle |MixColumns_33                    |    60|
h p
x
� 
d
%s
*synth2L
J|43    |      mix_first        |MixColumn_35                     |    15|
h p
x
� 
d
%s
*synth2L
J|44    |      mix_second       |MixColumn_36                     |    15|
h p
x
� 
d
%s
*synth2L
J|45    |      mix_third        |MixColumn_37                     |    15|
h p
x
� 
d
%s
*synth2L
J|46    |      mix_zeroth       |MixColumn_38                     |    15|
h p
x
� 
d
%s
*synth2L
J|47    |    sub_bytes_middle   |SubBytes_34                      |   480|
h p
x
� 
d
%s
*synth2L
J|48    |  round4               |EncryptionRound__parameterized1  |  1212|
h p
x
� 
d
%s
*synth2L
J|49    |    mix_columns_middle |MixColumns_27                    |    60|
h p
x
� 
d
%s
*synth2L
J|50    |      mix_first        |MixColumn_29                     |    15|
h p
x
� 
d
%s
*synth2L
J|51    |      mix_second       |MixColumn_30                     |    15|
h p
x
� 
d
%s
*synth2L
J|52    |      mix_third        |MixColumn_31                     |    15|
h p
x
� 
d
%s
*synth2L
J|53    |      mix_zeroth       |MixColumn_32                     |    15|
h p
x
� 
d
%s
*synth2L
J|54    |    sub_bytes_middle   |SubBytes_28                      |   480|
h p
x
� 
d
%s
*synth2L
J|55    |  round5               |EncryptionRound__parameterized2  |  1212|
h p
x
� 
d
%s
*synth2L
J|56    |    mix_columns_middle |MixColumns_21                    |    60|
h p
x
� 
d
%s
*synth2L
J|57    |      mix_first        |MixColumn_23                     |    15|
h p
x
� 
d
%s
*synth2L
J|58    |      mix_second       |MixColumn_24                     |    15|
h p
x
� 
d
%s
*synth2L
J|59    |      mix_third        |MixColumn_25                     |    15|
h p
x
� 
d
%s
*synth2L
J|60    |      mix_zeroth       |MixColumn_26                     |    15|
h p
x
� 
d
%s
*synth2L
J|61    |    sub_bytes_middle   |SubBytes_22                      |   480|
h p
x
� 
d
%s
*synth2L
J|62    |  round6               |EncryptionRound__parameterized3  |  1212|
h p
x
� 
d
%s
*synth2L
J|63    |    mix_columns_middle |MixColumns_15                    |    60|
h p
x
� 
d
%s
*synth2L
J|64    |      mix_first        |MixColumn_17                     |    15|
h p
x
� 
d
%s
*synth2L
J|65    |      mix_second       |MixColumn_18                     |    15|
h p
x
� 
d
%s
*synth2L
J|66    |      mix_third        |MixColumn_19                     |    15|
h p
x
� 
d
%s
*synth2L
J|67    |      mix_zeroth       |MixColumn_20                     |    15|
h p
x
� 
d
%s
*synth2L
J|68    |    sub_bytes_middle   |SubBytes_16                      |   480|
h p
x
� 
d
%s
*synth2L
J|69    |  round7               |EncryptionRound__parameterized4  |  1212|
h p
x
� 
d
%s
*synth2L
J|70    |    mix_columns_middle |MixColumns_9                     |    60|
h p
x
� 
d
%s
*synth2L
J|71    |      mix_first        |MixColumn_11                     |    15|
h p
x
� 
d
%s
*synth2L
J|72    |      mix_second       |MixColumn_12                     |    15|
h p
x
� 
d
%s
*synth2L
J|73    |      mix_third        |MixColumn_13                     |    15|
h p
x
� 
d
%s
*synth2L
J|74    |      mix_zeroth       |MixColumn_14                     |    15|
h p
x
� 
d
%s
*synth2L
J|75    |    sub_bytes_middle   |SubBytes_10                      |   480|
h p
x
� 
d
%s
*synth2L
J|76    |  round8               |EncryptionRound__parameterized5  |  1212|
h p
x
� 
d
%s
*synth2L
J|77    |    mix_columns_middle |MixColumns_3                     |    60|
h p
x
� 
d
%s
*synth2L
J|78    |      mix_first        |MixColumn_5                      |    15|
h p
x
� 
d
%s
*synth2L
J|79    |      mix_second       |MixColumn_6                      |    15|
h p
x
� 
d
%s
*synth2L
J|80    |      mix_third        |MixColumn_7                      |    15|
h p
x
� 
d
%s
*synth2L
J|81    |      mix_zeroth       |MixColumn_8                      |    15|
h p
x
� 
d
%s
*synth2L
J|82    |    sub_bytes_middle   |SubBytes_4                       |   480|
h p
x
� 
d
%s
*synth2L
J|83    |  round9               |EncryptionRound__parameterized6  |  1212|
h p
x
� 
d
%s
*synth2L
J|84    |    mix_columns_middle |MixColumns                       |    60|
h p
x
� 
d
%s
*synth2L
J|85    |      mix_first        |MixColumn                        |    15|
h p
x
� 
d
%s
*synth2L
J|86    |      mix_second       |MixColumn_0                      |    15|
h p
x
� 
d
%s
*synth2L
J|87    |      mix_third        |MixColumn_1                      |    15|
h p
x
� 
d
%s
*synth2L
J|88    |      mix_zeroth       |MixColumn_2                      |    15|
h p
x
� 
d
%s
*synth2L
J|89    |    sub_bytes_middle   |SubBytes                         |   480|
h p
x
� 
d
%s
*synth2L
J+------+-----------------------+---------------------------------+------+
h p
x
� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
�
%s*synth2�
�Finished Writing Synthesis Report : Time (s): cpu = 00:00:48 ; elapsed = 00:00:50 . Memory (MB): peak = 1508.465 ; gain = 866.539
h px� 
l
%s
*synth2T
R---------------------------------------------------------------------------------
h p
x
� 
d
%s
*synth2L
JSynthesis finished with 0 errors, 0 critical warnings and 24962 warnings.
h p
x
� 
�
%s
*synth2�
Synthesis Optimization Runtime : Time (s): cpu = 00:00:48 ; elapsed = 00:00:50 . Memory (MB): peak = 1508.465 ; gain = 866.539
h p
x
� 
�
%s
*synth2�
�Synthesis Optimization Complete : Time (s): cpu = 00:00:48 ; elapsed = 00:00:50 . Memory (MB): peak = 1508.465 ; gain = 866.539
h p
x
� 
B
 Translating synthesized netlist
350*projectZ1-571h px� 
�
I%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s
268*common2
Netlist sorting complete. 2

00:00:002
00:00:00.3752

1518.9842
0.000Z17-268h px� 
V
-Analyzing %s Unisim elements for replacement
17*netlist2
5384Z29-17h px� 
X
2Unisim Transformation completed in %s CPU seconds
28*netlist2
1Z29-28h px� 
K
)Preparing netlist for logic optimization
349*projectZ1-570h px� 
Q
)Pushed %s inverter(s) to %s load pin(s).
98*opt2
02
0Z31-138h px� 
�
I%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s
268*common2
Netlist sorting complete. 2

00:00:002
00:00:00.0042

1609.5622
0.000Z17-268h px� 
l
!Unisim Transformation Summary:
%s111*project2'
%No Unisim elements were transformed.
Z1-111h px� 
V
%Synth Design complete | Checksum: %s
562*	vivadotcl2

9b9abea1Z4-1430h px� 
C
Releasing license: %s
83*common2
	SynthesisZ17-83h px� 
�
G%s Infos, %s Warnings, %s Critical Warnings and %s Errors encountered.
28*	vivadotcl2
602
1022
02
0Z4-41h px� 
L
%s completed successfully
29*	vivadotcl2
synth_designZ4-42h px� 
�
I%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s
268*common2
synth_design: 2

00:00:552

00:00:572

1609.5622	
973.949Z17-268h px� 
�
I%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s
268*common2
Write ShapeDB Complete: 2

00:00:002
00:00:00.1092

1609.5622
0.000Z17-268h px� 
�
 The %s '%s' has been generated.
621*common2

checkpoint2\
ZC:/Users/dzemi/Desktop/AES-256-SystemVerilog/AES_VERILOG.runs/synth_1/EncryptPipelined.dcpZ17-1381h px� 
�
Executing command : %s
56330*	planAhead2k
ireport_utilization -file EncryptPipelined_utilization_synth.rpt -pb EncryptPipelined_utilization_synth.pbZ12-24828h px� 
\
Exiting %s at %s...
206*common2
Vivado2
Mon Oct 28 21:47:03 2024Z17-206h px� 


End Record