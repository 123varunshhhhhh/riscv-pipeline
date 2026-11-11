"""
golden_model.py — Python Software Reference Model for RV32I
Acts as the ground truth during co-simulation with the RTL.
Every instruction executed here defines the CORRECT architectural state.
"""

class RV32IGoldenModel:
    def __init__(self):
        self.regs = [0] * 32   # x0–x31 general-purpose registers
        self.pc   = 0           # Program Counter
        self.mem  = {}          # Sparse byte-addressable memory dict
        self.cycle_count   = 0
        self.instr_count   = 0

    # ----------------------------------------------------------------
    # Memory helpers
    # ----------------------------------------------------------------
    def _store_byte(self, addr, val):
        self.mem[addr] = val & 0xFF

    def _load_byte(self, addr):
        return self.mem.get(addr, 0)

    def _store_word(self, addr, val):
        for i in range(4):
            self._store_byte(addr + i, (val >> (8 * i)) & 0xFF)

    def _load_word(self, addr):
        return sum(self._load_byte(addr + i) << (8 * i) for i in range(4))

    def _load_half(self, addr, signed=True):
        v = self._load_byte(addr) | (self._load_byte(addr + 1) << 8)
        if signed and (v & 0x8000):
            v -= 0x10000
        return v & 0xFFFFFFFF

    # ----------------------------------------------------------------
    # Sign / mask helpers
    # ----------------------------------------------------------------
    @staticmethod
    def _sign_ext(val, bits):
        sign = 1 << (bits - 1)
        return (val & (sign - 1)) - (val & sign)

    @staticmethod
    def _mask32(val):
        return val & 0xFFFFFFFF

    # ----------------------------------------------------------------
    # Immediate decoders
    # ----------------------------------------------------------------
    @staticmethod
    def _imm_i(instr):
        return RV32IGoldenModel._sign_ext(instr >> 20, 12)

    @staticmethod
    def _imm_s(instr):
        return RV32IGoldenModel._sign_ext(
            ((instr >> 25) << 5) | ((instr >> 7) & 0x1F), 12)

    @staticmethod
    def _imm_b(instr):
        b12  = (instr >> 31) & 1
        b11  = (instr >>  7) & 1
        b10_5= (instr >> 25) & 0x3F
        b4_1 = (instr >>  8) & 0xF
        raw  = (b12 << 12) | (b11 << 11) | (b10_5 << 5) | (b4_1 << 1)
        return RV32IGoldenModel._sign_ext(raw, 13)

    @staticmethod
    def _imm_u(instr):
        return instr & 0xFFFFF000

    @staticmethod
    def _imm_j(instr):
        b20     = (instr >> 31) & 1
        b19_12  = (instr >> 12) & 0xFF
        b11     = (instr >> 20) & 1
        b10_1   = (instr >> 21) & 0x3FF
        raw     = (b20 << 20) | (b19_12 << 12) | (b11 << 11) | (b10_1 << 1)
        return RV32IGoldenModel._sign_ext(raw, 21)

    # ----------------------------------------------------------------
    # Execute one instruction; returns dict of updated state
    # ----------------------------------------------------------------
    def execute(self, instr: int) -> dict:
        self.instr_count += 1
        opcode = instr & 0x7F
        rd     = (instr >>  7) & 0x1F
        f3     = (instr >> 12) & 0x7
        rs1    = (instr >> 15) & 0x1F
        rs2    = (instr >> 20) & 0x1F
        f7     = (instr >> 25) & 0x7F
        pc     = self.pc

        def r(reg): return self.regs[reg]
        def w(reg, val):
            if reg != 0:
                self.regs[reg] = self._mask32(val)

        # R-type
        if opcode == 0x33:
            if   f3 == 0x0 and f7 == 0x00: w(rd, r(rs1) + r(rs2))          # ADD
            elif f3 == 0x0 and f7 == 0x20: w(rd, r(rs1) - r(rs2))          # SUB
            elif f3 == 0x7:                w(rd, r(rs1) & r(rs2))           # AND
            elif f3 == 0x6:                w(rd, r(rs1) | r(rs2))           # OR
            elif f3 == 0x4:                w(rd, r(rs1) ^ r(rs2))           # XOR
            elif f3 == 0x2:                w(rd, 1 if self._sign_ext(r(rs1), 32) < self._sign_ext(r(rs2), 32) else 0)  # SLT
            elif f3 == 0x3:                w(rd, 1 if r(rs1) < r(rs2) else 0)  # SLTU
            elif f3 == 0x1:                w(rd, r(rs1) << (r(rs2) & 0x1F)) # SLL
            elif f3 == 0x5 and f7 == 0x00: w(rd, r(rs1) >> (r(rs2) & 0x1F))  # SRL
            elif f3 == 0x5 and f7 == 0x20: w(rd, self._sign_ext(r(rs1), 32) >> (r(rs2) & 0x1F))  # SRA
            self.pc += 4

        # I-type ALU
        elif opcode == 0x13:
            imm = self._imm_i(instr)
            if   f3 == 0x0: w(rd, r(rs1) + imm)   # ADDI
            elif f3 == 0x7: w(rd, r(rs1) & imm)   # ANDI
            elif f3 == 0x6: w(rd, r(rs1) | imm)   # ORI
            elif f3 == 0x4: w(rd, r(rs1) ^ imm)   # XORI
            elif f3 == 0x2: w(rd, 1 if self._sign_ext(r(rs1), 32) < imm else 0)  # SLTI
            elif f3 == 0x3: w(rd, 1 if r(rs1) < (imm & 0xFFFFFFFF) else 0)        # SLTIU
            elif f3 == 0x1: w(rd, r(rs1) << (imm & 0x1F))  # SLLI
            elif f3 == 0x5:
                shamt = imm & 0x1F
                if f7 == 0x00: w(rd, r(rs1) >> shamt)  # SRLI
                else:          w(rd, self._sign_ext(r(rs1), 32) >> shamt)  # SRAI
            self.pc += 4

        # Load
        elif opcode == 0x03:
            addr = self._mask32(r(rs1) + self._imm_i(instr))
            if   f3 == 0x2: w(rd, self._load_word(addr))           # LW
            elif f3 == 0x1: w(rd, self._load_half(addr, True))     # LH
            elif f3 == 0x0: w(rd, self._sign_ext(self._load_byte(addr), 8))  # LB
            elif f3 == 0x5: w(rd, self._load_half(addr, False))    # LHU
            elif f3 == 0x4: w(rd, self._load_byte(addr))           # LBU
            self.pc += 4

        # Store
        elif opcode == 0x23:
            addr = self._mask32(r(rs1) + self._imm_s(instr))
            if   f3 == 0x2: self._store_word(addr, r(rs2))                     # SW
            elif f3 == 0x1:
                self._store_byte(addr, r(rs2) & 0xFF)
                self._store_byte(addr+1, (r(rs2) >> 8) & 0xFF)                 # SH
            elif f3 == 0x0: self._store_byte(addr, r(rs2) & 0xFF)              # SB
            self.pc += 4

        # Branch
        elif opcode == 0x63:
            imm = self._imm_b(instr)
            a, b = self._sign_ext(r(rs1), 32), self._sign_ext(r(rs2), 32)
            taken = False
            if   f3 == 0x0: taken = (r(rs1) == r(rs2))   # BEQ
            elif f3 == 0x1: taken = (r(rs1) != r(rs2))   # BNE
            elif f3 == 0x4: taken = (a < b)               # BLT
            elif f3 == 0x5: taken = (a >= b)              # BGE
            elif f3 == 0x6: taken = (r(rs1) < r(rs2))    # BLTU
            elif f3 == 0x7: taken = (r(rs1) >= r(rs2))   # BGEU
            self.pc = self._mask32(pc + imm) if taken else pc + 4

        # JAL
        elif opcode == 0x6F:
            w(rd, pc + 4)
            self.pc = self._mask32(pc + self._imm_j(instr))

        # JALR
        elif opcode == 0x67:
            w(rd, pc + 4)
            self.pc = self._mask32((r(rs1) + self._imm_i(instr)) & ~1)

        # LUI
        elif opcode == 0x37:
            w(rd, self._imm_u(instr))
            self.pc += 4

        # AUIPC
        elif opcode == 0x17:
            w(rd, self._mask32(pc + self._imm_u(instr)))
            self.pc += 4

        else:
            self.pc += 4  # Unknown / FENCE / SYSTEM — treat as NOP

        # x0 is always 0
        self.regs[0] = 0

        return {
            "pc":   self.pc,
            "regs": list(self.regs),
            "mem":  dict(self.mem)
        }

