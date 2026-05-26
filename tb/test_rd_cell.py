"""Unit test: rd_cell RTL vs Python golden fixed-point cell math (bit-exact)."""
import cocotb
from cocotb.triggers import Timer
import random

FRAC = 12
ONE = 1 << FRAC
W_D, W_O, W_C = 205, 819, 4096
DU, DV, FF, FK = 655, 328, 238, 496


def golden_cell(u, v):
    # u, v are dicts with keys c,n,s,e,w,ne,nw,se,sw
    def sar(x):  # arithmetic >>12 = floor, matches Verilog >>> and numpy >>
        return x >> FRAC
    u_diag = u['ne'] + u['nw'] + u['se'] + u['sw']
    u_orth = u['n'] + u['s'] + u['e'] + u['w']
    v_diag = v['ne'] + v['nw'] + v['se'] + v['sw']
    v_orth = v['n'] + v['s'] + v['e'] + v['w']
    lapU = sar(u_diag * W_D + u_orth * W_O - u['c'] * W_C)
    lapV = sar(v_diag * W_D + v_orth * W_O - v['c'] * W_C)
    uv = sar(u['c'] * v['c'])
    uvv = sar(uv * v['c'])
    un = u['c'] + sar(DU * lapU) - uvv + sar(FF * (ONE - u['c']))
    vn = v['c'] + sar(DV * lapV) + uvv - sar(FK * v['c'])
    un = max(0, min(ONE, un))
    vn = max(0, min(ONE, vn))
    return un, vn


@cocotb.test()
async def test_cell(dut):
    rng = random.Random(42)
    fails = 0
    for i in range(500):
        u = {key: rng.randint(0, ONE) for key in ['c', 'n', 's', 'e', 'w', 'ne', 'nw', 'se', 'sw']}
        v = {key: rng.randint(0, ONE) for key in ['c', 'n', 's', 'e', 'w', 'ne', 'nw', 'se', 'sw']}
        dut.u_c.value = u['c']; dut.u_n_.value = u['n']; dut.u_s.value = u['s']
        dut.u_e.value = u['e']; dut.u_w.value = u['w']
        dut.u_ne.value = u['ne']; dut.u_nw.value = u['nw']; dut.u_se.value = u['se']; dut.u_sw.value = u['sw']
        dut.v_c.value = v['c']; dut.v_n_.value = v['n']; dut.v_s.value = v['s']
        dut.v_e.value = v['e']; dut.v_w.value = v['w']
        dut.v_ne.value = v['ne']; dut.v_nw.value = v['nw']; dut.v_se.value = v['se']; dut.v_sw.value = v['sw']
        await Timer(1, unit="ns")
        eu, ev = golden_cell(u, v)
        gu, gv = int(dut.u_o.value), int(dut.v_o.value)
        if (gu, gv) != (eu, ev):
            fails += 1
            if fails <= 5:
                dut._log.info(f"MISMATCH #{i}: rtl=({gu},{gv}) exp=({eu},{ev})")
    assert fails == 0, f"{fails}/500 cell mismatches"
    dut._log.info("rd_cell matches golden bit-exact over 500 random windows")
