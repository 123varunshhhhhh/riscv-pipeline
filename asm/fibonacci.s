# Assembly: fibonacci.s
# Computes Fibonacci(10) = 55
# x1=fib[n-2], x2=fib[n-1], x3=counter, x4=temp
# Final: x2 = 55

.text
.global _start
_start:
    addi x1, x0, 0      # fib[0] = 0
    addi x2, x0, 1      # fib[1] = 1
    addi x3, x0, 9      # loop 9 times → after 9 iters x2=fib(10)=55

loop:
    add  x4, x1, x2     # x4 = fib[n-2] + fib[n-1]
    addi x1, x2, 0      # x1 = old x2
    addi x2, x4, 0      # x2 = new fib
    addi x3, x3, -1     # decrement counter
    bne  x3, x0, loop   # loop if x3 != 0

done:
    nop
    nop
    nop

