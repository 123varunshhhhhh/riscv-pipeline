# Assembly: basic_arith.s
# Tests: ADD, SUB, ADDI, AND, OR, XOR, SLT
# Expected final register values listed in comments

.text
.global _start
_start:
    addi x1, x0, 10      # x1 = 10
    addi x2, x0, 7       # x2 = 7
    add  x3, x1, x2      # x3 = 17
    sub  x4, x1, x2      # x4 = 3
    and  x5, x1, x2      # x5 = 2  (1010 & 0111)
    or   x6, x1, x2      # x6 = 15 (1010 | 0111)
    xor  x7, x1, x2      # x7 = 13 (1010 ^ 0111)
    slt  x8, x2, x1      # x8 = 1  (7 < 10)
    slt  x9, x1, x2      # x9 = 0  (10 < 7 = false)
    addi x10, x3, -5     # x10 = 12
    nop
    nop

