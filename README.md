# Caravel User Project

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) [![UPRJ_CI](https://github.com/efabless/caravel_project_example/actions/workflows/user_project_ci.yml/badge.svg)](https://github.com/efabless/caravel_project_example/actions/workflows/user_project_ci.yml) [![Caravel Build](https://github.com/efabless/caravel_project_example/actions/workflows/caravel_build.yml/badge.svg)](https://github.com/efabless/caravel_project_example/actions/workflows/caravel_build.yml)

| :exclamation: Important Note            |
|-----------------------------------------|

## Please fill in your project documentation in this README.md file 


Refer to [README](docs/source/index.rst) for this sample project documentation. 

## Wishbone CAN

This project is a wishbone bus compatible CAN (Controller Area Network) controller, which can be used to communicate with other nodes on a CAN bus like those frequently found in cars and other light industrial applications. This implementation should (hopefully!) cover the entire CAN 2.0B standard outlined in [this](http://esd.cs.ucr.edu/webres/can20.pdf) document. As a summary, this controller supports standard, extended ID, and RTR packets for both RX and TX. It should also recognize overload and error packets in RX and will transmit error packets when necessary. Taking inspiration from the CAN controller implemented in many STM32 MCUs, this controller also allows the user to configure up to 20 maskable filters for the receiver. An 8 section long FIFO is placed on the receive side to capture filtered packets, and three transmit mailboxes are available which can either transmit in numerical order, or by highest priority CAN ID.

## Register Map

### Master control register  (MCR) 0x0000

Bits 31-6: reserved  
  
Bit 5: overrun enable (r/w)  
Enable overrun on the RX FIFO  
  
Bit 4: auto retrans (r/w)  
Auto retransmission on TX in case of an arbitration loss. May be useful to keep 0 if packets are time sensitive.  
  
Bit 3: tx priority (r/w)  
Priority for TX mailboxes. Set to 1 for priority based on Mailbox number (1 -> 2 -> 3). Set to 0 for ID based priority (lowest ID wins like in normal arbitration).  
  
Bit 2: sleep (r/w)  
Put into sleep mode. No RX or TX.  
  
Bit 1: reset (r/w)  
Reset the CAN controller without needing to reset the whole chip  
  
Bit 0: start (r/w)  
Start the CAN controller from sleep mode. Set to 1 once the rest of the controller has been configured

### Master status register (MSR) 0x0004

Bits 31-5: reserved  
  
Bit 4: tx busy (r)  
Transmitter is transmitting something and has won arbitration  
  
Bit 3: rx busy (r)  
Receiver is busy receiver.  
  
Bit 2: curr sample (r)  
Current sample from the receiver  
  
Bits 1-0: mode (r)  
CAN controller mode. 0 = sleep, 1 = initialization, 2 = running

### FIFO status and control register (FSCR) 0x0008

Bit 31-9: reserved  
  
Bit 8: empty (r)  
FIFO is empty  
  
Bit 7: full (r)  
FIFO is full  
  
Bit 6-3: occupancy (r)  
FIFO occupancy  
  
Bit 2: overrun (r)
FIFO has overrun  
  
Bit 1: read fifo (r/w)  
Set to 1 after other FIFO registers have been read in order to move on to the next packet in the FIFO  
  
Bit 0: clear (r/w)
Clear the contents of the FIFO

### FIFO packet info register (FIR) 0x000c

Bits 31-11 reserved  
  
Bits 10-6: fmi (r)
Filter match index. The index of the filter for which this particular packet was passed on to the RX FIFO  
  
Bit 5: EXT (r)  
The packet is an extended ID packet  
  
Bit 4: RTR (r)  
The packet is a remote transmission request  
  
Bits 3-0: size (r)  
Size of the received packet

### FIFO ID register (FIDR) 0x0010

Bits 31-29: reserved  
  
Bits 28-0: ID (r)  
Bits 28-18: Normal ID, bits 17-0: extended ID if applicable  

### FIFO data low register (FDLR) 0x0014
  
read only  
  
Bits 31-24: Byte 3 of packet in FIFO  
Bits 23-16: Byte 2 of packet in FIFO  
Bits 15-8: Byte 1 of packet in FIFO  
Bits 7-0: Byte 0 of packet in FIFO

### FIFO data high register (FDHR) 0x0018
  
read only  
  
Bits 31-24: Byte 7 of packet in FIFO  
Bits 23-16: Byte 6 of packet in FIFO  
Bits 15-8: Byte 5 of packet in FIFO  
Bits 7-0: Byte 4 of packet in FIFO

### Filter mask enable register (FMER) 0x001c

Bits 31-20: reserved  
  
Bits 19-0: filter enables (r/w)  
Each bit enables the particular filter number for entry to the RX FIFO.  

### Filter registers (FRx) 0x0020 - 0x006c

Bit 31: reserved  
  
Bit 30: RTR (r/w)  
Preferred RTR bit for the filter  
  
Bit 29: EXT (r/w)  
Preferred EXT bit for the filter  
  
Bits 28-0: ID (r/w)  
Perferred ID for the filter. Refer to [FIDR](#fifo-id-register-(fidr)-0x0010) for bit organization

### Filter mask registers (FMRx) 0x0070 - 0x00bc

Bit 31: reserved  
  
Bits 30-0: mask (r/w)  
mask for corresponding filter (mask off bits you want to contribute to the filter). For example only mask off bits 28-18 of the ID, or just mask RTR packets by setting bit 30.  

### Error status register (ESR) 0x00c0

Bits 31-21: reserved  
  
Bits 20-18: LEC (r)  
Last error code  
  
Bit 17: bus off (r)  
Controller is in bus off mode  
  
Bit 16: error passive (r)  
Controller is error passive  
  
Bits 15-8: TEC (r)  
Transmitter error count  
  
Bits 7-0: REC (r)  
Receiver error count

### Timing register (TMGR) 0x00c4

Bits 31-16: reserved  
  
Bits 15-13: TS2 (r/w)  
Time segment 2. Length of the second time segment of a bit period in time quanta. Length = TS2 + 1.  
  
Bits 12-10: TS1 (r/w)  
Time segment 1. Length of the first time segment of a bit period in time quanta. Length = TS1 + 1.  
  
Bits 9-0: BRP (r/w)  
Baud rate prescaler. Prescaler from wishbone clock to time quanta. tq = BRP + 1  
Bit period = tq x (2 + (TS1 + 1) + (TS2 + 1))

### TX mailbox #x ID register (MLSxR) 0x00c8 - 0x00d0

Bit 31: data_ready (r/w)  
Set when data in mailbox is ready to be transmitted  
  
Bit 30: EXT (r/w)  
Signal the packet in mailbox has an extended ID  
  
Bit 29: RTR (r/w)  
Signal the packet in mailbox is a remote transmission request    
  
Bits 28-0: ID (r/w)  
ID to be transmitted. Refer to [FIDR](#fifo-id-register-(fidr)-0x0010) for bit organization

### TX mailbox #x packet size register (MLSxR) 0x00d4 - 0x00dc

Bits 31-4 reserved  
  
Bits 3-0: DLC (r/w)  
Data length code. Size in bytes of the packet to be transmitted. Maximum of 8.

### TX mailbox data low registers (MLDLxR) 0x00e0 - 0x00e8

read / write  
  
Bits 31-24: Byte 3 of packet to be transmitted  
Bits 23-16: Byte 2 of packet to be transmitted  
Bits 15-8: Byte 1 of packet to be transmitted  
Bits 7-0: Byte 0 of packet to be transmitted

### TX mailbox data high registers (MLDHxR) 0x00ec - 0x00f4

read / write  
  
Bits 31-24: Byte 7 of packet to be transmitted  
Bits 23-16: Byte 6 of packet to be transmitted  
Bits 15-8: Byte 5 of packet to be transmitted  
Bits 7-0: Byte 4 of packet to be transmitted

## Included Testbench
This peripheral was designed in SystemVerilog and as such was not easily simulated with FOSS/freeware. I ended up choosing Vivado Webpack for simulation. Therefore, an extra makefile as well as tcl script for running vivado have been added. They are mostly intended to be used in my personal design flow for Lattice iCE-40 FPGAs hence the extra portions or the tcl file. Running make tbsim_source on a machine with Vivado installed should allow the testbench to be run. You may also notice that some verilog versions of files are also included. These are neccessary as yosys cannot deal with all facets of SystemVerilog. The tool sv2v was used to accomplish this.