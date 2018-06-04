all:
	/home/babypaw/riscv/riscv-32/bin/riscv32-unknown-linux-gnu-gcc -Wall -Werror -mcmodel=medany -march='rv32i' -mabi=ilp32 -std=gnu99 -Wno-unused -Wno-attributes -fno-delete-null-pointer-checks -c entry.S
	/home/babypaw/riscv/riscv-32/bin/riscv32-unknown-linux-gnu-gcc -O2 -Wall -Werror -mcmodel=medany -march='rv32i' -mabi=ilp32 -std=gnu99 -Wno-unused -Wno-attributes -fno-delete-null-pointer-checks -c test.c
	/home/babypaw/riscv/riscv-32/bin/riscv32-unknown-linux-gnu-gcc -march='rv32i' -mabi=ilp32 -nostartfiles -nostdlib -static -o rv_32_elf entry.o test.o -T test.lds -Xlinker -Map=output.map
	/home/babypaw/riscv/riscv-32/bin/riscv32-unknown-linux-gnu-objcopy -O binary rv_32_elf rv_32.bin --pad-to 0x2000
	/home/babypaw/riscv/riscv-32/bin/riscv32-unknown-linux-gnu-gcc -march='rv32i' -mabi=ilp32 -nostartfiles -nostdlib -static -o sim_elf entry.o test.o -T sim.lds -Xlinker -Map=sim.map
	/home/babypaw/riscv/riscv-32/bin/riscv32-unknown-linux-gnu-objcopy -O binary sim_elf sim.bin --pad-to 0x2000

clean:
	rm rv_32.bin rv_32_elf entry.o test.o output.map sim.map sim.bin sim_elf
