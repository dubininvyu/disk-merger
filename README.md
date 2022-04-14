# disk-merger
A 16-bits x86 DOS Assembly console utility for merging two contiguous logical disks in an extended partition. 

# Theoretical basis
The first sector of physical hard drive, called the Master Boot Record (MBR) sector, contains the system Partition Table structure, which contains information about the created partitions.

The Master Boot is placed in the beginning of the sector, followed by the Partition Table. The structure of the MBR sector is shown below (in the table).

| Master Boot | Partition Table | Boot signature |
|:----------------:|:---------:|:----------------:|
| 446 bytes | 64 bytes | 2 bytes |

Thus, the Partition Table is located at offset `1BEh`, i.e. `446` bytes from the beginning of the MBR sector. The partition table is four 16-byte records: one record describes one partition. This means that the maximum number of partitions on one hard disk is limited to 4. Partition descriptor format is shown below (in the table).

| Boot Flag | Begin Head | Begin Cyl/Sec | System Code | Ending Head | Enging Cyl/Sec | Begin Sector | Num Sectors
|:----------------:|:---------:|:----------------:|:----------------:|:----------------:|:----------------:|:----------------:|:----------------:|
| 1 byte | 1 bytes | 2 bytes | 1 byte | 1 byte | 2 bytes | 4 bytes | 4 bytes |

Searching for an extended partition in the Partition Table boils down to finding a partition record where the ystem Code field takes the value `05h` or `0Fh`. After finding an extended partition thanks to the Begin Sector field you can find out the absolute number of the sector where the extended partition begins. The sector number of the partition's beginning is set by linear addressing - `LBA`.

Information about the internal structure of an extended partition is located inside the partition itself. Therefore, to get information about the structure of an extended partition, you need to jump to a sector whose number has already been extracted from the Begin Sector field.

The first sector of an extended partition is an Extended Partition Record (EPR) sector. As opposed to the Partition Table with a fixed number of partition descriptors, the organization of information about logical disks of an extended partition is dynamic. Each Logical Disk Table contains two main references: to the beginning sector of the current logical disk and to the EPR sector of the next logical disk. Thanks to this, the number of logical disks in an extended partition is not limited.

Logical disk table is located in the EPR sector at an offset of `1BEh` bytes from the beginning of the sector and consists of two 16-byte descriptors, some fields of which are similar to partition table descriptors.

| Boot Flag | Begin Head | Begin Cyl/Sec | System Code | Ending Head | Enging Cyl/Sec | Rel_Begin Sector | Num Sectors
|:----------------:|:---------:|:----------------:|:----------------:|:----------------:|:----------------:|:----------------:|:----------------:|
| Boot Flag | Begin Head | Begin Cyl/Sec | System Code | Begin Head-2 | Begin Cyl/Sec-2 | Rel_EPR-2 | Rel_EPR-3
| 1 byte | 1 bytes | 2 bytes | 1 byte | 1 byte | 2 bytes | 4 bytes | 4 bytes |

The first descriptor contains information about the logical disk. In particular, the `System Code` field allows you to define the file system of the logical disk, which is necessary for compatibility control: two logical disks to be merged must have the same file system. The `Ending Head` and `Ending CylSec` fields allow defining CHS-coordinates of the logical disk end. The `Rel_Begin Sector` field indicates the offset from this EPR table to the beginning of the logical disk, and the `NumSector` field allows to determine the size of the logical disk.

The second descriptor contains information to locate the EPR sector of the next logical drive. If there is no next logical drive, the second descriptor is zero. The most useful field in the second descriptor is the `Rel_EPR-2` field, indicating the offset from the beginning of the extended partition to the next EPR sector. The `Begin Head`, `Begin Cyl/Sec` and `Begin Head-2`, `Begin Cyl/Sec-2` fields indicate the CHS-coordinates of the beginning of the next EPR and the next.

# Requirements and limitations
- Software access to physical hard disk and a logical disk objects is performed at the sector level without using high-level services of the operating system.
- To address devices (keyboard input, screen output) high-level services for application programs are used.
- The utility uses a parameter specified at startup from the command line after the name of the executable program. The parameter is the number of the physical hard disk drive, a number written in decimal form and ranging from `0-3`.
- The number of logical disks in the extended partition is limited to `23`.
- When prompted, the number of the first logical drive to merge is entered in decimal form using the keyboard. The logical drive with the number entered will be merged with the next logical drive. The range of numbers of existing logical disks will be preliminarily displayed in decimal form.
- The logical disks selected for merging must have the same file system.

# Environments

## Operating environment
The program is designed to run in a 16-bit operating environment running in real CPU mode, such as MSDOS. This is due to the fact that in the protected mode of the processor, attempts to directly access the hard disk sectors will be blocked by the operating system.

## Development environment
Assembler program development was performed in such a development environment as Borland Turbo Assembler (TASM) - Borland software package designed to develop assembly language programs for x86 architecture.

## Debugging environment
Assembler program debugging was performed in such a debugging environment as Borland Turbo Assembler (TASM) - Borland software package designed to develop assembly language programs for x86 architecture.

# Using the utility

# Program structure

Segmented program structure:
- Code segment (pointer is `CS`)
- Data segment (pointer is `DS`) – for placing data in the memory.

## Variables

| Name | Size (bytes) | Assignment |
|:----------------:|:---------:|----------------|
| `sector1` | 512 | Buffer for placing bytes from the sector |
| `sector2` | 512 | Buffer for placing bytes from the sector |
| `packet` | 16 | Disk address packet |
| `msg_ld_count` | – | A message inviting you to enter the number of the first logical disk to merge |
| `ld_count_ascii` | 2 | Number of logical disks in the extended partition, prepared for display in decimal form |
| `input_ld` | 5 | Buffer for keyboard entry of the number of the first logical disk to merge (in ASCII) |
| `hd_number` | 1 | Identifier of the hard disk with which you are working |
| `ld_number` | 1 | Identifier of the first logical disk to be merged |
| `ld_count` | 1 | Number of logical disks in the extended partition |
| `lba_list` | 4 x 23 = 92 | Array of CHS-coordinates of sectors with EPR, in which there is a record about a logical disk |
| `msg_usage` | – | Message with guidance on specifying arguments when running the utility from the console |
| `msg_success` | – | Message about successful merging of two logical disks in an extended partition |
| `msg_err_r_sector` | – | Error message: failed to read sector |
| `msg_err_w_sector` | – | Error message: failed to write sector |
| `msg_err_wrong_ld` | – | Error message: invalid number of the first logical disk to merge |
| `msg_err_no_2ld` | – | Error message: there are less than two logical disks in the extended partition |
| `msg_err_diff_code` | – | Error message: disks to be merged have different file system |
| `msg_err_no_epart` | – | Error message: No extended partition entry found in MBR sector |

## Constants

| Name | Value | Assignment |
|:----------------:|:---------:|----------------|
| `BOOT_RECORD` | `1BEh` | Boot record offset |
| `DSCR_SIZE` | `10h` | Size of a descriptor or a record |
| `DSCR_COUNT` | `04h` | Maximum number of descriptors |
| `DSCR_F_CHS_END` | `05h` | Offset to the `Ending CHS` field from the beginning of the MBR table |
| `DSCR_F_CODE` | `04h` | Offset to the `System Code` field from the beginning of the MBR/EPR table |
| `DSCR_F_BEGIN` | `08h` | Offset to the `Begin Sector` field (in LBA) from the beginning of the EPR table |
| `DSCR_F_SIZE` | `0Ch` | Offset to the `Num Sectors` field from the beginning of the EPR table |
| `DSCR_F2_REL` | `18h` | Offset to the `Rel_EPR` field from the beginning of the EPR table |
| `DSCR_F2_CODE` | `14h` | Offset to the `System Code` field from the beginning of the EPR table |

## Procedures

1. `ascii_to_hex_hd` procedure.

Description: performs ASCII-character conversion with hard disk number to hex, checks hard disk number correctness (belonging to the interval `0...3`) and increments hard disk number by `80h`.

Parameters: 
- `AL` – ASCII character code with hard disk number.
- Return `AL` – hard disk number in heximal form.
- Return `CF` – error flag (CF=1 - error).

2. `ascii_to_hex_ld` procedure.

Description: performs conversion of ASCII-string with logical disk number to hex, checks if logical disk number is correct (belongs to `1...DL` interval) and writes logical disk number to the `DS:DI` address.

Parameters: 
- `SI` – the address of the input area where the ASCII string with the number of the logical disk was entered.
- `DI` – the address of the logical disk number location area in hexadecimal form.
- `DL` – the number of logical disks in the extended partition.
- Return `DI` – the written logical disk number in memory at address `DS:DI`.
- Return `CF` – error flag (CF=1 - error).

3. `hex_to_ascii_ld` procedure.

Description: converts the number of logical disks into an ASCII-string and places the string in memory at `DS:SI`.

Parameters: 
- `SI` – the address of the memory area where you want to write the ASCII-string.
- `BL` – the number of logical disks in the extended partition.
- Return `SI` – written ASCII-string with the number of logical disks in memory at address `DS:SI`.

4. `find_extended` procedure. 

Description: searches for the extended partition record in the MBR partition table and positions the `SI` at the beginning of the extended partition record.

Parameters: 
- `SI` – the address of the sector location area in memory.
- Return `SI` – the address of the beginning of the extended partition record, if `CF=0`.
- Return `CF` – error flag (CF=1 - error).

## Macros

1. Macro `throw`.

Description: enters the message specified in the message parameter and unconditionally passes to the 'Message output' block.

Parameters:
- `message` – text message to be displayed on the screen.

2. Macro `throw_c`.

Description: enters the message specified in the message parameter and proceeds to the "Message output" block if `CF=1`.

Parameters:
- `message` – text message to be displayed on the screen.

3. Macro `throw_e`.

Description: enters the message specified in the message parameter and proceeds to the "Message output" block if `ZF=1`.

Parameters:
- `message` – text message to be displayed on the screen.

4. Macro `read_sector`.

Description: reads a sector on the hard disk with the `drive` number with the `packet` of the disk address `packet`. After reading the sector it uses the macro command `throw_c` with the `message` parameter.

Parameters:
- `drive` – the number of the hard disk drive from which you want to read.
- `packet` – intra-segment packet address of the disk address.
- `message` – text message to be displayed on the screen.

# Examples
