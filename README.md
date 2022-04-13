# disk-merger
A 16-bits x86 DOS Assembly console tool for merging two contiguous logical disks in an extended partition. 

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

## Variables

## Procedures

## Macros

# Examples
