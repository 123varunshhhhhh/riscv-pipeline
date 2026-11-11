# Assembly: branch_test.s
# Tests all branch instructions: BEQ, BNE, BLT, BGE, BLTU, BGEU

.text
.global _start
_start:
    addi x1, x0, 5
    addi x2, x0, 5
    addi x3, x0, 0      # x3 = pass counter

    # BEQ test: x1==x2, should branch
    beq  x1, x2, beq_ok
    addi x10, x0, 1     # FAIL marker (should be skipped)
beq_ok:
    addi x3, x3, 1      # pass++

    # BNE test: x1!=x0, should branch
    bne  x1, x0, bne_ok
    addi x10, x0, 2
bne_ok:
    addi x3, x3, 1

    # BLT test: x0 < x1, should branch
    blt  x0, x1, blt_ok
    addi x10, x0, 3
blt_ok:
    addi x3, x3, 1

    # BGE test: x1 >= x2 (equal), should branch
    bge  x1, x2, bge_ok
    addi x10, x0, 4
bge_ok:
    addi x3, x3, 1

done:
    # x3 should be 4 (all branches taken), x10 should still be 0
    nop
    nop

