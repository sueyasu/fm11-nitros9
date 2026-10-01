# NitrOS-9 for Fujitsu FM-11

This repository contains a port of [NitrOS-9](https://github.com/nitros9project/nitros9) for the Fujitsu FM-11.

It is maintained as a fork of the upstream NitrOS-9 source tree. FM-11-specific sources are kept separate where practical so that changes from upstream can continue to be incorporated.

## Current status

NitrOS-9 Level 1 is operational on the FM-11.

The current implementation includes:

- Motorola 6809 support
- Hitachi HD63C09 support, including native mode
- FM-11 local console
- USART0 serial terminal support
- 5.25-inch 2D floppy support
- 5.25-inch 2HD floppy support
- FM-11 hard disk interface support
- RBF/RBSuper filesystem support
- Pipes
- ANSI/VT100 terminal support
- FM-11-aware `format`, `cobbler`, and `os9gen`
- FM-11 MMR/MMU diagnostic programs for future Level 2 development

FM-11-specific Level 1 sources are primarily located under:

```text
level1/fm11/
```

Shared NitrOS-9 sources are used directly wherever possible.

Level 2 support is not yet included as a usable system. Development of an FM-11 Level 2 port is planned.

## Building

The FM-11 build currently requires:

- [LWTOOLS](http://lwtools.projects.l-w.ca/), including `lwasm`
- [ToolShed](https://github.com/n6il/toolshed), including the `os9` command
- Python 3
- Standard Unix command-line utilities

Clone the repository and run:

```sh
git clone https://github.com/sueyasu/fm11-nitros9.git
cd fm11-nitros9
./build-minimal.sh
```

This builds both 6809 and HD63C09 Level 1 systems and creates four bootable D88 floppy images:

```text
fm11-system-6809-2d.d88
fm11-system-6809-2hd.d88
fm11-system-6309-2d.d88
fm11-system-6309-2hd.d88
```

A single CPU target can also be built with:

```sh
./build-cpu.sh 6809
```

or:

```sh
./build-cpu.sh 6309
```

## Disk configuration

The build provides separate 2D and 2HD system images.

For the 2D system profile:

```text
/D0, /D1 = 5.25-inch 2D drives
/D2, /D3 = 5.25-inch 2HD drives
```

For the 2HD system profile:

```text
/D0, /D1 = 5.25-inch 2HD drives
/D2, /D3 = 5.25-inch 2D drives
```

The physical device names used internally are:

```text
/MD0, /MD1 = 5.25-inch 2D
/ND0, /ND1 = 5.25-inch 2HD
```

Hard disk device descriptors are also included for supported FM-11 hard disk geometries.

## Source layout

Important FM-11-specific files are located in:

```text
defs/fm11.d
level1/fm11/
```

The `level1/fm11/` tree contains:

```text
bootlists/   boot module lists
cmds/        FM-11-specific command variants and diagnostics
ipl/         FM-11 ROM bootstrap code
modules/     device drivers, descriptors, boot and console modules
sys/         FM-11-specific help sources
```

The root-level build and image-generation scripts are currently specific to the FM-11 port.

## Versioning

GitHub-based versioning of this port begins with:

```text
fm11-v0.1
```

Earlier version numbers used during initial bring-up and testing are development history and are not part of the Git tag versioning scheme.

## Upstream

This repository is based on the NitrOS-9 project:

[NitrOS-9 Project](https://github.com/nitros9project/nitros9)

Changes from upstream NitrOS-9 will continue to be incorporated while maintaining the FM-11 port in this repository.

## License

This repository retains the licensing terms of the upstream NitrOS-9 sources. Individual files may contain additional copyright and licensing information; refer to the source files and upstream project for details.
