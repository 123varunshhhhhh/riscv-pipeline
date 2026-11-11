# Assembly: load_store.s
# Tests: SW, LW, SH, LH, SB, LB

.text
.global _start
_start:
    addi x1, x0, 200    # base address = 200

    addi x2, x0, 0xAB   # x2 = 0xAB
    sw   x2, 0(x1)       # mem[200] = 0xAB
    lw   x3, 0(x1)       # x3 = mem[200] = 0xAB
                          # x3 should == 0xAB

    addi x4, x0, 0x1234
    sh   x4, 4(x1)        # mem[204] = lower 16 bits = 0x1234
    lh   x5, 4(x1)        # x5 = sign-extended 0x1234

    addi x6, x0, 0xFF
    sb   x6, 8(x1)        # mem[208] = 0xFF
    lb   x7, 8(x1)        # x7 = sign-extended 0xFF = -1 = 0xFFFFFFFF

    nop
    nop

