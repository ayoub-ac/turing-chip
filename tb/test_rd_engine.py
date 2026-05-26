"""Full-grid test: rd_engine vs Python golden fixed-point, 32x32 torus.
Testbench models the dual framebuffer SRAM (1-cycle read latency) and the
ping-pong; after N frames the engine buffer must equal the golden after N steps.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np

GW, GH = 32, 32
N_FRAMES = 150
FRAC = 12
ONE = 1 << FRAC
Du, Dv, F, k = 655, 328, 238, 258
WD, WO, WC = 205, 819, 4096
FK = F + k


def make_seed():
    rng = np.random.default_rng(7)
    U = np.full((GH, GW), ONE, dtype=np.int64)
    V = np.zeros((GH, GW), dtype=np.int64)
    mask = rng.random((GH, GW)) < 0.10
    V[mask] = ONE // 2
    U[mask] = ONE // 2
    return U, V


def golden_step(U, V):
    def lap(Z):
        diag = (np.roll(np.roll(Z, 1, 0), 1, 1) + np.roll(np.roll(Z, 1, 0), -1, 1)
                + np.roll(np.roll(Z, -1, 0), 1, 1) + np.roll(np.roll(Z, -1, 0), -1, 1))
        orth = (np.roll(Z, 1, 0) + np.roll(Z, -1, 0) + np.roll(Z, 1, 1) + np.roll(Z, -1, 1))
        return (diag * WD + orth * WO - Z * WC) >> FRAC
    UV = (U * V) >> FRAC
    UVV = (UV * V) >> FRAC
    Un = U + ((Du * lap(U)) >> FRAC) - UVV + ((F * (ONE - U)) >> FRAC)
    Vn = V + ((Dv * lap(V)) >> FRAC) + UVV - ((FK * V) >> FRAC)
    return np.clip(Un, 0, ONE), np.clip(Vn, 0, ONE)


@cocotb.test()
async def test_engine(dut):
    U, V = make_seed()
    # golden N steps
    gU, gV = U.copy(), V.copy()
    for _ in range(N_FRAMES):
        gU, gV = golden_step(gU, gV)

    # framebuffer: 2 buffers of GW*GH 32-bit words {v,u}
    fb = [np.zeros(GW * GH, dtype=np.int64), np.zeros(GW * GH, dtype=np.int64)]
    for r in range(GH):
        for c in range(GW):
            fb[0][r * GW + c] = (int(V[r, c]) << 16) | int(U[r, c])

    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    dut.rst_ni.value = 0
    dut.start_i.value = 0
    dut.rd_data_i.value = 0
    await Timer(30, unit="ns")
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)
    dut.start_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.start_i.value = 0

    rd_addr_q = 0
    frames = 0
    max_cycles = N_FRAMES * GW * GH * 22 + 10000
    cyc = 0
    while frames < N_FRAMES and cyc < max_cycles:
        cyc += 1
        # service read issued last cycle (1-cycle latency) from current read buffer
        rbuf = int(dut.buf_sel_o.value)
        dut.rd_data_i.value = int(fb[rbuf][rd_addr_q])
        await Timer(1, unit="ns")
        # capture write (to write buffer = ~rbuf)
        if int(dut.wr_en_o.value) == 1:
            wbuf = rbuf ^ 1
            fb[wbuf][int(dut.wr_addr_o.value)] = int(dut.wr_data_o.value)
        # latch read address for next cycle
        if int(dut.rd_en_o.value) == 1:
            rd_addr_q = int(dut.rd_addr_o.value)
        if int(dut.frame_o.value) == 1:
            frames += 1
        await RisingEdge(dut.clk_i)

    # frame N output is in the buffer just written = current read-buf XOR 1
    best = None
    for which in (int(dut.buf_sel_o.value) ^ 1, int(dut.buf_sel_o.value)):
        out = fb[which]
        rU = np.array([out[i] & 0xFFFF for i in range(GW * GH)]).reshape(GH, GW)
        rV = np.array([(out[i] >> 16) & 0xFFFF for i in range(GW * GH)]).reshape(GH, GW)
        d = int(np.abs(rU - gU).max()) + int(np.abs(rV - gV).max())
        if best is None or d < best[0]:
            best = (d, which, rU, rV)
    _, which, rU, rV = best
    du = int(np.abs(rU - gU).max())
    dv = int(np.abs(rV - gV).max())
    dut._log.info(f"best buffer={which}")
    mm=np.argwhere((rU!=gU)|(rV!=gV))
    for (r,c) in mm[:6]:
        dut._log.info(f"  cell({r},{c}): rtl U={rU[r,c]} V={rV[r,c]} | gold U={gU[r,c]} V={gV[r,c]}")
    dut._log.info(f"frames={frames} cyc={cyc} maxdiff U={du} V={dv} | golden V std={gV.std()/ONE:.4f} rtl V std={rV.std()/ONE:.4f}")
    assert frames == N_FRAMES, f"only {frames} frames ran"
    assert du == 0 and dv == 0, f"mismatch vs golden: U={du} V={dv}"
    dut._log.info("rd_engine matches golden bit-exact after 150 frames — Turing pattern verified")
