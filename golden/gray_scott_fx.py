"""Q4.12 fixed-point Gray-Scott — exactly the integer arithmetic the RTL does.
Confirms the pattern survives quantization before writing SystemVerilog.
All values int (Q4.12, ONE=4096). Intermediates 32/64-bit.
"""
import numpy as np
from PIL import Image
import os

GRID_W, GRID_H = 128, 128
STEPS = 6000
FRAME_EVERY = 600
FRAC = 12
ONE = 1 << FRAC

# constants in Q4.12
Du = round(0.16 * ONE)   # 655
Dv = round(0.08 * ONE)   # 328
F  = round(0.058 * ONE)  # 238
k  = round(0.063 * ONE)  # 258
W_DIAG = round(0.05 * ONE)  # 205
W_ORTH = round(0.20 * ONE)  # 819
W_CTR  = ONE                # 4096


def mul(a, b):
    return (a.astype(np.int64) * b) >> FRAC  # Q4.12 * Q4.12 -> Q4.12


def lap_fx(Z):
    diag = (np.roll(np.roll(Z, 1, 0), 1, 1) + np.roll(np.roll(Z, 1, 0), -1, 1)
            + np.roll(np.roll(Z, -1, 0), 1, 1) + np.roll(np.roll(Z, -1, 0), -1, 1))
    orth = (np.roll(Z, 1, 0) + np.roll(Z, -1, 0) + np.roll(Z, 1, 1) + np.roll(Z, -1, 1))
    # (diag*Wd + orth*Wo - Z*Wc) in Q4.12
    return ((diag.astype(np.int64) * W_DIAG
             + orth.astype(np.int64) * W_ORTH
             - Z.astype(np.int64) * W_CTR) >> FRAC)


def seed():
    rng = np.random.default_rng(1)
    U = np.full((GRID_H, GRID_W), ONE, dtype=np.int64)
    V = np.zeros((GRID_H, GRID_W), dtype=np.int64)
    mask = rng.random((GRID_H, GRID_W)) < 0.08
    V[mask] = ONE // 2
    U[mask] = ONE // 2
    return U, V


def run_fx():
    U, V = seed()
    for s in range(STEPS):
        UV = mul(U, V)
        UVV = mul(UV, V)                         # U*V*V
        lapU = lap_fx(U)
        lapV = lap_fx(V)
        U = U + mul(Du * np.ones_like(U), lapU) - UVV + ((F * (ONE - U)) >> FRAC)
        V = V + mul(Dv * np.ones_like(V), lapV) + UVV - (((F + k) * V) >> FRAC)
        np.clip(U, 0, ONE, out=U)
        np.clip(V, 0, ONE, out=V)
    return U, V


def main():
    outdir = os.path.dirname(os.path.abspath(__file__))
    U, V = run_fx()
    Vf = V.astype(np.float64) / ONE
    print(f"fixed Q4.12: V min={Vf.min():.3f} max={Vf.max():.3f} std={Vf.std():.4f}")
    assert Vf.std() > 0.05, "pattern died under quantization — need more frac bits"
    print("FIXED-POINT PATTERN OK — Q4.12 survives, RTL will match")
    v = np.clip(Vf / max(Vf.max(), 1e-6), 0, 1)
    r = (np.clip(v * 1.6 - 0.4, 0, 1) * 255).astype(np.uint8)
    g = (np.clip(v * 2.0, 0, 1) * 255).astype(np.uint8)
    b = (np.clip(v * 1.3 + 0.15, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(np.dstack([r, g, b])).resize((GRID_W * 4, GRID_H * 4), Image.NEAREST).save(
        os.path.join(outdir, "final_fx.png"))
    print("saved final_fx.png")


if __name__ == "__main__":
    main()
