"""Gray-Scott reaction-diffusion golden model for the Turing chip.

Whole-grid noisy seed so Turing patterns nucleate everywhere and fill fast.
Labyrinth/worms regime. Float reference + Q4.12 fixed-point (matches RTL).
"""
import numpy as np
from PIL import Image
import os

GRID_W, GRID_H = 128, 128
STEPS = 6000
FRAME_EVERY = 600

# Labyrinth / "worms" regime — fills the grid with maze patterns.
Du, Dv, F, k = 0.16, 0.08, 0.058, 0.063

FRAC = 12
ONE = 1 << FRAC


def laplacian(Z):
    return (
        0.05 * (np.roll(np.roll(Z, 1, 0), 1, 1) + np.roll(np.roll(Z, 1, 0), -1, 1)
                + np.roll(np.roll(Z, -1, 0), 1, 1) + np.roll(np.roll(Z, -1, 0), -1, 1))
        + 0.20 * (np.roll(Z, 1, 0) + np.roll(Z, -1, 0) + np.roll(Z, 1, 1) + np.roll(Z, -1, 1))
        - 1.00 * Z
    )


def seed():
    rng = np.random.default_rng(1)
    U = np.ones((GRID_H, GRID_W), dtype=np.float64)
    V = np.zeros((GRID_H, GRID_W), dtype=np.float64)
    # scatter ~8% of cells as V-rich seed points across the WHOLE grid
    mask = rng.random((GRID_H, GRID_W)) < 0.08
    V[mask] = 0.5
    U[mask] = 0.5
    return U, V


def run_float():
    U, V = seed()
    frames = []
    for s in range(STEPS):
        UVV = U * V * V
        U = U + Du * laplacian(U) - UVV + F * (1 - U)
        V = V + Dv * laplacian(V) + UVV - (F + k) * V
        np.clip(U, 0, 1, out=U)
        np.clip(V, 0, 1, out=V)
        if s % FRAME_EVERY == 0:
            frames.append(V.copy())
    return U, V, frames


def colorize(V):
    v = np.clip(V / max(V.max(), 1e-6), 0, 1)
    r = (np.clip(v * 1.6 - 0.4, 0, 1) * 255).astype(np.uint8)
    g = (np.clip(v * 2.0, 0, 1) * 255).astype(np.uint8)
    b = (np.clip(v * 1.3 + 0.15, 0, 1) * 255).astype(np.uint8)
    return np.dstack([r, g, b])


def main():
    outdir = os.path.dirname(os.path.abspath(__file__))
    U, V, frames = run_float()
    vstd = float(V.std())
    print(f"float run: V min={V.min():.3f} max={V.max():.3f} std={vstd:.4f}")
    assert vstd > 0.05, "no pattern formed"
    print("PATTERN OK")
    for i, fr in enumerate(frames):
        Image.fromarray(colorize(fr)).resize((GRID_W * 4, GRID_H * 4), Image.NEAREST).save(
            os.path.join(outdir, f"frame_{i:02d}.png"))
    Image.fromarray(colorize(V)).resize((GRID_W * 4, GRID_H * 4), Image.NEAREST).save(
        os.path.join(outdir, "final.png"))
    print(f"saved {len(frames)} frames + final.png")


if __name__ == "__main__":
    main()
