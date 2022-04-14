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
The program is started from the command line. The program name is followed by one input parameter - the number of the hard disk drive to be operated (the input parameter is a number in decimal form from 0 to 3 inclusive). The program translates the entered number in decimal to hexadecimal and checks if the data is correct. If the data entered is incorrect, the user is prompted for a `Usage: HD number: 0...3` and program execution stops.

The program attempts to read the MBR sector of the hard disk drive entered. If that fails the user receives an error message on the screen: `Invalid sector reading` and program execution stops.

After a successful reading of the MBR sector, the program looks for the extended partition in the Partition Table. If there is no extended partition in the Partition Table, you will see an error message: `This HD has no extended partition` and the program stops executing.

If an entry of an extended partition is found in the Partition Table, the program "runs" through all Logical Disk Patterns (EPR) created in the extended partition and fills in an array with sector CHS-coordinates of those tables while counting the number of such found tables. If the number of logical disks in an extended partition is less than two, the user will see an error message: `There are no 2 logical disks`, and the program stops executing

Also, during the process of searching for logical disks in the extended partition, a sector reading error may occur - in this case the user will receive an `Invalid sector reading` error message on the screen and the program will abort.

In case the program finds two or more logical disks in an extended partition, it will prompt the user to enter the number of the first logical disk to be merged (it will be merged with the next one) in decimal notation. The program prompts you with a range of existing logical disk numbers. For example, if you have created 4 logical disks in the extended partition, the program will report this as follows: `Enter first LD for merging: 1 – 4`.

After the user has entered the data, the program will check if the entered data is correct and if the logical discs can be merged. The number you have entered should be in the range `1...N-1`, where `N` is the number of logical disks in the extended partition. If you enter an invalid logical disk number for combination, you will receive an error message on the screen: `Invalid logical disk number`.

As for the possibility of combining the selected logical disks, they should be with the same file system. In case the selected logical disks have different file systems, the user receives an error text: `Your logical disks have different file system`. In both cases the program will crash.
After receiving complete and correct information from the user, the program reads the two selected sectors to be merged into memory.

1. Increases the size of the first logical disk the size of the second logical disk and by the offset from the EPR of the second logical disk to the beginning of the disk itself.
2. Copies the CHS-coordinates of the end of the second logical disk in place of the CHS-coordinates of the end of the first logical disk.
3. Copies the second descriptor of the EPR table of the second logical disk in place of the second descriptor of the EPR table of the first logical disk.

When the above procedures are completed, the program writes the modified EPR sector of the first logical drive to the hard disk. If there are writing errors, the user gets an error text on the screen: `Invalid sector writing` and the program is interrupted.

Finally if the program succeeds the user receives a message on the screen: `Your logical disks were merged` and then the program stops.

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
According to the MSDOS operating system's internal disk manager, `fdisk`, the hard disk 1 has two partitions: a primarity partition (1) and an extended partition (2).
<p align="center">
    <img src="https://user-images.githubusercontent.com/37341526/163341297-02f7aa2b-dfc7-4ac5-96f5-027c3ee18064.png" alt="Image" />
</p>

Four logical disks are created in the extended partition:
<p align="center">
    <img src="https://user-images.githubusercontent.com/37341526/163341335-4bd8e040-0ee8-41fc-b5c2-9b1045df15b0.png" alt="Image" />
</p>

1. `E` - the logical drive is 133 MB in size.
2. `F` - the logical drive is 133 MB in size.
3. `G` - the logical drive is 133 MB in size.
4. `H` - the logical drive is 133 MB in size.

When starting the utility from the command line, you must set the parameter - the number of the hard disk (1).
<p align="center">
    <img src="https://user-images.githubusercontent.com/37341526/163341469-fe00cb2d-7be3-4896-a3ae-239677cc1d9c.png" alt="Image" />
</p>

When the utility determines the number of logical disks in the extended partition, the user will be prompted to choose which of the logical disks he wants to merge with the next.
<p align="center">
    <img src="https://user-images.githubusercontent.com/37341526/163341593-befd849e-7e66-4ee0-9f0b-92d8191a32b0.png" alt="Image" />
</p>

After merging the logical disks, the user receives a text message on the screen.
<p align="center">
    <img src="https://user-images.githubusercontent.com/37341526/163341613-a4df84fc-23fe-4ad2-952a-f2f004ee342f.png" alt="Image" />
</p>

In the internal disk manager `fdisk` users can see how all the changes are now displayed.
<p align="center">
    <img src="https://user-images.githubusercontent.com/37341526/163342228-da2b89b9-62d8-4b3e-9eb7-5ffef029ffc1.png" alt="Image" />
</p>
